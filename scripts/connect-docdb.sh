#!/bin/bash
# Connect to the DocumentDB cluster using Mongo Shell (mongosh)

PREFIX=database

HOST=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-DocDBEndpoint'].Value" --output text)
echo "HOST=$HOST"

PORT=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-DocDBPort'].Value" --output text)
echo "HOST=$PORT"

SECRET_ARN=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-DBAdminSecretArn'].Value" --output text)
echo "SECRET_ARN=$SECRET_ARN"

# Use a combination of client side query and jq to parse out the username and password from the secret.
# We set PGPASSWORD , which Psql knows to use.
PASSWORD=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query "SecretString" --output text | sed 's/\\//g' | jq -r '.password')
USER=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query "SecretString" --output text | sed 's/\\//g' | jq -r '.username')
echo "USER=$USER"

echo ""
echo "Some examples to get you started..."
echo " "
echo "show dbs"
echo "use <db name>"
echo "show collections"
echo "db.<collection name>.find()"
echo "exit"
echo ""

mongosh --tls --host $HOST:$PORT --tlsCAFile scripts/rds-combined-ca-bundle.pem --username $USER --password $PASSWORD