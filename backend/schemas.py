"""Request and response bodies for the /auth routes."""

import re

from pydantic import BaseModel, EmailStr, Field, field_validator

from input_rules import CleanModel

# "+<calling code> <number>" as sent by the app.
PHONE_PATTERN = re.compile(r"\+[0-9]{1,4} [0-9]{4,15}")

# Long enough for any passphrase, short enough that hashing stays cheap.
PASSWORD_MAX = 256


class RegisterRequest(CleanModel):
    """Body of POST /auth/register. Profile fields are optional."""

    email: EmailStr
    password: str = Field(min_length=8, max_length=PASSWORD_MAX)
    name: str | None = Field(default=None, max_length=100)
    gender: str | None = Field(default=None, max_length=20)
    birthdate: str | None = Field(default=None, max_length=40)
    country: str | None = Field(default=None, max_length=80)
    city: str | None = Field(default=None, max_length=80)
    street: str | None = Field(default=None, max_length=160)
    phone: str | None = Field(default=None, max_length=32)

    @field_validator(
        "name",
        "gender",
        "birthdate",
        "country",
        "city",
        "street",
        "phone",
        mode="before",
    )
    @classmethod
    def _blank_to_none(cls, value):
        if value is None:
            return None
        if isinstance(value, str):
            trimmed = value.strip()
            return trimmed or None
        return value

    @field_validator("gender")
    @classmethod
    def _known_gender(cls, value):
        if value is None:
            return None
        if value not in {"male", "female"}:
            raise ValueError("gender must be male or female")
        return value

    @field_validator("phone")
    @classmethod
    def _plausible_phone(cls, value):
        if value is None:
            return None
        if not PHONE_PATTERN.fullmatch(value):
            raise ValueError("phone must look like +963 912345678")
        return value


class LoginRequest(CleanModel):
    """Body of POST /auth/login."""

    email: EmailStr
    # No minimum: accounts made before the 8-character rule still sign in.
    password: str = Field(max_length=PASSWORD_MAX)


class AuthResponse(BaseModel):
    """A bearer token."""

    access_token: str
    token_type: str


class ForgotPasswordRequest(CleanModel):
    """Body of POST /auth/password/forgot."""

    email: EmailStr


class ResetPasswordRequest(CleanModel):
    """Body of POST /auth/password/reset."""

    email: EmailStr
    code: str = Field(min_length=6, max_length=6, pattern="^[0-9]{6}$")
    new_password: str = Field(min_length=8, max_length=PASSWORD_MAX)


class DataKeyIn(CleanModel):
    """The data key wrapped on the device with the user's password."""

    salt: str = Field(min_length=16, max_length=64)
    iterations: int = Field(ge=100_000, le=10_000_000)
    wrapped_key: str = Field(min_length=40, max_length=512)


class ChangePasswordRequest(CleanModel):
    """Body of POST /auth/password/change."""

    current_password: str = Field(max_length=PASSWORD_MAX)
    new_password: str = Field(min_length=8, max_length=PASSWORD_MAX)
    # The same data key, re-wrapped with the new password.
    data_key: DataKeyIn | None = None
