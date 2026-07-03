import logging
import smtplib
from email.message import EmailMessage
from html import escape

import requests

from app.core.config import settings

logger = logging.getLogger(__name__)


def _format_code(code: str) -> str:
    return f"{code[:3]} {code[3:]}"


def _build_code_email_html(user_name: str, code: str, title: str, intro: str) -> str:
    safe_name = escape(user_name)
    safe_title = escape(title)
    safe_intro = escape(intro)
    display_code = escape(_format_code(code))
    return f"""<!doctype html>
<html lang="es">
  <body style="margin:0;background:#F8F5EE;font-family:Arial,Helvetica,sans-serif;color:#263128;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#F8F5EE;padding:28px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #DFF3E3;">
            <tr>
              <td style="background:#2F6B3D;padding:28px 30px;color:#ffffff;">
                <div style="font-size:26px;font-weight:700;letter-spacing:0;">GeoCampo</div>
                <div style="margin-top:6px;font-size:14px;color:#DFF3E3;">Tecnología para el trabajo en campo</div>
                <div style="margin-top:18px;font-size:32px;line-height:1;">🌿 🌱 🌾</div>
              </td>
            </tr>
            <tr>
              <td style="padding:32px 30px 26px;">
                <h1 style="margin:0 0 14px;font-size:22px;line-height:1.25;color:#2F6B3D;">{safe_title}</h1>
                <p style="margin:0 0 14px;font-size:16px;line-height:1.6;">Hola {safe_name},</p>
                <p style="margin:0 0 22px;font-size:16px;line-height:1.6;">{safe_intro}</p>
                <div style="background:#DFF3E3;border:1px solid #B9E2C0;border-radius:14px;padding:24px;text-align:center;">
                  <div style="font-size:13px;text-transform:uppercase;color:#2F6B3D;font-weight:700;">Tu código</div>
                  <div style="margin-top:8px;font-size:42px;line-height:1;font-weight:800;letter-spacing:6px;color:#2F6B3D;">{display_code}</div>
                  <div style="margin-top:14px;font-size:14px;color:#5F6E62;">Vence en 10 minutos.</div>
                </div>
                <p style="margin:22px 0 0;font-size:14px;line-height:1.6;color:#5F6E62;">Si no solicitaste este código, puedes ignorar este correo.</p>
              </td>
            </tr>
            <tr>
              <td style="background:#F4EFE5;padding:18px 30px;color:#8B6B4A;font-size:13px;line-height:1.5;">
                Gracias por confiar en GeoCampo.<br>
                Tecnología para el trabajo en campo.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>"""


def _mail_from_email() -> str:
    return settings.MAIL_FROM_EMAIL or settings.SMTP_FROM_EMAIL


def _mail_from_name() -> str:
    return settings.MAIL_FROM_NAME or settings.SMTP_FROM_NAME


def _mail_from_header() -> str:
    return f"{_mail_from_name()} <{_mail_from_email()}>"


def _send_email_brevo(to_email: str, subject: str, text_body: str, html_body: str | None = None) -> None:
    response = requests.post(
        "https://api.brevo.com/v3/smtp/email",
        headers={
            "api-key": settings.BREVO_API_KEY,
            "Content-Type": "application/json",
        },
        json={
            "sender": {"name": _mail_from_name(), "email": _mail_from_email()},
            "to": [{"email": to_email}],
            "subject": subject,
            "textContent": text_body,
            "htmlContent": html_body or text_body,
        },
        timeout=10,
    )
    if response.status_code >= 400:
        raise RuntimeError(f"Brevo email error: {response.status_code} {response.text}")


def _send_email(to_email: str, subject: str, text_body: str, html_body: str | None = None) -> None:
    provider = getattr(settings, "EMAIL_PROVIDER", "smtp").lower()
    if provider == "brevo":
        _send_email_brevo(to_email, subject, text_body, html_body)
        return

    if provider == "resend":
        response = requests.post(
            "https://api.resend.com/emails",
            headers={
                "Authorization": f"Bearer {settings.RESEND_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "from": _mail_from_header(),
                "to": [to_email],
                "subject": subject,
                "text": text_body,
                "html": html_body or text_body,
            },
            timeout=10,
        )
        if response.status_code >= 400:
            raise RuntimeError(f"Resend email error: {response.status_code} {response.text}")
        return

    message = EmailMessage()
    message["From"] = _mail_from_header()
    message["To"] = to_email
    message["Subject"] = subject
    message.set_content(text_body)
    if html_body:
        message.add_alternative(html_body, subtype="html")
    try:
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=10) as smtp:
            if settings.SMTP_USE_TLS:
                smtp.starttls()
            if settings.SMTP_USERNAME and settings.SMTP_PASSWORD:
                smtp.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
            smtp.send_message(message)
    except (OSError, smtplib.SMTPException):
        if settings.APP_ENV == "development":
            logger.info("Development email fallback to %s: %s\n%s", to_email, subject, text_body)
            return
        raise


def send_verification_code_email(to_email: str, user_name: str, code: str) -> None:
    subject = "Tu código de verificación de GeoCampo"
    text_body = (
        f"Hola {user_name},\n\n"
        "Bienvenido a GeoCampo.\n\n"
        f"Tu código para verificar tu cuenta es: {_format_code(code)}\n\n"
        "Este código vence en 10 minutos.\n\n"
        "Gracias por confiar en GeoCampo.\n"
        "Tecnología para el trabajo en campo."
    )
    html_body = _build_code_email_html(
        user_name,
        code,
        "Verifica tu cuenta",
        "Bienvenido a GeoCampo. Usa este código para activar tu cuenta.",
    )
    _send_email(to_email, subject, text_body, html_body)


def send_password_reset_code_email(to_email: str, user_name: str, code: str) -> None:
    subject = "Tu código para recuperar contraseña de GeoCampo"
    text_body = (
        f"Hola {user_name},\n\n"
        "Recibimos una solicitud para cambiar tu contraseña.\n\n"
        f"Tu código de recuperación es: {_format_code(code)}\n\n"
        "Este código vence en 10 minutos.\n\n"
        "Gracias por confiar en GeoCampo.\n"
        "Tecnología para el trabajo en campo."
    )
    html_body = _build_code_email_html(
        user_name,
        code,
        "Recupera tu contraseña",
        "Recibimos una solicitud para cambiar tu contraseña. Usa este código para continuar.",
    )
    _send_email(to_email, subject, text_body, html_body)
