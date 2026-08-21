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

RUN apt update \
  # Installing `poetry` package manager:
  # https://github.com/python-poetry/poetry
  && curl -sSL 'https://install.python-poetry.org' | python - \
  && poetry --version \
  # Cleaning cache:
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && apt-get clean -y && rm -rf /var/lib/apt/lists/*

WORKDIR /root/services/fix_gateway

ENV PYTHONPATH=/root/services/fix_gateway

COPY ./services/fix_gateway/pyproject.toml ./services/fix_gateway/poetry.lock /root/services/fix_gateway/
COPY ./libraries/logger /root/libraries/logger/
COPY ./libraries/fix_trade_app /root/libraries/fix_trade_app/
COPY ./libraries/fix_parser /root/libraries/fix_parser/
COPY ./libraries/slot /root/libraries/slot/

RUN poetry config virtualenvs.create false \
  && poetry install --no-interaction --no-ansi -vvv \
  && rm -rf $POETRY_CACHE_DIR \
  && pip3 install quickfix

COPY ./services/fix_gateway /root/services/fix_gateway

CMD ["python3", "fix_gateway/market_trader.py"]
