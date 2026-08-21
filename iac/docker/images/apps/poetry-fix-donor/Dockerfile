FROM python:3.10

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

RUN apt update && apt install -y stunnel4 \
  # Installing `poetry` package manager:
  # https://github.com/python-poetry/poetry
  && curl -sSL 'https://install.python-poetry.org' | python - \
  && poetry --version \
  # Cleaning cache:
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && apt-get clean -y && rm -rf /var/lib/apt/lists/*


WORKDIR /root/services/market_feed
COPY ./services/market_feed/poetry.lock ./services/market_feed/pyproject.toml /root/services/market_feed/

RUN poetry config virtualenvs.create false \
  && poetry install --no-interaction --no-ansi --no-dev \
  && rm -rf $POETRY_CACHE_DIR

ENV PYTHONPATH=/root/services/market_feed

COPY ./services/market_feed /root/services/market_feed

RUN ["chmod", "+x", "entrypoint.sh"]
ENTRYPOINT ["/root/services/market_feed/entrypoint.sh"]
