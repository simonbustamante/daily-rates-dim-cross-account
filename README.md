# AWS Data Configuration and Processing Guide

![image](https://github.com/simonbustamante/daily-rates-dim-cross-account/assets/31484503/3f856bd6-7c01-4e24-a9f1-b9a8bb79948e)

This README provides a detailed guide on setting up AWS configurations for data handling and processing. The configurations include AWS IAM roles, Glue connections, S3 bucket creation, and a step function.

## Important Notes

- Manually add the following inline policy to `role_from_step_function`:
  ```json
  {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::ACCOUNTID1:role/role_to_create"
  }
  ```

- The `role_to_create` includes a trust relationship in the script execution (Line 80) as follows:
  ```json
  {
      "Effect": "Allow",
      "Principal": {
          "AWS": "arn:aws:iam::ACCOUNTID2:role/role_from_step_function"
      },
      "Action": "sts:AssumeRole"
  }
  ```

- Ensure `role_from_step_function` and `role_to_create` include all necessary permissions for executing or provisioning services configured with this script.

## Configuration Details

- Profiles, regions, connection names, IP addresses, ports, database names, and other local variables are defined.
- AWS provider configurations for different profiles are set.
- AWS Glue connection for database connectivity is defined.
- IAM roles with necessary policies and trust relationships are created.
- S3 buckets for storing code and data are configured.
- Glue jobs for data processing are defined.
- AWS Step Functions for orchestrating tasks are set up.

## AWS Glue Script

The provided Python script (`#%help` section) is for an AWS Glue job. It handles:

- Data extraction from a JDBC source.
- Data transformation and checking for existing data paths.
- Data loading to S3 in Parquet format.

## Step Function Configuration

The JSON configuration (`{...}`) outlines the state machine for handling data processing tasks, including starting Glue jobs and crawlers, and making choices based on crawler states.

---

**Note:** Replace `ACCOUNTID1`, `ACCOUNTID2`, and other placeholders with actual account IDs and values as per your AWS setup.
