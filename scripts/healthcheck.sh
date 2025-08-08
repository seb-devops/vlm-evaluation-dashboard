#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${COMPOSE_PROJECT_NAME:-vlm-dashboard}"

echo "[healthcheck] Bringing up services..."
docker compose up -d --wait

echo "[healthcheck] Waiting for Postgres to be healthy..."
docker compose ps postgres | grep -q "healthy"

echo "[healthcheck] Waiting for Redis to be healthy..."
docker compose ps redis | grep -q "healthy"

echo "[healthcheck] Waiting for MinIO liveness..."
# Poll MinIO HTTP liveness instead of compose health status
for i in {1..60}; do
  if curl -fsS "http://localhost:${MINIO_PORT_API:-9000}/minio/health/live" >/dev/null; then
    break
  fi
  sleep 2
done

echo "[healthcheck] Verifying Postgres connectivity..."
docker compose exec -T postgres psql -U "${POSTGRES_USER:-vlm}" -d "${POSTGRES_DB:-vlm}" -c "SELECT 1;" >/dev/null

echo "[healthcheck] Verifying Redis connectivity..."
docker compose exec -T redis redis-cli ping | grep -q PONG

echo "[healthcheck] Verifying MinIO liveness endpoint..."
curl -fsS "http://localhost:${MINIO_PORT_API:-9000}/minio/health/live" >/dev/null

echo "[healthcheck] OK — all services are up and reachable."


