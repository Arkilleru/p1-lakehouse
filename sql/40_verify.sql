WITH direct AS (
  SELECT l.orderkey, round(sum(l.extendedprice * (1 - l.discount)), 2) AS revenue, o.orderdate, o.shippriority
  FROM tpch.sf1.customer AS c
  JOIN tpch.sf1.orders   AS o ON c.custkey = o.custkey
  JOIN tpch.sf1.lineitem AS l ON l.orderkey = o.orderkey
  WHERE c.mktsegment = 'BUILDING' AND o.orderdate < DATE '1995-03-15' AND l.shipdate > DATE '1995-03-15'
  GROUP BY l.orderkey, o.orderdate, o.shippriority
  ORDER BY 2 DESC LIMIT 10
),
gold AS (
  SELECT orderkey, round(revenue, 2) AS revenue, orderdate, shippriority FROM lakekeeper.gold.shipping_priority
)
SELECT (SELECT count(*) FROM (SELECT * FROM direct EXCEPT SELECT * FROM gold)) AS direct_minus_gold,
       (SELECT count(*) FROM (SELECT * FROM gold EXCEPT SELECT * FROM direct)) AS gold_minus_direct,
       (SELECT count(*) FROM gold) AS gold_rows;
