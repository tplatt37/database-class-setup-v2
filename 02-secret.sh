#!/bin/bash

PREFIX="database"

REGION=${AWS_DEFAULT_REGION:-$(aws configure get default.region)}
echo "Creating in $REGION..."

echo "Setting up Secret to store the dbadmin password ..."
aws cloudformation deploy --template-file secrets.yaml --stack-name $PREFIX-secrets
