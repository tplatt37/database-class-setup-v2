#!/bin/bash

# Creates a VPC for use with the databases.
# This creates 3 AZs - so you can use a Multi-AZ Cluster

main() {

  # This is an arbitrary naming identifier that is used to ensure all stacks can be clearly identified as being part of this project.
  PREFIX="database"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        shift
        usage
        exit 1
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

  # Check for pre-requisites
  ./00-check-prereqs.sh
  if [[ $? -ne 0 ]]; then
      err "Missing prerequisites... exiting..."
      exit 1
  fi

  PREFIX="database"

  echo "Setting up VPC (in $REGION)..."
  
  # NOTE: We're using 3 AZs, but this template also supports 2 (see parameter).
  aws cloudformation deploy --template-file core/vpc-multi-az.yaml --parameter-overrides UseThirdAZ=True --stack-name $PREFIX-vpc --region $REGION

}

err() {
   echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

usage() {
  echo " Create a VPC and subnets using multiple AZs suitable for database demos."
  echo " "
  echo " --region : Region (Optional)"
  echo " --help : This help."
  echo " "
  exit 1
}

validate_arguments() {

  return
}

main "$@"