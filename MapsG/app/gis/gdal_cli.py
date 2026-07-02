import subprocess

from app.core.exceptions import GeoCampoError


def run_gdal(command: list[str], clean_message: str, error_code: str = "GDAL_PROCESSING_FAILED") -> None:
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
    except FileNotFoundError as exc:
        raise GeoCampoError(
            "GDAL_NOT_AVAILABLE",
            "GDAL no está instalado o no está disponible en PATH.",
            500,
        ) from exc

    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise GeoCampoError(error_code, f"{clean_message} {detail}"[:2000], 422)
