from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.models import User
from app.schemas.auth_schema import (
    ChangePasswordRequest,
    ForgotPasswordRequest,
    LoginRequest,
    LogoutRequest,
    MessageResponse,
    RefreshRequest,
    RefreshResponse,
    RegisterRequest,
    RegisterResponse,
    ResendVerificationCodeRequest,
    ResetPasswordRequest,
    TokenResponse,
    VerifyEmailRequest,
)
from app.schemas.user_schema import UserPublic
from app.services.auth_service import (
    GENERIC_EMAIL_MESSAGE,
    authenticate,
    change_password as change_user_password,
    get_current_user,
    logout as logout_session,
    refresh_session,
    register_user,
    resend_verification_code,
    reset_password_with_code,
    send_password_reset_code,
    verify_email_code,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=RegisterResponse, status_code=201)
def register(payload: RegisterRequest, request: Request, db: Session = Depends(get_db)) -> RegisterResponse:
    user = register_user(db, payload, request)
    return RegisterResponse(
        message="Cuenta creada correctamente. Enviamos un código de verificación a su correo.",
        requires_email_verification=True,
        email=user.email,
    )


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, request: Request, db: Session = Depends(get_db)) -> TokenResponse:
    access_token, refresh_token, user = authenticate(db, payload.email, payload.password, request)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        user=user,
    )


@router.post("/refresh", response_model=RefreshResponse)
def refresh(payload: RefreshRequest, request: Request, db: Session = Depends(get_db)) -> RefreshResponse:
    access_token, refresh_token = refresh_session(db, payload.refresh_token, request)
    return RefreshResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post("/logout", response_model=MessageResponse)
def logout(payload: LogoutRequest, db: Session = Depends(get_db)) -> MessageResponse:
    logout_session(db, payload.refresh_token)
    return MessageResponse(message="Sesión cerrada correctamente.")


@router.get("/me", response_model=UserPublic)
def me(user: User = Depends(get_current_user)) -> User:
    return user


@router.post("/verify-email", response_model=MessageResponse)
def verify_email(payload: VerifyEmailRequest, db: Session = Depends(get_db)) -> MessageResponse:
    verify_email_code(db, payload.email, payload.code)
    return MessageResponse(message="Correo verificado correctamente.")


@router.post("/resend-verification-code", response_model=MessageResponse)
def resend_code(
    payload: ResendVerificationCodeRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> MessageResponse:
    resend_verification_code(db, payload.email, request)
    return MessageResponse(message=GENERIC_EMAIL_MESSAGE)


@router.post("/forgot-password", response_model=MessageResponse)
def forgot_password(payload: ForgotPasswordRequest, request: Request, db: Session = Depends(get_db)) -> MessageResponse:
    send_password_reset_code(db, payload.email, request)
    return MessageResponse(message=GENERIC_EMAIL_MESSAGE)


@router.post("/reset-password", response_model=MessageResponse)
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)) -> MessageResponse:
    reset_password_with_code(db, payload.email, payload.code, payload.new_password)
    return MessageResponse(message="Contraseña actualizada correctamente.")


@router.post("/change-password", response_model=MessageResponse)
def change_password(
    payload: ChangePasswordRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> MessageResponse:
    change_user_password(db, user, payload.current_password, payload.new_password)
    return MessageResponse(message="Contraseña actualizada correctamente.")
