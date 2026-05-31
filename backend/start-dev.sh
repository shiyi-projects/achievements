#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE="${ENV_FILE:-.env.dev}"
IMAGE="${IMAGE:-achievements/backend:dev}"
CONTAINER_NAME="${CONTAINER_NAME:-achievements-api}"
HOST_PORT="${HOST_PORT:-8001}"
CONTAINER_PORT="${CONTAINER_PORT:-8084}"

if [[ ! -f "$ENV_FILE" ]]; then
  cat >&2 <<EOF
Missing $ENV_FILE.
Create it first, for example:
  cp .env.example $ENV_FILE

For the current dev Docker setup, $ENV_FILE should normally point DB/Redis to
host.docker.internal and set AUTH_ENABLED=true.
EOF
  exit 1
fi

echo "==> Building backend image: $IMAGE"
docker compose -f docker-compose.yml build api

echo "==> Running database migrations with $ENV_FILE"
docker run --rm \
  --env-file "$ENV_FILE" \
  --add-host host.docker.internal:host-gateway \
  -v "${PWD}/app:/app/app:ro" \
  -v "${PWD}/alembic:/app/alembic:ro" \
  -v "${PWD}/alembic.ini:/app/alembic.ini:ro" \
  "$IMAGE" \
  alembic upgrade head

echo "==> Restarting API container: $CONTAINER_NAME"
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

docker run -d \
  --name "$CONTAINER_NAME" \
  --env-file "$ENV_FILE" \
  --add-host host.docker.internal:host-gateway \
  -p "${HOST_PORT}:${CONTAINER_PORT}" \
  -v "${PWD}/app:/app/app:ro" \
  -v "${PWD}/alembic:/app/alembic:ro" \
  -v "${PWD}/alembic.ini:/app/alembic.ini:ro" \
  "$IMAGE" \
  uvicorn app.main:app --host 0.0.0.0 --port "$CONTAINER_PORT" --reload

echo "==> Waiting for health check: http://localhost:${HOST_PORT}/api/v1/healthz"
for i in {1..30}; do
  if curl -fsS "http://localhost:${HOST_PORT}/api/v1/healthz" >/dev/null; then
    echo
    echo "Dev backend is ready: http://localhost:${HOST_PORT}"
    echo "OpenAPI docs:        http://localhost:${HOST_PORT}/docs"
    echo
    echo "Frontend example:"
    echo "  flutter run -d windows --dart-define=API_BASE_URL=http://localhost:${HOST_PORT}"
    exit 0
  fi
  sleep 1
  printf '.'
done

echo
cat >&2 <<EOF
API did not become healthy in time.
Recent logs:
EOF
docker logs --tail 120 "$CONTAINER_NAME" >&2
exit 1
