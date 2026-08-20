# pylint: disable=invalid-name
"""Конфигурация Superset для docker-compose.

Ожидаемые переменные окружения (часть задаётся в docker-compose.yml, часть — в .env):

- SUPERSET_SECRET_KEY — из .env
- SQLALCHEMY_DATABASE_URI — из compose (PostgreSQL 17, сервис db)
- REDIS_URL — из compose (Redis 7, сервис redis; Celery broker/backend и кэш)

Прокси: nginx завершает TLS; ENABLE_PROXY_FIX включён.

Аутентификация: по умолчанию OAuth2/OIDC (ADFS), либо только БД — SUPERSET_AUTH_TYPE=db (см. env.example).
"""

import os

from superset.config import CeleryConfig as BaseCeleryConfig


def _require(name: str) -> str:
    v = os.environ.get(name)
    if not v:
        raise ValueError(f"environment variable {name} is required")
    return v


def _bool_env(name: str, default: str = "false") -> bool:
    return os.environ.get(name, default).lower() in ("1", "true", "yes")


SECRET_KEY = _require("SUPERSET_SECRET_KEY")

SQLALCHEMY_DATABASE_URI = _require("SQLALCHEMY_DATABASE_URI")

ENABLE_PROXY_FIX = True

SUPERSET_WEBSERVER_TIMEOUT = int(os.environ.get("SUPERSET_WEBSERVER_TIMEOUT", "300"))

_redis_url = _require("REDIS_URL")

CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_REDIS_URL": _redis_url,
    "CACHE_KEY_PREFIX": "superset_",
    "CACHE_OPTIONS": {"socket_connect_timeout": 10},
}


class CeleryConfig(BaseCeleryConfig):
    broker_url = _redis_url
    result_backend = _redis_url


CELERY_CONFIG = CeleryConfig

WTF_CSRF_ENABLED = True
WTF_CSRF_TIME_LIMIT = 60 * 60 * 24 * 365

# За reverse proxy с HTTPS у cookie должен быть флаг Secure (см. SESSION_COOKIE_SECURE в .env)
SESSION_COOKIE_SECURE = os.environ.get("SESSION_COOKIE_SECURE", "true").lower() in (
    "1",
    "true",
    "yes",
)

MAPBOX_API_KEY = os.environ.get("MAPBOX_API_KEY", "")

# --- Аутентификация: OAuth2/OIDC (ADFS) или только локальная БД ---
# По умолчанию db — чтобы стек поднимался без ADFS; в проде задать SUPERSET_AUTH_TYPE=oauth
_auth = os.environ.get("SUPERSET_AUTH_TYPE", "db").lower().strip()

if _auth == "db":
    from flask_appbuilder.const import AUTH_DB

    AUTH_TYPE = AUTH_DB
else:
    from custom_sso_security_manager import CustomSsoSecurityManager
    from flask_appbuilder.security.manager import AUTH_OAUTH

    AUTH_TYPE = AUTH_OAUTH
    CUSTOM_SECURITY_MANAGER = CustomSsoSecurityManager

    _oauth_client_id = _require("OAUTH_CLIENT_ID")
    _oauth_client_secret = _require("OAUTH_CLIENT_SECRET")
    _metadata_url = os.environ.get(
        "OAUTH_SERVER_METADATA_URL",
        "https://adfs.example.com/adfs/.well-known/openid-configuration",
    )

    OAUTH_PROVIDERS = [
        {
            "name": "SSO",
            "token_key": "access_token",
            "icon": "fa-windows",
            "remote_app": {
                "client_id": _oauth_client_id,
                "client_secret": _oauth_client_secret,
                "server_metadata_url": _metadata_url,
                "client_kwargs": {
                    "scope": "openid email profile",
                },
            },
        }
    ]

    AUTH_USER_REGISTRATION = True
    AUTH_USER_REGISTRATION_ROLE = os.environ.get(
        "AUTH_USER_REGISTRATION_ROLE",
        "Public",
    )

    # Имена групп должны совпадать с выдачей ADFS в токене (role_keys → см. custom_sso_security_manager)
    AUTH_ROLES_MAPPING = {
        "Estate Superset Administrators": ["Admin"],
        "Estate Superset Users": ["Public"],
        "Estate Superset Manager": ["Manager"],
        "Estate Superset SQL_engineer": ["SQL_engineer"],
    }

    AUTH_ROLES_SYNC_AT_LOGIN = _bool_env("AUTH_ROLES_SYNC_AT_LOGIN", "true")
