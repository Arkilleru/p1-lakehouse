SET SESSION lakekeeper.compression_codec = '__CODEC__';

DROP TABLE IF EXISTS lakekeeper.bronze.customer;
CREATE TABLE lakekeeper.bronze.customer WITH (format = 'PARQUET') AS
SELECT custkey, mktsegment FROM tpch.sf1.customer;

DROP TABLE IF EXISTS lakekeeper.bronze.orders;
CREATE TABLE lakekeeper.bronze.orders WITH (format = 'PARQUET') AS
SELECT orderkey, custkey, orderdate, shippriority FROM tpch.sf1.orders;

DROP TABLE IF EXISTS lakekeeper.bronze.lineitem;
CREATE TABLE lakekeeper.bronze.lineitem WITH (format = 'PARQUET') AS
SELECT orderkey, linenumber, extendedprice, discount, shipdate FROM tpch.sf1.lineitem;
