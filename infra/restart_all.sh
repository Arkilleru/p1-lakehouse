#!/usr/bin/env bash
set -euo pipefail

echo "==> Текущее состояние всех контейнеров"
docker ps -a --filter "name=lakehouse-pg" --filter "name=lakekeeper" --filter "name=trino" --filter "name=lakehouse-minio"
echo

echo "==> Запускаем MinIO"
docker start lakehouse-minio
for i in $(seq 1 30); do
  if curl -sf http://localhost:9000/minio/health/live >/dev/null 2>&1; then break; fi
  sleep 1
done
curl -sf http://localhost:9000/minio/health/live && echo " - MinIO health OK"
echo

echo "==> Запускаем Postgres"
docker start lakehouse-pg
for i in $(seq 1 30); do
  if docker exec lakehouse-pg pg_isready >/dev/null 2>&1; then break; fi
  sleep 1
done
docker exec lakehouse-pg pg_isready
echo

echo "==> Запускаем Lakekeeper"
docker start lakekeeper
for i in $(seq 1 30); do
  if curl -sf http://localhost:8181/health >/dev/null 2>&1; then break; fi
  sleep 1
done
curl -sf http://localhost:8181/health && echo " - Lakekeeper health OK"
echo

echo "==> Запускаем Trino"
docker start trino
for i in $(seq 1 60); do
  if curl -sf http://localhost:8080/v1/info >/dev/null 2>&1; then break; fi
  sleep 1
done
curl -sf http://localhost:8080/v1/info && echo
echo

echo "==> Итоговое состояние"
docker ps
