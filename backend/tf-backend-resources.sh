#!/bin/bash

#
# https://github.com/digitalden3/TF-Backend-AWS-Bash-Script
#

# Function to check the exit status and display an error message if it failed
check_exit_status() {
  if [ $? -ne 0 ]; then
    echo "Error: $1"
    exit 1
  fi
}

# Function to display help
show_help() {
  echo "Usage: AWS_REGION must be set before running the script."
  echo "Example:"
  echo "  AWS_REGION=eu-central-1 ENV=np ./create-backend.sh"
  exit 1
}

# Check if AWS_REGION environment variable is set
if [ -z "$AWS_REGION" ]; then
  echo "Error: AWS_REGION environment variable is not set."
  show_help
fi

# Check if AWS_REGION environment variable is set
if [[ "$ENV" != "p" && "$ENV" != "np" ]]; then
  echo "Error: ENV environment variable is not set. The possible options are p for production and np for lab and non production"
  show_help
fi

# Check if AWS_REGION environment variable is set
if [ -z "$PROJECT" ]; then
  echo "Error: PROJECT environment variable is not set."
  show_help
fi

USER_ARN=$(aws sts get-caller-identity | jq -r .Arn)
check_exit_status "Failed to get AWS user identity."

# S3 Bucket Name
S3_BUCKET_NAME="tf-bucket-$ENV-$PROJECT"

# Create S3 Bucket
aws s3 mb "s3://$S3_BUCKET_NAME" --region "$AWS_REGION"
check_exit_status "Failed to create S3 bucket."

# Enable Versioning for S3 Bucket
aws s3api put-bucket-versioning --bucket "$S3_BUCKET_NAME" --versioning-configuration Status=Enabled --region "$AWS_REGION"
check_exit_status "Failed to enable versioning on the S3 bucket."

# Create DynamoDB Table
aws dynamodb create-table \
  --table-name "tf-lock-table" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
  --region "$AWS_REGION"
check_exit_status "Failed to create DynamoDB table."

# Echo a confirmation message
echo "Resources created in AWS region: $AWS_REGION"
echo "S3 Bucket created successfully: $S3_BUCKET_NAME (Versioning enabled)"
echo "DynamoDB Table created successfully: tf-lock-table"
echo "Script execution completed successfully."
