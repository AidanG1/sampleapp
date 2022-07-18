FROM python:3.10.2-slim as base

# Setup env
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1
ENV PYTHONUNBUFFERED=1
ENV PYTHONHASHSEED=random
ENV DJANGO_SETTINGS_MODULE=sampleapp.config.settings.prod


FROM node:lts-alpine AS js-deps
# Install application into container
COPY . .
RUN npm install
RUN npm run build

FROM base AS python-deps
# Install poetry and compilation dependencies
RUN pip install poetry==1.2.0b2
# Install python dependencies in /.venv
COPY pyproject.toml .
COPY poetry.lock .
ENV POETRY_VIRTUALENVS_IN_PROJECT true
run poetry install --without dev --no-interaction


FROM base AS runtime

# Copy virtual env from python-deps stage
COPY --from=python-deps /.venv /.venv
ENV PATH="/.venv/bin:$PATH"

# Create and switch to a new user
WORKDIR app

# Install application into container
COPY . .
COPY --from=js-deps /sampleapp/static ./sampleapp/static

ENV DJANGO_SETTINGS_MODULE="sampleapp.config.settings.prod"
RUN DJANGO_AWS_ACCESS_KEY_ID="" \
    DJANGO_AWS_SECRET_ACCESS_KEY="" \
    DJANGO_AWS_STORAGE_BUCKET_NAME="" \
    DJANGO_AWS_S3_ENDPOINT_URL="" \
    DJANGO_SECURE_SSL_REDIRECT=False \
    DJANGO_SECURE_HSTS_SECONDS=0 \
    DJANGO_SECRET_KEY="!!! CHANGE ME !!!" \
    DJANGO_ALLOWED_HOSTS="*" \
    APP_VERSION_RELEASE="build" \
    ENVIRONMENT="build" \
    SENTRY_DSN="" \
    REDIS_URL="" \
    REDIS_PASSWORD="" \
    DATABASE_URL="" \
    ALLOWED_HOSTS="*" \
    python ./manage.py collectstatic --noinput

CMD gunicorn sampleapp.config.asgi:application --bind 0.0.0.0:8080  -k uvicorn.workers.UvicornWorker --access-logfile - --preload