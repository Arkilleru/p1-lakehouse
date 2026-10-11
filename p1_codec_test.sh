#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
check_stack
tq_file sql/00_schemas.sql >/dev/null

for CODEC in GZIP ZSTD; do
  echo
  echo "##################  BRONZE: $CODEC  ##################"
  sed "s/__CODEC__/$CODEC/g" sql/10_bronze.sql.tpl > logs/_bronze_render.sql
  echo "--- время записи Bronze ($CODEC) ---"
  time tq_file logs/_bronze_render.sql >/dev/null
  echo "--- размер Bronze ($CODEC) ---"
  tq "SELECT '$CODEC' AS codec, sum(files) AS files, sum(bytes) AS bytes, round(CAST(sum(bytes) AS double)/1048576, 4) AS size_mb FROM (SELECT count(*) AS files, sum(file_size_in_bytes) AS bytes FROM lakekeeper.bronze.\"customer\$files\" UNION ALL SELECT count(*), sum(file_size_in_bytes) FROM lakekeeper.bronze.\"orders\$files\" UNION ALL SELECT count(*), sum(file_size_in_bytes) FROM lakekeeper.bronze.\"lineitem\$files\")"
  for i in 1 2 3; do
    echo "--- Q3 на Bronze ($CODEC), прогон $i ---"
    time tq "/* p1_q3_${CODEC}_run${i} */ SELECT l.orderkey, sum(l.extendedprice * (1 - l.discount)) AS revenue, o.orderdate, o.shippriority FROM lakekeeper.bronze.customer AS c JOIN lakekeeper.bronze.orders AS o ON c.custkey = o.custkey JOIN lakekeeper.bronze.lineitem AS l ON l.orderkey = o.orderkey WHERE c.mktsegment = 'BUILDING' AND o.orderdate < DATE '1995-03-15' AND l.shipdate > DATE '1995-03-15' GROUP BY l.orderkey, o.orderdate, o.shippriority ORDER BY revenue DESC LIMIT 10" >/dev/null
  done
done

echo
echo "##################  Время выполнения из system.runtime.queries  ##################"
tq "SELECT regexp_extract(query, 'p1_q3_[A-Z]+_run[0-9]') AS tag, state, date_diff('millisecond', started, \"end\") AS exec_ms FROM system.runtime.queries WHERE query LIKE '%p1_q3_%' AND query NOT LIKE '%system.runtime.queries%' ORDER BY created"
echo "ГОТОВО"
