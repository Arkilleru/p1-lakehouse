#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
check_stack
IMAGE="apache/spark:3.5.1"
docker run --rm \
  -v "$(pwd)/spark/bronze_demo.py:/opt/spark/work-dir/bronze_demo.py" \
  --entrypoint /bin/bash "$IMAGE" -c '
    mkdir -p /tmp/ivy2/cache /tmp/ivy2/jars &&
    /opt/spark/bin/spark-submit \
      --conf spark.jars.ivy=/tmp/ivy2 \
      --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.2,org.apache.iceberg:iceberg-aws-bundle:1.5.2 \
      --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
      --conf spark.sql.catalog.lakekeeper=org.apache.iceberg.spark.SparkCatalog \
      --conf spark.sql.catalog.lakekeeper.type=rest \
      --conf spark.sql.catalog.lakekeeper.uri=http://host.docker.internal:8181/catalog \
      --conf spark.sql.catalog.lakekeeper.warehouse=demo \
      --conf spark.sql.catalog.lakekeeper.io-impl=org.apache.iceberg.aws.s3.S3FileIO \
      --conf spark.sql.catalog.lakekeeper.s3.endpoint=http://host.docker.internal:9000 \
      --conf spark.sql.catalog.lakekeeper.s3.path-style-access=true \
      --conf spark.sql.catalog.lakekeeper.s3.access-key-id=minioadmin \
      --conf spark.sql.catalog.lakekeeper.s3.secret-access-key=minioadmin \
      /opt/spark/work-dir/bronze_demo.py 2>&1 | grep -v " INFO "
  '
echo "ГОТОВО"
