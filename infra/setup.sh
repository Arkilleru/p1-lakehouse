#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "==> 0. Проверка Docker"
if ! command -v docker >/dev/null 2>&1; then
  echo "!! docker не найден в PATH. Установи Docker Desktop: https://www.docker.com/products/docker-desktop/"
  exit 1
fi
docker --version
if ! docker ps >/dev/null 2>&1; then
  echo "!! Docker демон не отвечает. Запусти Docker Desktop и дождись, пока кит перестанет 'думать'."
  exit 1
fi
echo "Docker OK"

echo "==> 0.1 Проверка портов 9000/9001/5432/8181/8080"
BUSY=$(lsof -nP -iTCP:9000 -iTCP:9001 -iTCP:5432 -iTCP:8181 -iTCP:8080 -sTCP:LISTEN 2>/dev/null || true)
if [ -n "$BUSY" ]; then
  echo "!! Заняты порты:"
  echo "$BUSY"
  echo "Останови процессы или поменяй порты в этом скрипте вручную."
  exit 1
fi
echo "Порты свободны"

ADD_HOST_FLAG=""
if [ "$(uname -s)" = "Linux" ]; then
  ADD_HOST_FLAG="--add-host host.docker.internal:host-gateway"
fi

echo "==> 1. MinIO"
docker rm -f lakehouse-minio >/dev/null 2>&1 || true
docker run -d --name lakehouse-minio $ADD_HOST_FLAG \
  -p 9000:9000 -p 9001:9001 \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=minioadmin \
  -v minio-data:/data \
  pgsty/silo:latest server /data --console-address ":9001"

echo "Ждём, пока MinIO поднимется..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:9000/minio/health/live >/dev/null 2>&1; then break; fi
  sleep 1
done

echo "Создаём bucket warehouse"
docker run --rm --entrypoint /bin/sh --add-host host.docker.internal:host-gateway \
  pgsty/mc:latest -c "mc alias set m http://host.docker.internal:9000 minioadmin minioadmin && mc mb --ignore-existing m/warehouse" || \
  echo "(если bucket уже существует - это нормально)"

echo "==> 2. Postgres"
docker rm -f lakehouse-pg >/dev/null 2>&1 || true
docker run -d --name lakehouse-pg \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  -v pg-data:/var/lib/postgresql/data \
  postgres:17

echo "Ждём готовности Postgres..."
for i in $(seq 1 30); do
  if docker exec lakehouse-pg pg_isready >/dev/null 2>&1; then break; fi
  sleep 1
done
docker exec lakehouse-pg pg_isready

echo "==> 3. Миграции Lakekeeper"
docker run --rm $ADD_HOST_FLAG \
  -e 'LAKEKEEPER__PG_ENCRYPTION_KEY=This-is-NOT-Secure!' \
  -e 'LAKEKEEPER__PG_DATABASE_URL_READ=postgresql://postgres:postgres@host.docker.internal:5432/postgres' \
  -e 'LAKEKEEPER__PG_DATABASE_URL_WRITE=postgresql://postgres:postgres@host.docker.internal:5432/postgres' \
  quay.io/lakekeeper/catalog:latest-main migrate

echo "==> 4. Lakekeeper"
docker rm -f lakekeeper >/dev/null 2>&1 || true
docker run -d --name lakekeeper $ADD_HOST_FLAG \
  -e 'LAKEKEEPER__PG_ENCRYPTION_KEY=This-is-NOT-Secure!' \
  -e 'LAKEKEEPER__PG_DATABASE_URL_READ=postgresql://postgres:postgres@host.docker.internal:5432/postgres' \
  -e 'LAKEKEEPER__PG_DATABASE_URL_WRITE=postgresql://postgres:postgres@host.docker.internal:5432/postgres' \
  -p 8181:8181 \
  quay.io/lakekeeper/catalog:latest-main serve

echo "Ждём готовности Lakekeeper..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:8181/health >/dev/null 2>&1; then break; fi
  sleep 1
done
curl -sf http://localhost:8181/health && echo "Lakekeeper health OK"

echo "==> 4.4 Bootstrap + регистрация warehouse demo"
curl -s -X POST http://localhost:8181/management/v1/bootstrap \
  -H "Content-Type: application/json" \
  -d '{"accept-terms-of-use": true}' -w "\n(HTTP %{http_code})\n" || true

curl -s -X POST http://localhost:8181/management/v1/warehouse \
  -H "Content-Type: application/json" \
  -d @create-warehouse.json -w "\n(HTTP %{http_code})\n"

echo "==> 5. Trino"
docker rm -f trino >/dev/null 2>&1 || true
docker run -d --name trino \
  -p 8080:8080 \
  -v "$(pwd)/catalog:/etc/trino/catalog" \
  trinodb/trino:476

echo "Ждём готовности Trino (может занять ~20-30 сек)..."
for i in $(seq 1 60); do
  if curl -sf http://localhost:8080/v1/info >/dev/null 2>&1; then break; fi
  sleep 1
done
curl -sf http://localhost:8080/v1/info && echo
echo
echo "==> Готово! Проверь: docker ps"
docker ps
echo
echo "Дальше: открой DBeaver, подключись к Trino (localhost:8080, catalog lakekeeper) и выполни SQL из гайда."
