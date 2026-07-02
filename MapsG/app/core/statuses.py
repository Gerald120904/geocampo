MAP_STATUS_UPLOADED = "uploaded"
MAP_STATUS_QUEUED = "queued"
MAP_STATUS_PROCESSING = "processing"
MAP_STATUS_INSPECTING = "inspecting"
MAP_STATUS_BUILDING_PREVIEW = "building_preview"
MAP_STATUS_WARPING = "warping"
MAP_STATUS_BUILDING_TILES = "building_tiles"
MAP_STATUS_BUILDING_PACKAGE = "building_package"
MAP_STATUS_QUICK_BUILDING = "quick_building"
MAP_STATUS_QUICK_READY = "quick_ready"
MAP_STATUS_OPTIMIZING = "optimizing"
MAP_STATUS_RAW_READY = "raw_ready"
MAP_STATUS_READY = "ready"
MAP_STATUS_DUPLICATE_REVIEW = "duplicate_review"
MAP_STATUS_FAILED = "failed"
MAP_STATUS_ARCHIVED = "archived"
MAP_STATUS_REPLACED = "replaced"
MAP_STATUS_DELETED = "deleted"

MAP_STATUSES = {
    MAP_STATUS_UPLOADED,
    MAP_STATUS_QUEUED,
    MAP_STATUS_PROCESSING,
    MAP_STATUS_INSPECTING,
    MAP_STATUS_BUILDING_PREVIEW,
    MAP_STATUS_WARPING,
    MAP_STATUS_BUILDING_TILES,
    MAP_STATUS_BUILDING_PACKAGE,
    MAP_STATUS_QUICK_BUILDING,
    MAP_STATUS_QUICK_READY,
    MAP_STATUS_OPTIMIZING,
    MAP_STATUS_RAW_READY,
    MAP_STATUS_READY,
    MAP_STATUS_DUPLICATE_REVIEW,
    MAP_STATUS_FAILED,
    MAP_STATUS_ARCHIVED,
    MAP_STATUS_REPLACED,
    MAP_STATUS_DELETED,
}
JOB_STATUSES = {"pending", "running", "completed", "failed", "cancelled"}


def assert_map_status(status: str) -> str:
    if status not in MAP_STATUSES:
        raise ValueError(f"Invalid map status: {status}")
    return status


def assert_job_status(status: str) -> str:
    if status not in JOB_STATUSES:
        raise ValueError(f"Invalid job status: {status}")
    return status
