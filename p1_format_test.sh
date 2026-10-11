#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
check_stack

for FMT in PARQUET ORC; do
  for CODEC in NONE SNAPPY GZIP ZSTD; do
    f=$(echo "$FMT" | tr 'A-Z' 'a-z'); c=$(echo "$CODEC" | tr 'A-Z' 'a-z')
    S="fmt_${f}_${c}"
    TAG="p1_fmt_${FMT}_${CODEC}"
    echo
    echo "##################  $FMT / $CODEC  (схема $S)  ##################"
    cat > logs/_fmt_render.sql << SQL
SET SESSION lakekeeper.compression_codec = '$CODEC';
CREATE SCHEMA IF NOT EXISTS lakekeeper.$S;
DROP TABLE IF EXISTS lakekeeper.$S.customer;
CREATE TABLE lakekeeper.$S.customer WITH (format = '$FMT') AS SELECT custkey, mktsegment FROM tpch.sf1.customer;
DROP TABLE IF EXISTS lakekeeper.$S.orders;
CREATE TABLE lakekeeper.$S.orders WITH (format = '$FMT') AS SELECT orderkey, custkey, orderdate, shippriority FROM tpch.sf1.orders;
DROP TABLE IF EXISTS lakekeeper.$S.lineitem;
CREATE TABLE lakekeeper.$S.lineitem WITH (format = '$FMT') AS SELECT orderkey, linenumber, extendedprice, discount, shipdate FROM tpch.sf1.lineitem;
SQL
    echo "--- время записи ($FMT/$CODEC) ---"
    time tq_file logs/_fmt_render.sql >/dev/null
    echo "--- размер и файлы ($FMT/$CODEC) ---"
    tq "SELECT '$FMT' AS format, '$CODEC' AS codec, sum(files) AS files, sum(bytes) AS bytes, round(CAST(sum(bytes) AS double)/1048576, 4) AS size_mb FROM (SELECT count(*) AS files, sum(file_size_in_bytes) AS bytes FROM lakekeeper.$S.\"customer\$files\" UNION ALL SELECT count(*), sum(file_size_in_bytes) FROM lakekeeper.$S.\"orders\$files\" UNION ALL SELECT count(*), sum(file_size_in_bytes) FROM lakekeeper.$S.\"lineitem\$files\")"
    echo "--- кодек, записанный в свойствах таблицы ---"
    tq "SELECT key, value FROM lakekeeper.$S.\"lineitem\$properties\" WHERE key LIKE 'write.%compression-codec' OR key = 'write.format.default'"
    for i in 1 2 3; do
      tq "/* ${TAG}_run${i} */ SELECT l.orderkey, sum(l.extendedprice * (1 - l.discount)) AS revenue, o.orderdate, o.shippriority FROM lakekeeper.$S.customer AS c JOIN lakekeeper.$S.orders AS o ON c.custkey = o.custkey JOIN lakekeeper.$S.lineitem AS l ON l.orderkey = o.orderkey WHERE c.mktsegment = 'BUILDING' AND o.orderdate < DATE '1995-03-15' AND l.shipdate > DATE '1995-03-15' GROUP BY l.orderkey, o.orderdate, o.shippriority ORDER BY revenue DESC LIMIT 10" >/dev/null
    done
    echo "--- время Q3 из system.runtime.queries ($FMT/$CODEC) ---"
    tq "SELECT regexp_extract(query, 'p1_fmt_[A-Z]+_[A-Z]+_run[0-9]') AS tag, state, date_diff('millisecond', started, \"end\") AS exec_ms FROM system.runtime.queries WHERE query LIKE '%${TAG}_run%' AND query NOT LIKE '%system.runtime.queries%' ORDER BY created"
  done
done
echo "ГОТОВО"
