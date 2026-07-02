from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class GeoCampoError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400):
        self.code = code
        self.message = message
        self.status_code = status_code
        super().__init__(message)


def install_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(GeoCampoError)
    async def geocampo_error_handler(_: Request, exc: GeoCampoError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": True, "code": exc.code, "message": exc.message},
        )

