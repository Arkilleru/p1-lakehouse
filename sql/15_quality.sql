-- Отчёт качества Bronze: сколько строк нарушает правила очистки Silver
SELECT 'lineitem' AS tbl,
       count(*)                                         AS total_rows,
       count_if(orderkey IS NULL OR linenumber IS NULL) AS null_keys,
       count_if(shipdate IS NULL)                       AS null_shipdate,
       count_if(extendedprice <= 0)                     AS bad_price,
       count_if(discount < 0 OR discount > 1)           AS bad_discount,
       count(*) - count(DISTINCT (orderkey, linenumber)) AS duplicate_rows
FROM lakekeeper.bronze.lineitem;

SELECT 'orders' AS tbl,
       count(*)                                       AS total_rows,
       count_if(orderkey IS NULL OR custkey IS NULL)  AS null_keys,
       count_if(orderdate IS NULL)                    AS null_orderdate,
       count(*) - count(DISTINCT orderkey)            AS duplicate_rows
FROM lakekeeper.bronze.orders;

-- Значения сегмента до нормализации (регистр/пробелы)
SELECT mktsegment AS raw_value, length(mktsegment) AS len, count(*) AS cnt
FROM lakekeeper.bronze.customer GROUP BY 1, 2 ORDER BY 1;
