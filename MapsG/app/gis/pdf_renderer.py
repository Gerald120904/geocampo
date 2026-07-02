from pathlib import Path

import fitz

from app.core.exceptions import GeoCampoError


def render_pdf_page_to_png(source: Path, output: Path, page_index: int = 0, zoom: float = 2.0) -> Path:
    try:
        document = fitz.open(source)
    except Exception as exc:
        raise GeoCampoError("INVALID_PDF", "No se pudo abrir el PDF.", 422) from exc

    try:
        if document.needs_pass:
            raise GeoCampoError(
                "PDF_PASSWORD_PROTECTED",
                "El PDF está protegido con contraseña.",
                422,
            )

        if page_index >= len(document):
            raise GeoCampoError("INVALID_PDF_PAGE", "La página del PDF no existe.", 422)

        output.parent.mkdir(parents=True, exist_ok=True)
        page = document[page_index]
        matrix = fitz.Matrix(zoom, zoom)
        pixmap = page.get_pixmap(matrix=matrix, alpha=False)
        pixmap.save(str(output))
        return output
    finally:
        document.close()
