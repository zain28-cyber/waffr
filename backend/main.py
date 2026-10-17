"""The FastAPI app: startup, middleware, routers, and the /auth routes.

Importing this module creates the tables and policies. Run it with
``uvicorn main:app`` from the backend folder.
"""

import asyncio
import logging
from contextlib import asynccontextmanager, suppress
from datetime import timedelta

from fastapi import BackgroundTasks, Depends, FastAPI, HTTPException, Request
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from database import create_tables, get_db, utc_now
from legacy_photo import photo_meta, remove_uploaded_photos
from category_model import ExpenseCategory
from models import Notification, User, UserSettings
from preset_model import ExpensePreset
import password_reset
from schemas import (
    AuthResponse,
    ChangePasswordRequest,
    DataKeyIn,
    ForgotPasswordRequest,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
)
from auth import (
    burn_password_check,
    hash_password,
    verify_password,
    create_access_token,
    get_current_user,
    user_id_for_email,
)
from goal_model import SavingsGoal, SavingsTransfer
from online_model import ExchangeRate, NewsArticle
from shopping_model import ShoppingItem, ShoppingList
from transaction_model import RecurringExpense, Transaction
from news_service import news_refresh_loop
from rate_limit import (
    ACCOUNT_DELETE_USER,
    DATA_KEY_USER,
    FORGOT_ALL,
    FORGOT_EMAIL,
    FORGOT_IP,
    LOGIN_FAILURES_EMAIL,
    LOGIN_IP,
    PASSWORD_CHANGE_USER,
    REGISTER_ALL,
    REGISTER_IP,
    RESET_EMAIL,
    RESET_IP,
    email_key,
    enforce,
    enforce_ip,
    limiter,
    too_many,
)
from row_security import bind_user
from security_log import configure_logging, log_event
import security_middleware
from routers.notifications import router as notifications_router
from routers.online import router as online_router
from routers.recurring import router as recurring_router
from routers.savings import router as savings_router
from routers.settings import router as settings_router
from routers.shopping import router as shopping_router
from routers.sync import router as sync_router
from routers.transactions import router as transactions_router

_MODEL_MODULES = (
    User,
    UserSettings,
    Notification,
    Transaction,
    RecurringExpense,
    SavingsGoal,
    SavingsTransfer,
    ShoppingList,
    ShoppingItem,
    ExpenseCategory,
    ExpensePreset,
    NewsArticle,
    ExchangeRate,
)

configure_logging()
create_tables()
remove_uploaded_photos()

# Wrong passwords in a row before sign-in locks, and for how long.
MAX_FAILED_LOGINS = 5
LOGIN_LOCKOUT = timedelta(minutes=15)


@asynccontextmanager
async def _lifespan(_app: FastAPI):
    task = asyncio.create_task(news_refresh_loop())
    try:
        yield
    finally:
        task.cancel()
        with suppress(asyncio.CancelledError):
            await task


app = FastAPI(lifespan=_lifespan, **security_middleware.docs_settings())
security_middleware.install(app)

app.include_router(transactions_router)
app.include_router(online_router)
app.include_router(savings_router)
app.include_router(shopping_router)
app.include_router(recurring_router)
app.include_router(notifications_router)
app.include_router(settings_router)
app.include_router(sync_router)


@app.get("/")
def root():
    """Health check for Render."""
    return {"message": "Waffr API is running"}


@app.post("/auth/register", response_model=AuthResponse)
def register(data: RegisterRequest, request: Request, db: Session = Depends(get_db)):
    """Create an account and its settings row; return a token."""
    enforce_ip(request, "register", REGISTER_IP)
    enforce(request, "register:all", REGISTER_ALL)

    # One account per email.
    if user_id_for_email(db, data.email) is not None:
        log_event("register_email_taken", request=request, email=data.email)
        raise HTTPException(
            status_code=400,
            detail="Email already registered",
        )

    # Profile fields: blanks are stored as NULL.
    name = _clean(data.name)
    gender = _clean(data.gender)
    birthdate = _clean(data.birthdate)
    country = _clean(data.country)
    city = _clean(data.city)
    street = _clean(data.street)
    phone = _clean(data.phone)

    # Take the id first so the new rows are written as their own owner.
    user_id = db.scalar(text("SELECT nextval(pg_get_serial_sequence('users', 'id'))"))
    bind_user(db, user_id)
    user = User(
        id=user_id,
        email=data.email,
        password_hash=hash_password(data.password),
        name=name,
        gender=gender,
        birthdate=birthdate,
        country=country,
        city=city,
        street=street,
        phone=phone,
        settings=UserSettings(
            gender=gender,
            birthdate=birthdate,
            processed_period_keys=[],
        ),
    )

    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        # Another sign-up with the same email won the race.
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail="Email already registered",
        ) from None
    db.refresh(user)
    log_event("register", request=request, user_id=user.id)

    # Signed in straight away.
    token = create_access_token(user)

    return {
        "access_token": token,
        "token_type": "bearer",
    }


def _login_failed(request: Request, email: str, user_id: int | None) -> HTTPException:
    limiter.hit(email_key("login-failures", email), LOGIN_FAILURES_EMAIL)
    log_event(
        "login_failed",
        request=request,
        level=logging.WARNING,
        user_id=user_id,
        email=email,
    )
    return HTTPException(
        status_code=401,
        detail="Invalid email or password",
    )


@app.post("/auth/login", response_model=AuthResponse)
def login(data: LoginRequest, request: Request, db: Session = Depends(get_db)):
    """Check the password and return a token.

    Wrong passwords count per email and per account; five in a row lock
    sign-in for LOGIN_LOCKOUT.
    """
    enforce_ip(request, "login", LOGIN_IP)
    # Counts wrong passwords per email whether or not the account exists, so
    # the 429 does not reveal which emails are registered.
    failures_key = email_key("login-failures", data.email)
    wait = limiter.check(failures_key, LOGIN_FAILURES_EMAIL)
    if wait > 0:
        log_event("login_throttled", request=request, level=logging.WARNING, email=data.email)
        raise too_many(wait)

    # The account, and whether it is locked.
    user_id = user_id_for_email(db, data.email)
    if user_id is None:
        burn_password_check(data.password)
        raise _login_failed(request, data.email, None)

    bind_user(db, user_id)
    user = db.get(User, user_id)
    now = utc_now()
    if user.locked_until is not None and user.locked_until > now:
        log_event("login_locked", request=request, level=logging.WARNING, user_id=user.id)
        raise too_many((user.locked_until - now).total_seconds())

    # Wrong password: count it, and lock after MAX_FAILED_LOGINS in a row.
    if not verify_password(data.password, user.password_hash):
        user.failed_login_count += 1
        if user.failed_login_count >= MAX_FAILED_LOGINS:
            user.failed_login_count = 0
            user.locked_until = now + LOGIN_LOCKOUT
            log_event("account_locked", request=request, level=logging.WARNING, user_id=user.id)
        db.commit()
        raise _login_failed(request, data.email, user.id)

    # Right password: clear the failure count and any expired lock.
    if user.failed_login_count or user.locked_until is not None:
        user.failed_login_count = 0
        user.locked_until = None
        db.commit()
    limiter.reset(failures_key)
    log_event("login", request=request, user_id=user.id)

    token = create_access_token(user)

    return {
        "access_token": token,
        "token_type": "bearer",
    }


def _clean(value: str | None) -> str | None:
    if value is None:
        return None
    trimmed = value.strip()
    return trimmed or None


def _profile_text(user: User, field: str, *, settings_fallback: bool = False) -> str | None:
    direct = _clean(getattr(user, field))
    if direct:
        return direct
    if not settings_fallback or user.settings is None:
        return None
    return _clean(getattr(user.settings, field, None))


def _user_payload(user: User) -> dict:
    return {
        "id": user.id,
        "email": user.email,
        "name": _clean(user.name),
        "gender": _profile_text(user, "gender", settings_fallback=True),
        "birthdate": _profile_text(user, "birthdate", settings_fallback=True),
        "country": _clean(user.country),
        "city": _clean(user.city),
        "street": _clean(user.street),
        "phone": _clean(user.phone),
        "data_key": _data_key(user),
        **photo_meta(),
    }


def _data_key(user: User) -> dict | None:
    if not user.wrapped_key or not user.key_salt or not user.key_iterations:
        return None
    return {
        "salt": user.key_salt,
        "iterations": user.key_iterations,
        "wrapped_key": user.wrapped_key,
    }


@app.get("/auth/me")
def get_me(current_user: User = Depends(get_current_user)):
    """The signed-in user's profile and data key."""
    return _user_payload(current_user)


@app.put("/auth/key")
def store_data_key(
    data: DataKeyIn,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Store the wrapped data key once; 409 when one is already set."""
    enforce(request, f"data-key:user:{current_user.id}", DATA_KEY_USER)
    # Set once. Replacing it would leave the encrypted rows unreadable.
    if current_user.wrapped_key:
        raise HTTPException(status_code=409, detail="Data key already set")
    current_user.key_salt = data.salt
    current_user.key_iterations = data.iterations
    current_user.wrapped_key = data.wrapped_key
    db.commit()
    db.refresh(current_user)
    log_event("data_key_set", request=request, user_id=current_user.id)
    return {"data_key": _data_key(current_user)}


@app.post("/auth/password/forgot")
def forgot_password(
    data: ForgotPasswordRequest,
    request: Request,
    background_tasks: BackgroundTasks,
):
    """Email a reset code. Answers the same whether or not the email exists."""
    if not password_reset.email_configured():
        raise HTTPException(status_code=503, detail="Email is not configured")
    enforce_ip(request, "forgot", FORGOT_IP)
    enforce(request, email_key("forgot", data.email), FORGOT_EMAIL)
    enforce(request, "forgot:all", FORGOT_ALL)
    log_event("password_reset_requested", request=request, email=data.email)
    # Same reply, at the same speed, whether or not the email has an account:
    # the lookup and the email happen after the response.
    background_tasks.add_task(password_reset.email_code, data.email)
    return {"ok": True}


@app.post("/auth/password/reset")
def reset_password(
    data: ResetPasswordRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Set a new password with an emailed code.

    Signs out every device and drops the data key and the text it sealed,
    which the new password cannot unwrap.
    """
    enforce_ip(request, "reset", RESET_IP)
    enforce(request, email_key("reset", data.email), RESET_EMAIL)

    # The account and its code; a failed check still counts the attempt.
    user_id = user_id_for_email(db, data.email)
    if user_id is None:
        burn_password_check(data.code)
        log_event("password_reset_failed", request=request, level=logging.WARNING, email=data.email)
        raise HTTPException(status_code=400, detail="Invalid or expired code")
    bind_user(db, user_id)
    user = db.get(User, user_id)
    if not password_reset.check_code(user, data.code, utc_now()):
        db.commit()
        log_event("password_reset_failed", request=request, level=logging.WARNING, user_id=user.id)
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    # New password; everything tied to the old one is dropped.
    user.password_hash = hash_password(data.new_password)
    # Every signed-in device has to sign in again.
    user.token_version += 1
    password_reset.clear_code(user)
    # The code proved the email belongs to them; lift any sign-in lock.
    user.failed_login_count = 0
    user.locked_until = None
    # The data key was wrapped with the old password and cannot be recovered.
    # The next sign-in creates a new one.
    user.key_salt = None
    user.key_iterations = None
    user.wrapped_key = None
    password_reset.drop_sealed_text(db, user.id)
    db.commit()
    limiter.reset(email_key("login-failures", data.email))
    log_event("password_reset", request=request, user_id=user.id)
    return {"ok": True}


@app.post("/auth/password/change", response_model=AuthResponse)
def change_password(
    data: ChangePasswordRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Change the password; other devices are signed out."""
    enforce(request, f"password-change:user:{current_user.id}", PASSWORD_CHANGE_USER)
    if not verify_password(data.current_password, current_user.password_hash):
        log_event(
            "password_change_failed",
            request=request,
            level=logging.WARNING,
            user_id=current_user.id,
        )
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    if current_user.wrapped_key and data.data_key is None:
        raise HTTPException(status_code=400, detail="Data key is required")

    current_user.password_hash = hash_password(data.new_password)
    # Other devices are signed out; this one gets a fresh token below.
    current_user.token_version += 1
    if data.data_key is not None:
        current_user.key_salt = data.data_key.salt
        current_user.key_iterations = data.data_key.iterations
        current_user.wrapped_key = data.data_key.wrapped_key
    db.commit()
    db.refresh(current_user)
    log_event("password_changed", request=request, user_id=current_user.id)
    return {
        "access_token": create_access_token(current_user),
        "token_type": "bearer",
    }


@app.delete("/auth/account", status_code=204)
def delete_account(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Delete the account and every row it owns."""
    enforce(request, f"account-delete:user:{current_user.id}", ACCOUNT_DELETE_USER)
    user_id = current_user.id
    # Rows owned by the user go with it (ORM cascade and ON DELETE CASCADE).
    db.delete(current_user)
    db.commit()
    log_event("account_deleted", request=request, user_id=user_id)


# Profile photos were removed. These stay for older app versions: an upload
# is dropped unread and answered as "no photo", so the app stops retrying it
# and removes the photo on its next sync.
@app.put("/auth/photo")
def upload_photo(_current_user: User = Depends(get_current_user)):
    """Legacy: accept and drop a photo upload."""
    return photo_meta()


@app.get("/auth/photo")
def download_photo(_current_user: User = Depends(get_current_user)):
    """Legacy: there is never a photo."""
    raise HTTPException(status_code=404, detail="No profile photo")


@app.delete("/auth/photo")
def delete_photo(_current_user: User = Depends(get_current_user)):
    """Legacy: nothing to delete."""
    return photo_meta()
