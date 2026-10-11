#!/usr/bin/env bash
cd "$(dirname "$0")"
bash p1_all.sh
bash p1_part2.sh
bash p1_spark.sh
bash p1_format_test.sh
echo "ВСЁ ГОТОВО. Логи: logs/"
