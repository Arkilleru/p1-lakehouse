# Практическая p1 — Lakehouse и медальон (вариант 1, TPC-H Q3 «Shipping Priority»)

ФИО: Шилов Артём. Масштаб данных: **sf1**. Полный отчёт с таблицами и обоснованиями — в [`отчет.md`](отчет.md).

## Что сделано

Локальный lakehouse из четырёх контейнеров: MinIO (pgsty/silo) → PostgreSQL → Lakekeeper (Iceberg REST Catalog) → Trino. Поверх него построен медальон для запроса Q3 (выручка по заказам сегмента BUILDING, топ-10):

| Слой | Таблица | Что происходит |
|---|---|---|
| Bronze | `bronze.customer`, `bronze.orders`, `bronze.lineitem` | загрузка сырых данных `tpch.sf1` как есть, только нужные запросу колонки |
| Silver | `silver.order_lines` | очистка (правила качества, дубли), нормализация (`upper(trim())`), обогащение (`line_revenue`, `days_to_ship`), фильтр Q3 и джойн трёх таблиц |
| Gold | `gold.shipping_priority` | витрина для BI: 10 строк (orderkey, revenue, orderdate, shippriority) |

Gold проверен против Q3, посчитанного напрямую на `tpch.sf1`: расхождений 0 (`sql/40_verify.sql`).

## Методология бенчмарка

Сравниваются 8 вариантов: формат Parquet и ORC × кодек NONE, SNAPPY, GZIP, ZSTD. Для каждого на одних и тех же данных Bronze (sf1, 7,65 млн строк) замеряются:

- **размер и число файлов** — по системной таблице Iceberg `$files`;
- **время записи** — `time` вокруг записи трёх таблиц;
- **скорость агрегации** — Q3 (три джойна, фильтры, `GROUP BY`) 3 раза, время из `system.runtime.queries`, в отчёте медиана.

Результаты: матрица в `отчет.md`, раздел 5; сырой вывод — `logs/p1_format_test.log` и `logs/p1_codec_test.log`. Итог: Parquet + ZSTD сжимает на 61 % относительно NONE, как GZIP, но пишется вдвое быстрее. Parquet на этих данных компактнее ORC. Для всех слоёв выбран Parquet + ZSTD.

## Масштаб sf1

В `lineitem` 6 млн строк (0,7 ГБ сырых). Запрос считается за доли секунды, Bronze пересоздаётся за секунды, результат детерминирован, поэтому его можно воспроизвести на любом ноутбуке. Подробное обоснование — в отчёте, раздел 1.

## Структура репозитория

| Путь | Что это |
|---|---|
| `infra/` | скрипты поднятия стека (`setup.sh`, `restart_all.sh`, `create-warehouse.json`, `catalog/*.properties`) |
| `sql/` | SQL слоёв Bronze/Silver/Gold, проверка и метрики |
| `p1_build.sh` | сборка медальона Bronze → Silver → Gold, проверка, метрики |
| `p1_codec_test.sh` | тест GZIP vs ZSTD на Bronze |
| `p1_format_test.sh` | матрица Parquet/ORC × NONE/SNAPPY/GZIP/ZSTD |
| `p1_run_everything.sh` | все прогоны подряд |
| `p1_part2.sh` | schema evolution и восстановление из снапшота (time travel) |
| `p1_spark.sh`, `spark/bronze_demo.py` | Spark в Docker читает Bronze (п. 6.2) |
| `logs/` | вывод прогонов — подтверждение цифр из отчёта |

## Как воспроизвести

1. Поднять стек: `bash infra/setup.sh` (если контейнеры уже были созданы — `bash infra/restart_all.sh`).
2. Всё остальное одной командой: `bash p1_run_everything.sh` (тест кодеков и сборка слоёв, schema evolution и time travel, Spark, матрица форматов и кодеков). Отдельные шаги — `p1_all.sh`, `p1_part2.sh`, `p1_spark.sh`, `p1_format_test.sh`.

Нужен только Docker. В Trino используются каталог `lakekeeper` (warehouse `demo`) и встроенный коннектор `tpch`.
