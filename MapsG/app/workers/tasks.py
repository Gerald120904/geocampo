from app.core.database import SessionLocal
from app.services.map_service import create_quick_geopdf_view, process_map
from app.workers.celery_app import celery_app


@celery_app.task(
    name="app.workers.tasks.process_map_task",
    bind=True,
    autoretry_for=(ConnectionError, TimeoutError),
    retry_kwargs={"max_retries": 2, "countdown": 30},
)
def process_map_task(self, map_id: str, job_id: str) -> None:
    with SessionLocal() as db:
        process_map(db, map_id, job_id)


@celery_app.task(
    name="app.workers.tasks.process_quick_view_task",
    bind=True,
    autoretry_for=(ConnectionError, TimeoutError),
    retry_kwargs={"max_retries": 2, "countdown": 30},
)
def process_quick_view_task(self, map_id: str, job_id: str) -> None:
    with SessionLocal() as db:
        create_quick_geopdf_view(db, map_id, job_id)
