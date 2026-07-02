from pydantic import BaseModel, EmailStr, Field, field_validator

from app.schemas.user_schema import UserPublic


class RegisterRequest(BaseModel):
    company_name: str = Field(min_length=2, max_length=200)
    company_identifier: str = Field(min_length=2, max_length=100)
    name: str = Field(min_length=2, max_length=200)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class LoginRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=8, max_length=128)

    @field_validator("email")
    @classmethod
    def normalize_login_email(cls, value: str) -> str:
        email = value.strip().lower()
        if "@" not in email or email.startswith("@") or email.endswith("@"):
            raise ValueError("Correo inválido.")
        return email


class EmailRequest(BaseModel):
    email: EmailStr


class VerifyEmailRequest(EmailRequest):
    code: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")


class ResendVerificationCodeRequest(EmailRequest):
    pass


class ForgotPasswordRequest(EmailRequest):
    pass


class TokenRequest(BaseModel):
    token: str = Field(min_length=20, max_length=512)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=512)


class LogoutRequest(RefreshRequest):
    pass


class ResetPasswordRequest(VerifyEmailRequest):
    new_password: str = Field(min_length=8, max_length=128)


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=8, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class MessageResponse(BaseModel):
    message: str


class RegisterResponse(MessageResponse):
    requires_email_verification: bool
    email: EmailStr


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserPublic


class RefreshResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
