#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
CODEC="${1:-ZSTD}"
check_stack

echo "=== 0. Схемы ==="; tq_file sql/00_schemas.sql

echo "=== 1. Bronze (кодек $CODEC) ==="
sed "s/__CODEC__/$CODEC/g" sql/10_bronze.sql.tpl > logs/_bronze_render.sql
time tq_file logs/_bronze_render.sql

echo "=== 1a. Отчёт качества Bronze ==="; tq_file sql/15_quality.sql
echo "=== 2. Silver (очистка, нормализация, обогащение) ==="; time tq_file sql/20_silver.sql
echo "--- Silver: проверка диапазонов и обогащённых колонок ---"
tq "SELECT count(*) AS rows_cnt, count_if(line_revenue IS NULL) AS null_revenue, min(days_to_ship) AS min_days, max(days_to_ship) AS max_days, round(avg(days_to_ship), 2) AS avg_days FROM lakekeeper.silver.order_lines"
tq "DESCRIBE lakekeeper.silver.order_lines"
echo "=== 3. Gold ===";   time tq_file sql/30_gold.sql
echo "=== 4. Проверка Gold против Q3 напрямую на tpch.sf1 ==="; tq_file sql/40_verify.sql
echo "=== 5. Метрики слоёв ==="; tq_file sql/50_metrics.sql
echo "=== Свойства кодека (из \$properties) ==="
tq "SELECT 'bronze.lineitem' t, key, value FROM lakekeeper.bronze.\"lineitem\$properties\" WHERE key LIKE 'write.%' UNION ALL SELECT 'silver.order_lines', key, value FROM lakekeeper.silver.\"order_lines\$properties\" WHERE key LIKE 'write.%' UNION ALL SELECT 'gold.shipping_priority', key, value FROM lakekeeper.gold.\"shipping_priority\$properties\" WHERE key LIKE 'write.%'"
echo "ГОТОВО"
