#%help

from datetime import datetime
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *
import boto3

session = boto3.Session()

# Create an S3 client
s3 = session.client('s3')

sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
connection = glueContext.extract_jdbc_conf("fnc_dwh_conn")

bucket="s3-hq-std-prd-finan"
prefix="daily_rates"
prefix_temp = "daily_rates_temp"
output_path = f"s3a://{bucket}/{prefix}/"
output_path_temp = f"s3a://{bucket}/{prefix_temp}/"

# Función para verificar si un path existe en S3
def path_exists(buck, path):
    response = s3.list_objects_v2(Bucket=buck, Prefix=path)
    return 'Contents' in response

query = "SELECT * FROM stg_ebs.DAILY_RATES_VW"
df = spark.read.format("jdbc") \
    .option("user", connection['user']) \
    .option("password", connection['password']) \
    .option("driver", "com.microsoft.sqlserver.jdbc.SQLServerDriver") \
    .option("url", connection['fullUrl']) \
    .option("query", query) \
    .load()

df = df.withColumnRenamed("Base Source","BASE_SOURCE")
df = df.withColumn("HASH", sha2(concat_ws("||", *df.columns), 256))

if path_exists(bucket, prefix):
    currentDf = spark.read.parquet(output_path)


    #unir existencias
    joinedDF = currentDf.alias("A").join(
        df.alias("B"),
        (col("A.HASH") == col("B.HASH")),
        "fullouter"
    ).select(
        coalesce(col("A.FROM_CURRENCY"),col("B.FROM_CURRENCY")).alias("FROM_CURRENCY"),
        coalesce(col("A.TO_CURRENCY"),col("B.TO_CURRENCY")).alias("TO_CURRENCY"),   
        coalesce(col("A.CONVERSION_DATE"),col("B.CONVERSION_DATE")).alias("CONVERSION_DATE"),   
        coalesce(col("A.USER_CONVERSION_TYPE"),col("B.USER_CONVERSION_TYPE")).alias("USER_CONVERSION_TYPE"),   
        coalesce(col("A.SHOW_CONVERSION_RATE"),col("B.SHOW_CONVERSION_RATE")).alias("SHOW_CONVERSION_RATE"),   
        coalesce(col("A.SHOW_INVERSE_CON_RATE"),col("B.SHOW_INVERSE_CON_RATE")).alias("SHOW_INVERSE_CON_RATE"),   
        coalesce(col("A.CONVERSION_RATE"),col("B.CONVERSION_RATE")).alias("CONVERSION_RATE"),   
        coalesce(col("A.INVERSE_CONVERSION_RATE"),col("B.INVERSE_CONVERSION_RATE")).alias("INVERSE_CONVERSION_RATE"),   
        coalesce(col("A.CONVERSION_TYPE"),col("B.CONVERSION_TYPE")).alias("CONVERSION_TYPE"), 
        coalesce(col("A.LAST_UPDATE_DATE"),col("B.LAST_UPDATE_DATE")).alias("LAST_UPDATE_DATE"), 
        coalesce(col("A.LAST_UPDATED_BY"),col("B.LAST_UPDATED_BY")).alias("LAST_UPDATED_BY"), 
        coalesce(col("A.LAST_UPDATE_LOGIN"),col("B.LAST_UPDATE_LOGIN")).alias("LAST_UPDATE_LOGIN"), 
        coalesce(col("A.CREATED_BY"),col("B.CREATED_BY")).alias("CREATED_BY"), 
        coalesce(col("A.CREATION_DATE"),col("B.CREATION_DATE")).alias("CREATION_DATE"), 
        coalesce(col("A.BASE_SOURCE"),col("B.BASE_SOURCE")).alias("BASE_SOURCE"), 
        coalesce(col("A.HASH"),col("B.HASH")).alias("HASH"), 
    )

    #actualizar data de daily rates
    joinedDF.write.mode("overwrite").parquet(output_path_temp)
    currentDf = spark.read.parquet(output_path_temp)
    currentDf.write.mode("overwrite").partitionBy("FROM_CURRENCY").parquet(output_path)


    # borrando bucket temporal
    response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix_temp)

    if 'Contents' in response:
        for item in response['Contents']:
            s3.delete_object(Bucket=bucket, Key=item['Key'])
else:
    # Si el path no existe, escribir el DataFrame en Parquet
    df.write.mode("overwrite").partitionBy("FROM_CURRENCY").parquet(output_path)

job.commit()