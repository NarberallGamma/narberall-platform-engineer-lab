# Superset (estate prod) — Docker Compose

Стек по официальному образу [apache/superset](https://hub.docker.com/r/apache/superset) с фиксированным тегом **`6.0.0`**: Gunicorn, Celery worker, Celery beat. **PostgreSQL** и **Redis** — контейнеры в том же `docker-compose.yml`; наружу на хосте только **`127.0.0.1:8088`** для обратного прокси. TLS — на отдельном **nginx** `1.29.0` (`network_mode: host`), по аналогии с `estate-prod-app-1` в `/docker/nginx`.

Команды и имена сервисов согласованы с upstream [docker-compose-non-dev.yml](https://github.com/apache/superset/blob/master/docker-compose-non-dev.yml) (`app-gunicorn`, `docker-init.sh`, `docker-bootstrap.sh` для worker/beat). В upstream заявлено, что compose не позиционируется как production; для estate это осознанный self-hosted вариант с внешним nginx и привязкой портов к localhost. Отличие от upstream: образ **Docker Hub** вместо `build`, **профиль `init`** у `superset-init` (повторный `docker compose up -d` не перезапускает init), **bind-монты** для данных и **read-only** `pythonpath` вместо томов из репозитория разработки. Версия PostgreSQL в образе **`postgres:17-alpine`**, как в non-dev.

### Где что хранится

| Данные | Место |
|--------|--------|
| Метаданные Superset (дашборды, датасеты, пользователи) | Том **`./data/postgres`** (PostgreSQL 17 в контейнере `db`) |
| Кэш и очереди Celery | Том **`./data/redis`** (Redis 7 в контейнере `redis`, AOF) |
| Домашний каталог приложения (`SUPERSET_HOME` → `/app/superset_home`) | **`./data/superset_home`** относительно `docker-compose.yml` |

Каталоги под тома создаются при первом запуске; при необходимости заранее: `mkdir -p data/postgres data/redis data/superset_home`.

## Расположение на сервере

Имеет смысл скопировать каталог `superset` в `/docker/superset` (или `/docker/apps/superset`) на `estate-prod-superset` (отдельный диск `/docker` уже смонтирован).

## Конфигурация

1. `cp env.example .env`
2. Создать доверенный CA bundle для контейнера (том `./ca-certificates.crt` в `docker-compose.yml`): на Linux  
   `sh scripts/prepare-ca-bundle.sh`  
   либо вручную скопировать хостовый `/etc/ssl/certs/ca-certificates.crt` в `ca-certificates.crt` рядом с compose (файл в `.gitignore`).
3. Заполнить `SUPERSET_SECRET_KEY`, `POSTGRES_PASSWORD`, `ADMIN_PASSWORD`. После init первый вход в UI: пользователь **`admin`**, пароль из `ADMIN_PASSWORD` (в upstream `docker-init.sh` для 6.0.0 зашиты логин и `admin@superset.com`).
4. **OAuth / ADFS (прод):** в `.env` задать `SUPERSET_AUTH_TYPE=oauth`, `OAUTH_CLIENT_ID`, `OAUTH_CLIENT_SECRET` (конфиденциальные строки из регистрации приложения в ADFS). При необходимости поправить `OAUTH_SERVER_METADATA_URL`, `ADFS_EXTRA_HOST_ENTRY`, `OAUTHLIB_INSECURE_TRANSPORT`.
5. Положить `example.com.crt` и `example.com.key` в `nginx/certs/` (те же файлы, что на app01).

### Вход через ADFS и что настраивается где

- **ADFS:** выдача токена OIDC, membership в группах Windows (`Estate Superset Administrators` и т.д.). Имена групп в токене должны совпадать с ключами в `AUTH_ROLES_MAPPING` в `pythonpath/superset_config.py`. Поля в JWT (`upn`, `email`, `roles`, …) задаются на стороне ADFS и должны соответствовать ожиданиям `custom_sso_security_manager.py`.
- **Superset UI:** подключения к **базам данных** (источники для дашбордов, SQL Lab), выдача прав на датасеты, строковая безопасность, роли поверх уже назначенных из групп — это **не** настраивается в ADFS, а в меню Superset (Data → Databases, Security → …).

## OAuth / OIDC (файлы в репозитории)

| Файл | Назначение |
|------|------------|
| `requirements-local.txt` | `authlib` — подтягивается entrypoint-ом образа Superset при старте |
| `pythonpath/custom_sso_security_manager.py` | Разбор JWT из `access_token`, маппинг claim → пользователь и `role_keys` |
| `pythonpath/superset_config.py` | `OAUTH_PROVIDERS`, `AUTH_ROLES_MAPPING`, переключение `SUPERSET_AUTH_TYPE` |
| `ca-certificates.crt` | Bundle для TLS к ADFS внутри контейнера (не коммитировать) |
| `docker-compose.yml` | `extra_hosts` для ADFS, монтирование CA и `requirements-local.txt` |

## Первый запуск (миграции и admin)

Сервис **`superset-init`** вынесен в **профиль `init`**, чтобы обычный `docker compose up -d` не перезапускал создание admin и не падал при повторе.

Из каталога с `docker-compose.yml`:

```bash
docker compose up -d db redis
docker compose --profile init run --rm superset-init
docker compose up -d
```

Повторный запуск с профилем init после появления admin приведёт к ошибке создания пользователя — инициализация только при пустой БД.

## Повседневная работа

```bash
docker compose up -d
docker compose pull   # при смене тега в .env
```

## Nginx

```bash
cd nginx
docker compose up -d
```

Проверить, что DNS `superset.example.com` указывает на эту ВМ и с балансировщика/фаервола доступны 443 (и при необходимости 80 для редиректа).

## Обновление версии Superset

В `.env` задать новый тег `SUPERSET_IMAGE`, затем:

```bash
docker compose pull
docker compose run --rm superset superset db upgrade
docker compose up -d
```

Повторно вызывать `superset-init` с профилем init при обновлении не нужно (там полный `superset init` и создание admin).

## Резервное копирование

Для снимка состояния копировать каталоги **`./data/postgres`**, **`./data/redis`**, **`./data/superset_home`** (с остановкой контейнеров или через снапшоты тома — по политике эксплуатации).

## Ссылки

- [Docker Compose (официально)](https://superset.apache.org/docs/installation/docker-compose/)
- [Конфигурация](https://superset.apache.org/docs/configuration/configuring-superset/)

## LDAP

Отдельно не используется: вход через **OIDC к ADFS** (см. выше).
