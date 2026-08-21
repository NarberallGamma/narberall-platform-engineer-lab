FROM python:3.9 AS dev_build


ENV PYTHONFAULTHANDLER=1 \
  PYTHONUNBUFFERED=1 \
  PYTHONHASHSEED=random \
  PYTHONDONTWRITEBYTECODE=1 \
  # pip:
  PIP_NO_CACHE_DIR=off \
  PIP_DISABLE_PIP_VERSION_CHECK=on \
  PIP_DEFAULT_TIMEOUT=100 \
  # poetry:
  POETRY_VERSION=1.1.12 \
  POETRY_CACHE_DIR="/var/cache/pypoetry" \
  PATH="$PATH:/root/.local/bin"

RUN apt update \
  # Installing `poetry` package manager:
  # https://github.com/python-poetry/poetry
  && curl -sSL 'https://install.python-poetry.org' | python - \
  && poetry --version \
  # Install deps
  && apt-get install -y python3-dev \
  # Cleaning cache:
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && apt-get clean -y && rm -rf /var/lib/apt/lists/*

WORKDIR /root/services/admin_api
COPY ./services/admin_api/pyproject.toml ./services/admin_api/poetry.lock /root/services/admin_api/
COPY ./libraries/market_lib /root/libraries/market_lib/
COPY ./libraries/logger /root/libraries/logger/
COPY ./libraries/vendor_sdk /root/libraries/vendor_sdk/
COPY ./libraries/market_sdk /root/libraries/market_sdk/
COPY ./libraries/protobuf /root/libraries/protobuf/
COPY ./libraries/db_lib /root/libraries/db_lib/
COPY ./libraries/slot /root/libraries/slot/

RUN poetry config virtualenvs.create false \
  && poetry install --no-interaction --no-ansi --no-dev -vvv \
  && rm -rf $POETRY_CACHE_DIR

COPY ./services/admin_api /root/services/admin_api

ENV FLASK_APP=admin_api/wsgi.py

RUN ["chmod", "+x", "/root/services/admin_api/entrypoint.sh"]
ENTRYPOINT ["/root/services/admin_api/entrypoint.sh"]
