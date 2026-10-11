SET SESSION lakekeeper.compression_codec = 'ZSTD';

DROP TABLE IF EXISTS lakekeeper.gold.shipping_priority;
CREATE TABLE lakekeeper.gold.shipping_priority WITH (format = 'PARQUET') AS
SELECT orderkey,
       sum(line_revenue) AS revenue,
       orderdate,
       shippriority
FROM lakekeeper.silver.order_lines
GROUP BY orderkey, orderdate, shippriority
ORDER BY revenue DESC
LIMIT 10;

SELECT * FROM lakekeeper.gold.shipping_priority ORDER BY revenue DESC;
