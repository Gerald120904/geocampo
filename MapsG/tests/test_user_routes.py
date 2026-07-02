import uuid

from app.api.routes.user_routes import list_users, update_me
from app.core.database import Base, SessionLocal, engine
from app.core.security import hash_password
from app.models import Company, User
from app.models.base import utcnow
from app.schemas.user_schema import UserUpdateMe


def _unique_email(prefix: str) -> str:
    return f"{prefix}-{uuid.uuid4().hex}@example.com"


def _create_company_and_user(role: str = "company_admin") -> tuple[Company, User]:
    with SessionLocal() as db:
        company = Company(name=f"Test Company {uuid.uuid4().hex}", identifier=f"test-{uuid.uuid4().hex}")
        user = User(
            name="Gerald Admin",
            email=_unique_email("gerald"),
            password_hash=hash_password("Password1"),
            role=role,
            company=company,
            is_active=True,
            email_verified_at=utcnow(),
        )
        db.add_all([company, user])
        db.commit()
        db.refresh(company)
        db.refresh(user)
        return company, user


def setup_module() -> None:
    Base.metadata.create_all(bind=engine)


def test_update_me_changes_current_user_name():
    _, user = _create_company_and_user()

    with SessionLocal() as db:
        current = db.get(User, user.id)
        assert current is not None
        updated = update_me(UserUpdateMe(name=" Gerald "), db, current)

    assert updated.id == user.id
    assert updated.name == "Gerald"
    assert updated.email == user.email
    assert updated.role == "company_admin"
    assert updated.company_id == user.company_id
    assert updated.email_verified is True


def test_list_users_returns_paginated_response_with_filters():
    company, admin = _create_company_and_user()
    with SessionLocal() as db:
        db.add_all(
            [
                User(
                    name="Gerald Technician",
                    email=_unique_email("gerald-tech"),
                    password_hash=hash_password("Password1"),
                    role="technician",
                    company_id=company.id,
                    is_active=True,
                    email_verified_at=utcnow(),
                ),
                User(
                    name="Other Viewer",
                    email=_unique_email("viewer"),
                    password_hash=hash_password("Password1"),
                    role="viewer",
                    company_id=company.id,
                    is_active=True,
                    email_verified_at=utcnow(),
                ),
            ]
        )
        db.commit()

    with SessionLocal() as db:
        current = db.get(User, admin.id)
        assert current is not None
        body = list_users(limit=1, offset=0, q="gerald", role="technician", db=db, current=current)

    assert body.total == 1
    assert body.limit == 1
    assert body.offset == 0
    assert body.has_more is False
    assert len(body.items) == 1
    assert body.items[0].name == "Gerald Technician"
    assert body.items[0].role == "technician"
    assert body.items[0].company_id == admin.company_id
