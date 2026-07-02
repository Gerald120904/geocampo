from sqlalchemy.orm import Session

from app.core.exceptions import GeoCampoError
from app.models import MapProject, Project, User


def assert_company_access(user: User, company_id: str) -> None:
    if user.role != "super_admin" and user.company_id != company_id:
        raise GeoCampoError("FORBIDDEN", "No tiene acceso a esta empresa.", 403)


def get_project_for_user(db: Session, project_id: str, user: User) -> Project:
    project = db.get(Project, project_id)
    if not project:
        raise GeoCampoError("PROJECT_NOT_FOUND", "Proyecto no encontrado.", 404)
    assert_company_access(user, project.company_id)
    return project


def get_map_for_user(db: Session, map_id: str, user: User) -> MapProject:
    map_project = db.get(MapProject, map_id)
    if not map_project or map_project.status in {"deleted", "archived"}:
        raise GeoCampoError("MAP_NOT_FOUND", "Mapa no encontrado.", 404)
    get_project_for_user(db, map_project.project_id, user)
    return map_project
