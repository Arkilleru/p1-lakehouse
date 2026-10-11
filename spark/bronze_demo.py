import time
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("p1-bronze-demo").getOrCreate()
spark.sparkContext.setLogLevel("WARN")

print(">>> Таблицы схемы bronze (видит Spark через Lakekeeper)")
spark.sql("SHOW TABLES IN lakekeeper.bronze").show(truncate=False)

for t in ["customer", "orders", "lineitem"]:
    print(f">>> bronze.{t}: схема, число строк, файлы данных")
    spark.sql(f"DESCRIBE lakekeeper.bronze.{t}").show(truncate=False)
    spark.sql(f"SELECT count(*) AS rows_cnt FROM lakekeeper.bronze.{t}").show()
    spark.sql(f"SELECT count(*) AS files, round(sum(file_size_in_bytes)/1048576.0, 3) AS size_mb FROM lakekeeper.bronze.{t}.files").show()

print(">>> Пример строк Bronze lineitem")
spark.sql("SELECT * FROM lakekeeper.bronze.lineitem LIMIT 5").show(truncate=False)

q3 = """
SELECT l.orderkey, sum(l.extendedprice * (1 - l.discount)) AS revenue, o.orderdate, o.shippriority
FROM lakekeeper.bronze.customer AS c
JOIN lakekeeper.bronze.orders   AS o ON c.custkey = o.custkey
JOIN lakekeeper.bronze.lineitem AS l ON l.orderkey = o.orderkey
WHERE c.mktsegment = 'BUILDING' AND o.orderdate < DATE '1995-03-15' AND l.shipdate > DATE '1995-03-15'
GROUP BY l.orderkey, o.orderdate, o.shippriority
ORDER BY revenue DESC
LIMIT 10
"""
for i in (1, 2, 3):
    print(f">>> Q3 на Bronze в Spark, прогон {i}")
    t0 = time.time()
    spark.sql(q3).show(truncate=False)
    print(f"RESULT SPARK_Q3_RUN{i}_SEC={time.time()-t0:.3f}")

spark.stop()
