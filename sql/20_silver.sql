SET SESSION lakekeeper.compression_codec = 'ZSTD';

DROP TABLE IF EXISTS lakekeeper.silver.order_lines;
CREATE TABLE lakekeeper.silver.order_lines WITH (format = 'PARQUET') AS
WITH customers AS (
  -- НОРМАЛИЗАЦИЯ: убираем пробелы и приводим сегмент к верхнему регистру
  SELECT custkey, upper(trim(mktsegment)) AS mktsegment
  FROM lakekeeper.bronze.customer
  WHERE custkey IS NOT NULL
),
orders AS (
  -- ОЧИСТКА: заказы без ключей и без даты не нужны
  SELECT orderkey, custkey, orderdate, shippriority
  FROM lakekeeper.bronze.orders
  WHERE orderkey IS NOT NULL AND custkey IS NOT NULL AND orderdate IS NOT NULL
),
lines AS (
  -- ОЧИСТКА: убираем позиции без ключей/даты, с неположительной ценой и скидкой вне [0, 1];
  -- дубли по ключу позиции (orderkey, linenumber) оставляем в одном экземпляре
  SELECT orderkey, linenumber, extendedprice, discount, shipdate
  FROM (
    SELECT orderkey, linenumber, extendedprice, discount, shipdate,
           row_number() OVER (PARTITION BY orderkey, linenumber ORDER BY shipdate) AS rn
    FROM lakekeeper.bronze.lineitem
    WHERE orderkey IS NOT NULL AND linenumber IS NOT NULL AND shipdate IS NOT NULL
      AND extendedprice > 0 AND discount BETWEEN 0 AND 1
  )
  WHERE rn = 1
)
SELECT l.orderkey,
       l.linenumber,
       o.orderdate,
       o.shippriority,
       l.extendedprice,
       l.discount,
       l.shipdate,
       -- ОБОГАЩЕНИЕ: выручка позиции и срок от заказа до отгрузки в днях
       l.extendedprice * (1 - l.discount)             AS line_revenue,
       date_diff('day', o.orderdate, l.shipdate)      AS days_to_ship
FROM customers AS c
JOIN orders    AS o ON c.custkey = o.custkey
JOIN lines     AS l ON l.orderkey = o.orderkey
WHERE c.mktsegment = 'BUILDING'
  AND o.orderdate < DATE '1995-03-15'
  AND l.shipdate  > DATE '1995-03-15';
