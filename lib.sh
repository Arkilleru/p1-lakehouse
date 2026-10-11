cd "$(dirname "${BASH_SOURCE[0]}")"
mkdir -p logs
LOGNAME_="$(basename "$0" .sh)"
exec > >(tee "logs/${LOGNAME_}.log") 2>&1

tq_file() { docker exec -i trino trino --output-format ALIGNED < "$1"; }
tq()      { docker exec trino trino --output-format ALIGNED --execute "$1"; }
tq_csv()  { docker exec trino trino --output-format CSV_UNQUOTED --execute "$1" 2>/dev/null; }

check_stack() {
  for c in lakehouse-minio lakehouse-pg lakekeeper trino; do
    if [ "$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null)" != "true" ]; then
      echo "Контейнер $c не запущен. Сначала: bash ../lakehouse/restart_all.sh"; exit 1
    fi
  done
  curl -sf http://localhost:8080/v1/info | grep -q '"starting":false' || { echo "Trino ещё стартует"; exit 1; }
  echo "Стек работает: minio, postgres, lakekeeper, trino"
}
