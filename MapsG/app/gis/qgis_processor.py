from app.core.exceptions import GeoCampoError


def process_qgis(*_args, **_kwargs):
    raise GeoCampoError(
        "FORMAT_NOT_AVAILABLE_IN_MVP",
        "Los proyectos QGIS están previstos para la fase avanzada.",
    )

