
#### #### #### #### #### #### #### #### #### #### #### #### 
#### #### #### #### #### #### #### #### #### #### #### #### 
#### #### #### #### #### #### #### #### #### #### #### #### 
#### aws-data-hq-prd-analytics #account 2 #### #### ####
#### #### #### #### #### #### #### #### #### #### #### #### 
#### #### #### #### #### #### #### #### #### #### #### #### 
#### #### #### #### #### #### #### #### #### #### #### #### 

# IMPORTANTE: ES NECESARIO AGREGAR MANUALMENTE A "role_from_step_function" LO SIGUIENTE  EN UN INLINE POLICY:

        # {
        #     "Effect": "Allow",
        #     "Action": "sts:AssumeRole",
        #     "Resource": "arn:aws:iam::ACCOUNTID1:role/role_to_create"
        # }

# EL "role_to_create" TIENE UN TRUST RELATIONSHIP INCLUIDO EN LA EJECUCIÓN DE SCRIPT (LINEA 80) DE LA SIGUIENTE FORMA:

        # {
        #     "Effect": "Allow",
        #     "Principal": {
        #         "AWS": "arn:aws:iam::ACCOUNTID2:role/role_from_step_function"
        #     },
        #     "Action": "sts:AssumeRole"
        # }

# role_from_step_function Y role_to_create DEBEN DE INCLUIR TODOS LOS PERMISOS NECESARIOS PARA EJECUTAR O APROVISIONAR TODOS LOS SERVICIOS CONFIGURADOS CON ESTE SCRIPT


locals {
  profile = "<account2>_AWSAdministratorAccess"
  profile2 = "<account1>_AWSAdministratorAccess"
  region = "us-east-1"
  connection_name = "fnc_dwh_conn"
  fnc_db_ip = "10.18.26.11"
  fnc_db_port = "1433"
  fnc_db_name = "FNC_DWH"
  fnc_db_user = "awsuser"
  fnc_db_password = "4w5us3r"
  fnc_db_vpc_av_zone = "us-east-1b"
  fnc_db_vpc_sg_id = "sg-0662c28ef8b0447dc"
  fnc_db_vpc_subnet_id = "subnet-05d76c28490be84dc"
  role_to_create = "svc_hq_zeus_fnc_dwh_conn"
  role_from_step_function = "arn:aws:iam::525196274797:role/svc-role-data-mic-development-integrations"
  this_account = "052081006081"
  bucket_to_create = "s3-hq-zeus-extract-from-fnc-daily-rates-prd"
  file_cp_to_bucket = "glu_hq_finan_zeus_daily_rates_extraction_to_data_lake_hq_prd_001"
  db_target = "hq-std-prd-finan-link"
  crawler_name = "crwl-hq-std-prd-finan-daily-rate-prd"
  s3_to_crawl = "s3://s3-hq-std-prd-finan/daily_rates/"
  step_function_name = "stp-fnc-hq-finan-zeus-rbs-daily-rates-and-exchange-prd"
  step_function_path = "step_function_prd.json"
}

provider "aws" {
  alias = "aws-data-hq-prd-analytics"
  profile = local.profile
  region  = local.region
}

## CONEXION PARA GLUE
resource "aws_glue_connection" "fnc_dwh_conn" {
  provider = aws.aws-data-hq-prd-analytics
  name = local.connection_name

  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:sqlserver://${local.fnc_db_ip}:${local.fnc_db_port};databaseName=${local.fnc_db_name}"
    USERNAME            = local.fnc_db_user
    PASSWORD            = local.fnc_db_password
  }

  physical_connection_requirements {
    availability_zone = local.fnc_db_vpc_av_zone
    security_group_id_list = [local.fnc_db_vpc_sg_id]
    subnet_id              = local.fnc_db_vpc_subnet_id
  }
}

## CREAR UN ROLE PARA LA CONEXION

## Rol para la conexión de Glue
resource "aws_iam_role" "svc_hq_zeus_fnc_dwh_conn" {
  provider = aws.aws-data-hq-prd-analytics
  name = local.role_to_create

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
                    {
                    Effect = "Allow",
                    Principal = {
                        Service = "glue.amazonaws.com"
                    },
                    Action = "sts:AssumeRole"
                    },
                    {
                        "Sid": "",
                        "Effect": "Allow",
                        "Principal": {
                            "Service": "lakeformation.amazonaws.com"
                        },
                        "Action": "sts:AssumeRole"
                    },
                    {
                        "Effect": "Allow",
                        "Principal": {
                            "AWS": "${local.role_from_step_function}"
                        },
                        "Action": "sts:AssumeRole"
                    },
                    {
                        "Sid": "",
                        "Effect": "Allow",
                        "Principal": {
                            "Service": [
                                "events.amazonaws.com",
                                "states.amazonaws.com",
                                "scheduler.amazonaws.com"
                            ]
                        },
                        "Action": "sts:AssumeRole"
                    },
                    {
                        "Effect": "Allow",
                        "Principal": {
                            "Service": "transfer.amazonaws.com"
                        },
                        "Action": "sts:AssumeRole"
                    }
    ]
  })
}

## Adjuntar la política AmazonVPCFullAccess al rol
resource "aws_iam_role_policy_attachment" "vpc_full_access" {
  provider = aws.aws-data-hq-prd-analytics
  role       = aws_iam_role.svc_hq_zeus_fnc_dwh_conn.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}

## Adjuntar la política AWSGlueServiceRole al rol
resource "aws_iam_role_policy_attachment" "glue_service_role" {
  provider = aws.aws-data-hq-prd-analytics
  role       = aws_iam_role.svc_hq_zeus_fnc_dwh_conn.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

## Adjuntar la política CloudWatchFullAccess al rol
resource "aws_iam_role_policy_attachment" "cloudwatch_full_access" {
  provider = aws.aws-data-hq-prd-analytics
  role       = aws_iam_role.svc_hq_zeus_fnc_dwh_conn.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

## Adjuntar la política s3FullAccess al rol
resource "aws_iam_role_policy_attachment" "s3_full_access" {
  provider = aws.aws-data-hq-prd-analytics
  role       = aws_iam_role.svc_hq_zeus_fnc_dwh_conn.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

## Política Inline para el rol
resource "aws_iam_role_policy" "svc_hq_zeus_fnc_dwh_conn_inline_policy" {
  provider = aws.aws-data-hq-prd-analytics
  name   = "svc_hq_zeus_fnc_dwh_conn_inline_policy"
  role   = aws_iam_role.svc_hq_zeus_fnc_dwh_conn.id
  policy = jsonencode(
    {
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Action": "iam:PassRole",
        "Resource": "arn:aws:iam::${local.this_account}:role/${local.role_to_create}"
        }
    ]
    }
  )
}

## INSTALAR SCRIPT

# crear un bucket para zeus en aws-data-hq-prd-analytics NO forma parte de datalake
resource "aws_s3_bucket" "bucket-prd-daily-rates" {
  provider = aws.aws-data-hq-prd-analytics
  bucket = local.bucket_to_create  # Reemplaza con el nombre único de tu bucket

  tags = {
    Nombre = local.bucket_to_create
    Propósito = "Almacenar codigo fuente de extracción de datos de FNC Daily Rates"
  }
}

# copiar el archivo al bucket
resource "null_resource" "copy_source_code" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "aws s3 cp ${local.file_cp_to_bucket}.py s3://${aws_s3_bucket.bucket-prd-daily-rates.bucket} --profile ${local.profile}"  
  }
}



## Definición del trabajo de Glue
resource "aws_glue_job" "my-job-daily-rates-glue" {
  provider = aws.aws-data-hq-prd-analytics
  name     = "${local.file_cp_to_bucket}"
  role_arn = aws_iam_role.svc_hq_zeus_fnc_dwh_conn.arn
  glue_version = "4.0"

  command {
    script_location = "s3://${local.bucket_to_create}/${local.file_cp_to_bucket}.py"  # Reemplaza con la ubicación real de tu script en S3
    python_version  = "3"                           # Asegúrate de especificar la versión correcta de Python
  }

  connections = [aws_glue_connection.fnc_dwh_conn.name]

  default_arguments = {
    "--TempDir"             = "s3://${local.bucket_to_create}/temp-dir"
    "--job-bookmark-option" = "job-bookmark-enable"
    #"--extra-py-files"      = "s3://${local.bucket_to_create}/extra-files.zip"  # Si necesitas archivos adicionales
  }

  #max_capacity = 2.0  # Configura según las necesidades de tu trabajo
  max_retries  = 0    # Número de reintentos en caso de fallo
  timeout      = 60   # Tiempo máximo de ejecución en minutos
  number_of_workers = 5
  worker_type = "G.1X"
}



#### #### #### #### #### #### #### #### #### #### #### #### 
#### #### #### #### #### #### #### #### #### #### #### #### 
#### #### #### #### #### #### #### #### #### #### #### #### 
#### aws-bi-LakeH-hq-prd #<account1> #### #### #### #######
#### #### #### #### #### #### #### #### #### #### #### #### 
#### #### #### #### #### #### #### #### #### #### #### #### 
#### #### #### #### #### #### #### #### #### #### #### #### 

## CONFIGURAR CRAWLERS
# la step function se encuentra en otra cuenta


provider "aws" {
  alias = "aws-bi-LakeH-hq-prd"
  profile = local.profile2
  region  = local.region
}

resource "aws_glue_crawler" "daily_rates_crawler" {
  provider = aws.aws-bi-LakeH-hq-prd
  name          = local.crawler_name
  role          = local.role_from_step_function  # Asegúrate de reemplazar esto con el ARN de tu rol de IAM para Glue

  database_name = "${local.db_target}"  # Reemplaza con el nombre de tu base de datos de Glue

  s3_target {
    path = local.s3_to_crawl
  }


}


## CONFIGURAR STEP FUNCTION

resource "aws_sfn_state_machine" "daily_rate_state_machine" {
  provider = aws.aws-bi-LakeH-hq-prd
  name     = local.step_function_name
  role_arn = local.role_from_step_function

  # Lee la definición de la máquina de estados del archivo JSON
  definition = file("${local.step_function_path}")
}




