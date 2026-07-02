from datetime import timedelta

from fastapi import Depends, Query, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.exceptions import GeoCampoError
from app.core.security import (
    create_access_token,
    decode_access_token,
    generate_numeric_code,
    generate_secure_token,
    hash_password,
    hash_token,
    validate_password_strength,
    verify_password,
)
from app.models import AuthToken, Company, User
from app.models.base import utcnow
from app.repositories.user_repository import get_by_email, get_by_id
from app.services.email_service import send_password_reset_code_email, send_verification_code_email

bearer = HTTPBearer(auto_error=False)

GENERIC_EMAIL_MESSAGE = "Si el correo existe, enviaremos instrucciones."
ACCOUNT_LOCK_MINUTES = 15
MAX_FAILED_LOGIN_ATTEMPTS = 5
MAX_CODE_ATTEMPTS = 5


def _request_ip(request: Request | None) -> str | None:
    return request.client.host if request and request.client else None


def _request_user_agent(request: Request | None) -> str | None:
    return request.headers.get("user-agent")[:500] if request else None


def _now_for(value) -> object:
    now = utcnow()
    if value is not None and getattr(value, "tzinfo", None) is None:
        return now.replace(tzinfo=None)
    return now


def _raise_weak_password(password: str) -> None:
    try:
        validate_password_strength(password)
    except ValueError as exc:
        raise GeoCampoError("WEAK_PASSWORD", str(exc), 422) from exc


def _revoke_active_tokens(db: Session, user_id: str, token_type: str) -> None:
    db.execute(
        update(AuthToken)
        .where(
            AuthToken.user_id == user_id,
            AuthToken.token_type == token_type,
            AuthToken.used_at.is_(None),
            AuthToken.revoked_at.is_(None),
        )
        .values(revoked_at=utcnow())
    )


def _create_auth_token(
    db: Session,
    user: User,
    token_type: str,
    token_value: str,
    expires_at,
    request: Request | None = None,
) -> None:
    db.add(
        AuthToken(
            user_id=user.id,
            token_hash=hash_token(token_value),
            token_type=token_type,
            expires_at=expires_at,
            ip_address=_request_ip(request),
            user_agent=_request_user_agent(request),
        )
    )


def _create_refresh_token(db: Session, user: User, request: Request | None = None) -> str:
    refresh_token = generate_secure_token()
    _create_auth_token(
        db,
        user,
        "refresh",
        refresh_token,
        utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        request,
    )
    return refresh_token


def _create_code(db: Session, user: User, token_type: str, expires_minutes: int, request: Request | None = None) -> str:
    _revoke_active_tokens(db, user.id, token_type)
    code = generate_numeric_code()
    _create_auth_token(db, user, token_type, code, utcnow() + timedelta(minutes=expires_minutes), request)
    return code


def _find_valid_token(db: Session, token: str, token_type: str) -> AuthToken:
    auth_token = db.scalar(
        select(AuthToken)
        .where(
            AuthToken.token_hash == hash_token(token),
            AuthToken.token_type == token_type,
        )
        .order_by(AuthToken.created_at.desc())
    )
    now = _now_for(auth_token.expires_at) if auth_token else utcnow()
    if (
        not auth_token
        or auth_token.used_at is not None
        or auth_token.revoked_at is not None
        or auth_token.expires_at <= now
    ):
        raise GeoCampoError("INVALID_TOKEN", "El token no es válido o expiró.", 400)
    return auth_token


def _find_latest_active_code(db: Session, user: User, token_type: str) -> AuthToken | None:
    return db.scalar(
        select(AuthToken)
        .where(
            AuthToken.user_id == user.id,
            AuthToken.token_type == token_type,
            AuthToken.used_at.is_(None),
            AuthToken.revoked_at.is_(None),
        )
        .order_by(AuthToken.created_at.desc())
    )


def _consume_code(db: Session, user: User, token_type: str, code: str) -> AuthToken:
    auth_token = _find_latest_active_code(db, user, token_type)
    now = _now_for(auth_token.expires_at) if auth_token else utcnow()
    if not auth_token or auth_token.expires_at <= now:
        raise GeoCampoError("INVALID_CODE", "El código no es válido o expiró.", 400)
    if auth_token.attempts >= MAX_CODE_ATTEMPTS:
        auth_token.revoked_at = utcnow()
        db.commit()
        raise GeoCampoError("CODE_ATTEMPTS_EXCEEDED", "Se superó el máximo de intentos.", 429)
    if auth_token.token_hash != hash_token(code):
        auth_token.attempts += 1
        if auth_token.attempts >= MAX_CODE_ATTEMPTS:
            auth_token.revoked_at = utcnow()
        db.commit()
        raise GeoCampoError("INVALID_CODE", "El código no es válido o expiró.", 400)
    auth_token.used_at = utcnow()
    return auth_token


def register_user(db: Session, payload, request: Request | None = None) -> User:
    _raise_weak_password(payload.password)
    email = payload.email.lower()
    identifier = payload.company_identifier.lower()
    if db.scalar(select(User).where(User.email == email)):
        raise GeoCampoError("USER_EXISTS", "Ya existe un usuario con ese correo.", 409)
    if db.scalar(select(Company).where(Company.identifier == identifier)):
        raise GeoCampoError("COMPANY_EXISTS", "Ya existe una empresa con ese identificador.", 409)

    company = Company(name=payload.company_name, identifier=identifier)
    user = User(
        name=payload.name,
        email=email,
        password_hash=hash_password(payload.password),
        role="company_admin",
        company=company,
        is_active=True,
    )
    db.add(user)
    db.flush()
    code = _create_code(db, user, "email_verification", settings.EMAIL_VERIFICATION_CODE_EXPIRE_MINUTES, request)
    send_verification_code_email(user.email, user.name, code)
    db.commit()
    db.refresh(user)
    return user


def verify_email_code(db: Session, email: str, code: str) -> None:
    user = get_by_email(db, email)
    if not user or not user.is_active:
        raise GeoCampoError("INVALID_CODE", "El código no es válido o expiró.", 400)
    auth_token = _consume_code(db, user, "email_verification", code)
    user.email_verified_at = user.email_verified_at or utcnow()
    auth_token.used_at = auth_token.used_at or utcnow()
    db.commit()


def resend_verification_code(db: Session, email: str, request: Request | None = None) -> None:
    user = get_by_email(db, email)
    if user and user.is_active and not user.email_verified_at:
        code = _create_code(db, user, "email_verification", settings.EMAIL_VERIFICATION_CODE_EXPIRE_MINUTES, request)
        send_verification_code_email(user.email, user.name, code)
        db.commit()


def authenticate(db: Session, email: str, password: str, request: Request | None = None) -> tuple[str, str, User]:
    user = get_by_email(db, email)
    now = utcnow()
    if not user or not user.is_active:
        raise GeoCampoError("INVALID_CREDENTIALS", "Correo o contraseña incorrectos.", 401)
    if user.locked_until and user.locked_until > _now_for(user.locked_until):
        raise GeoCampoError("ACCOUNT_LOCKED", "Cuenta bloqueada temporalmente. Intente más tarde.", 423)
    if not verify_password(password, user.password_hash):
        user.failed_login_attempts = (user.failed_login_attempts or 0) + 1
        if user.failed_login_attempts >= MAX_FAILED_LOGIN_ATTEMPTS:
            user.locked_until = now + timedelta(minutes=ACCOUNT_LOCK_MINUTES)
        db.commit()
        raise GeoCampoError("INVALID_CREDENTIALS", "Correo o contraseña incorrectos.", 401)
    if not user.email_verified_at:
        raise GeoCampoError("EMAIL_NOT_VERIFIED", "Debe verificar su correo antes de iniciar sesión.", 403)
    user.failed_login_attempts = 0
    user.locked_until = None
    user.last_login_at = now
    access_token = create_access_token(user.id)
    refresh_token = _create_refresh_token(db, user, request)
    db.commit()
    return access_token, refresh_token, user


def send_password_reset_code(db: Session, email: str, request: Request | None = None) -> None:
    user = get_by_email(db, email)
    if user and user.is_active:
        code = _create_code(db, user, "password_reset", settings.PASSWORD_RESET_CODE_EXPIRE_MINUTES, request)
        send_password_reset_code_email(user.email, user.name, code)
        db.commit()


def reset_password_with_code(db: Session, email: str, code: str, new_password: str) -> None:
    _raise_weak_password(new_password)
    user = get_by_email(db, email)
    if not user or not user.is_active:
        raise GeoCampoError("INVALID_CODE", "El código no es válido o expiró.", 400)
    auth_token = _consume_code(db, user, "password_reset", code)
    now = utcnow()
    user.password_hash = hash_password(new_password)
    user.password_changed_at = now
    user.failed_login_attempts = 0
    user.locked_until = None
    auth_token.used_at = auth_token.used_at or now
    db.execute(
        update(AuthToken)
        .where(
            AuthToken.user_id == user.id,
            AuthToken.token_type == "refresh",
            AuthToken.revoked_at.is_(None),
        )
        .values(revoked_at=now)
    )
    db.commit()


def refresh_session(db: Session, refresh_token: str, request: Request | None = None) -> tuple[str, str]:
    auth_token = _find_valid_token(db, refresh_token, "refresh")
    user = auth_token.user
    if not user.is_active:
        raise GeoCampoError("INVALID_TOKEN", "El token no es válido.", 401)
    auth_token.used_at = utcnow()
    access_token = create_access_token(user.id)
    new_refresh_token = _create_refresh_token(db, user, request)
    db.commit()
    return access_token, new_refresh_token


def logout(db: Session, refresh_token: str) -> None:
    auth_token = db.scalar(
        select(AuthToken)
        .where(
            AuthToken.token_hash == hash_token(refresh_token),
            AuthToken.token_type == "refresh",
        )
        .order_by(AuthToken.created_at.desc())
    )
    if auth_token and auth_token.revoked_at is None:
        auth_token.revoked_at = utcnow()
        db.commit()


def change_password(db: Session, user: User, current_password: str, new_password: str) -> None:
    if not verify_password(current_password, user.password_hash):
        raise GeoCampoError("INVALID_CREDENTIALS", "Contraseña actual incorrecta.", 401)
    _raise_weak_password(new_password)
    now = utcnow()
    user.password_hash = hash_password(new_password)
    user.password_changed_at = now
    db.execute(
        update(AuthToken)
        .where(
            AuthToken.user_id == user.id,
            AuthToken.token_type == "refresh",
            AuthToken.revoked_at.is_(None),
        )
        .values(revoked_at=now)
    )
    db.commit()


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    access_token: str | None = Query(default=None),
    db: Session = Depends(get_db),
) -> User:
    token = credentials.credentials if credentials else access_token
    if not token:
        raise GeoCampoError("NOT_AUTHENTICATED", "Se requiere autenticación.", 401)
    user_id = decode_access_token(token)
    user = get_by_id(db, user_id) if user_id else None
    if not user or not user.is_active:
        raise GeoCampoError("INVALID_TOKEN", "El token no es válido.", 401)
    return user


def require_roles(*roles: str):
    def dependency(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise GeoCampoError("FORBIDDEN", "No tiene permisos para realizar esta acción.", 403)
        return user

    return dependency
