#!/bin/bash

# Connect to Redshift - using psql!
# See https://docs.aws.amazon.com/redshift/latest/mgmt/connecting-from-psql.html
#
#
# or \l
#
# \q  - to quit
#

PREFIX=database

HOST=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-RedshiftEndpoint'].Value" --output text)
echo "HOST=$HOST"

PORT=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-RedshiftPort'].Value" --output text)
echo "PORT=$PORT"

SECRET_ARN=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-DBAdminSecretArn'].Value" --output text)
echo "SECRET_ARN=$SECRET_ARN"

# Use a combination of client side query and jq to parse out the username and password from the secret.
# We set PGPASSWORD , which Psql knows to use.
export PGPASSWORD=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query "SecretString" --output text | sed 's/\\//g' | jq -r '.password')
USER=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query "SecretString" --output text | sed 's/\\//g' | jq -r '.username')
echo "USER=$USER"

psql --host=$HOST --port=$PORT "dbname=database-demo user=$USER sslmode=verify-full sslrootcert=scripts/amazon-trust-ca-bundle.crt"
