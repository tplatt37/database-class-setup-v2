#!/bin/bash

#
# Easy way to connect to the MySQL MultiAZ Instance or MultiAZ Cluster database created by these templates.
#

main() {

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --database)
        shift
        if [[ "$1" != "" ]]; then
          DATABASE="$1"
        else
          err "Missing value for --database."
          usage
        fi
        ;;
      --help)
        shift
        usage
        exit 1
        ;;
      --mode)
        shift
        if [[ "$1" != "" ]]; then
          MODE="$1"
        else
          err "Missing value for --mode."
          usage
        fi
        ;;
      --region)
        shift
        if [[ "$1" != "" ]]; then
          REGION_ARG="$1"
        else
          err "Missing value for --region."
          usage
        fi
        ;;
      *)
        echo "Unknown argument: $1"
        usage
        ;;
    esac
    shift
  done

  validate_arguments

  # Which region? Display to user so they can double-check.
  # Our first preference is the --region argument, then AWS_DEFAULT_REGION, lastly just use that set in the profile.
  REGION=${REGION_ARG:-${AWS_DEFAULT_REGION:-$(aws configure get default.region)}}
  echo "REGION=$REGION"

  PREFIX="database"

  # RDS MySQL Instance
  if [[ "$DATABASE" == "multiaz-rds" ]]; then
    if [[ "$MODE" == "rw" ]]; then
      HOST_EXPORT_NAME="$PREFIX-MySqlInstanceEndpoint"
    else
      err "There is no ro (Read Only) instance for the MySQL MultiAZ Instance - use rw instead."
      exit 1
    fi
    PORT_EXPORT_NAME="$PREFIX-MySqlInstancePort"
  fi
  
  # Aurora Mysql Instance
  if [[ "$DATABASE" == "multiaz-aurora" ]]; then
    if [[ "$MODE" == "rw" ]]; then
      HOST_EXPORT_NAME="$PREFIX-MySqlEndpoint"
    else
      HOST_EXPORT_NAME="$PREFIX-MySqlReadEndpoint"
    fi
    PORT_EXPORT_NAME="$PREFIX-MySqlPort"
  fi
   
  HOST=$(aws cloudformation list-exports --query "Exports[?Name=='$HOST_EXPORT_NAME'].Value" --output text --region $REGION)
  echo "HOST=$HOST"

  PORT=$(aws cloudformation list-exports --query "Exports[?Name=='$PORT_EXPORT_NAME'].Value" --output text --region $REGION)
  echo "PORT=$PORT"

  SECRET_ARN=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-DBAdminSecretArn'].Value" --output text --region $REGION)
  echo "SECRET_ARN=$SECRET_ARN"

  if [[ "$HOST" == "" || "$PORT" == "" || "$SECRET_ARN" == "" ]]; then
      err "Could not find database connection information, please double check region."
      exit 1
  fi

  # Use a combination of client side query and jq to parse out the username and password from the secret.
  PASSWORD=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query "SecretString" --output text  --region $REGION | sed 's/\\//g' | jq -r '.password')
  USER=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --region $REGION --query "SecretString" --output text | sed 's/\\//g' | jq -r '.username')
  echo "USER=$USER"

  if [[ "$PASSWORD" == "" || "$USER" == "" ]]; then
      err "Could not find database user/password from the secret, please double check region."
      exit 1
  fi

  if [[ "$(which mysql)" == "" ]]; then
      err "You must install mysql (client) to use this script."
      exit 1
  fi

  mysql \
    -h $HOST \
    -P $PORT \
    -u $USER \
    -p$PASSWORD \
    --ssl-ca=global-bundle.pem \
    --ssl-verify-server-cert

  # NOTE: If using Mysql 8.0 client, the format will be:
  # mysql -h $HOST -P 3306 -u $USER -p$PASSWORD --ssl-ca=global-bundle.pem --ssl-mode=VERIFY_IDENTITY

}

# Any error should got to STDERR
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

usage() {
        echo " "
        echo " Easy way to connect to the MySQL MultiAZ Instance or MultiAZ Cluster databases created by these templates."
        echo " "
        echo " --database : Which database - either multiaz-rds or multiaz-aurora"
        echo " --mode : Which mode - ro (Read Only) or rw (Read/Write)"
        echo " --region : Region (Optional)"
        echo " --help : This help"
        echo " "
        exit 1
}

validate_arguments() {

  if [[ -z "$DATABASE" || -z "$MODE" ]]; then
    err "Missing required argumemts."
    usage
    exit 1
  fi

  if [[ "$MODE" != "ro" && "$MODE" != "rw" ]]; then
    err "Mode must be ro or rw."
    usage
    exit 1
  fi

  if [[ "$DATABASE" != "multiaz-instance" && "$DATABASE" != "multiaz-cluster" ]]; then
    err "Database must be either multiaz-instance or multiaz-cluster."
    usage
    exit 1
  fi

}

main "$@"