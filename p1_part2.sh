#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
check_stack
T=lakekeeper.silver.order_lines

echo "################  SCHEMA EVOLUTION на Silver  ################"
echo "--- схема и число файлов ДО ---"
tq "DESCRIBE $T"
tq "SELECT count(*) AS files_before FROM lakekeeper.silver.\"order_lines\$files\""
tq "SELECT count(*) AS rows_total FROM $T"
echo "--- ADD COLUMN discount_amount ---"
tq "ALTER TABLE $T ADD COLUMN discount_amount double"
echo "--- старые строки читают NULL в новой колонке ---"
tq "SELECT orderkey, extendedprice, discount, discount_amount FROM $T LIMIT 5"
tq "SELECT count(*) AS rows_total, count(discount_amount) AS new_col_not_null FROM $T"
echo "--- число файлов ПОСЛЕ (файлы не переписывались) ---"
tq "SELECT count(*) AS files_after FROM lakekeeper.silver.\"order_lines\$files\""
echo "--- RENAME COLUMN discount_amount -> line_discount ---"
tq "ALTER TABLE $T RENAME COLUMN discount_amount TO line_discount"
tq "DESCRIBE $T"
echo "--- убираем тестовую колонку, схема Silver как раньше ---"
tq "ALTER TABLE $T DROP COLUMN line_discount"
tq "DESCRIBE $T"

echo
echo "################  TIME TRAVEL: восстановление из снапшота  ################"
echo "--- история снапшотов ---"
tq "SELECT snapshot_id, committed_at, operation FROM lakekeeper.silver.\"order_lines\$snapshots\" ORDER BY committed_at"
SNAP=$(tq_csv "SELECT snapshot_id FROM lakekeeper.silver.\"order_lines\$snapshots\" ORDER BY committed_at DESC LIMIT 1")
echo "Хороший снапшот: $SNAP"
tq "SELECT count(*) AS rows_before_accident FROM $T"
echo "--- АВАРИЯ: случайно удалили строки (DELETE) ---"
tq "DELETE FROM $T WHERE orderdate < DATE '1995-01-01'"
tq "SELECT count(*) AS rows_after_accident FROM $T"
echo "--- старый снапшот цел: читаем его через FOR VERSION AS OF ---"
tq "SELECT count(*) AS rows_in_old_snapshot FROM $T FOR VERSION AS OF $SNAP"
echo "--- ВОССТАНОВЛЕНИЕ: rollback_to_snapshot ---"
if ! tq "ALTER TABLE $T EXECUTE rollback_to_snapshot($SNAP)"; then
  echo "(ALTER TABLE EXECUTE не прошёл, пробуем CALL)"
  tq "CALL lakekeeper.system.rollback_to_snapshot('silver', 'order_lines', $SNAP)"
fi
tq "SELECT count(*) AS rows_after_restore FROM $T"
tq "SELECT snapshot_id, committed_at, operation FROM lakekeeper.silver.\"order_lines\$snapshots\" ORDER BY committed_at"
echo "ГОТОВО"
