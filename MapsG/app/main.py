from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select

import app.models  # noqa: F401
from app.api.routes import (
    auth_routes,
    company_routes,
    health_routes,
    map_routes,
    observation_routes,
    project_routes,
    project_share_routes,
    user_routes,
)
from app.core.config import settings
from app.core.database import SessionLocal
from app.core.exceptions import install_exception_handlers
from app.core.logging import configure_logging
from app.core.security import hash_password
from app.core.storage import ensure_storage_directories
from app.models import User
from app.models.base import utcnow


def bootstrap_admin() -> None:
    with SessionLocal() as db:
        existing = db.scalar(select(User).where(User.email == settings.BOOTSTRAP_ADMIN_EMAIL.lower()))
        if not existing:
            db.add(
                User(
                    name=settings.BOOTSTRAP_ADMIN_NAME,
                    email=settings.BOOTSTRAP_ADMIN_EMAIL.lower(),
                    password_hash=hash_password(settings.BOOTSTRAP_ADMIN_PASSWORD),
                    role="super_admin",
                    is_active=True,
                    email_verified_at=utcnow(),
                )
            )
            db.commit()


@asynccontextmanager
async def lifespan(_: FastAPI):
    configure_logging(settings.APP_DEBUG)
    ensure_storage_directories()
    bootstrap_admin()
    yield


app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    description="Procesamiento y distribución de mapas offline para GeoCampo.",
    lifespan=lifespan,
)
if settings.cors_origins_list:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_origin_regex=settings.cors_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

install_exception_handlers(app)
for router in (
    health_routes.router,
    auth_routes.router,
    company_routes.router,
    user_routes.router,
    project_routes.router,
    project_share_routes.router,
    map_routes.router,
    observation_routes.router,
):
    app.include_router(router, prefix="/api")
