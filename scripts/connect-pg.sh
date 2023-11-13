#!/bin/bash

#
# Easy way to connect to the Aurora Postresql databases created by these templates.
#
# This will open psql interactively.
# If you "source" this command it'll set ENV VARS for easier connecting (HOST, PORT, USER, PGPASSWORD, etc.)

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

  if [[ "$DATABASE" == "multiaz-instance" ]]; then
    if [[ "$MODE" == "rw" ]]; then
      HOST_EXPORT_NAME="$PREFIX-PostgresqlEndpoint"
    else
      HOST_EXPORT_NAME="$PREFIX-PostgresqlReadEndpoint"
    fi
    PORT_EXPORT_NAME="$PREFIX-PostgresqlPort"
  fi
  
  if [[ "$DATABASE" == "multiaz-cluster" ]]; then
    if [[ "$MODE" == "rw" ]]; then
      HOST_EXPORT_NAME="$PREFIX-PostgresqlClusterEndpoint"
    else
      HOST_EXPORT_NAME="$PREFIX-PostgresqlClusterReadEndpoint"
    fi
    PORT_EXPORT_NAME="$PREFIX-PostgresqlClusterPort"
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
  # We set PGPASSWORD , which Psql knows to use.
  export PGPASSWORD=$(aws secretsmanager get-secret-value  --region $REGION --secret-id $SECRET_ARN --query "SecretString" --output text | sed 's/\\//g' | jq -r '.password')
  USER=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN  --region $REGION --query "SecretString" --output text | sed 's/\\//g' | jq -r '.username')
  echo "USER=$USER"

  if [[ "$PGPASSWORD" == "" || "$USER" == "" ]]; then
      err "Could not find database user/password from the secret, please double check region."
      exit 1
  fi

  if [[ "$(which psql)" == "" ]]; then
      err "You must install psql to use this script."
      exit 1
  fi

  psql \
    --host=$HOST \
    --port=$PORT \
    "dbname=postgres user=$USER sslmode=verify-full sslrootcert=./global-bundle.pem"

}

# Any error should got to STDERR
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

usage() {
        echo " "
        echo " Easy way to connect to the Aurora Postresql databases created by these templates."
        echo " "
        echo " --database : Which database - either multiaz-instance or multiaz-cluster"
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