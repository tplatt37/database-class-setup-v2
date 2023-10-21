#!/bin/bash

#
# Install database demos.
#

main() {

  # This is an arbitrary naming identifier that is used to ensure all stacks can be clearly identified as being part of this project.
  PREFIX="database"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --demos)
        shift
        if [[ "$1" != "" ]]; then
          DEMOS="$1"
        else
          err "Missing value for --demos."
          usage
        fi
        ;;
      --help)
        shift
        usage
        exit 1
        ;;
      --bucket)
        shift
        if [[ "$1" != "" ]]; then
          BUCKET="$1"
        else
          err "Missing value for --bucket."
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

  # Check for pre-requisites
  ./00-check-prereqs.sh
  if [[ $? -ne 0 ]]; then
      err "Missing prerequisites... exiting..."
      exit 1
  fi

  # VPC ?
  # There should be an existing VPC - created either by this project, or via the Super-VPC project.
  # This VPC has database subnet groups, and other things that will be needed later.
  echo "VPC - Checking to see if $PREFIX-vpc stack exists..."
  aws cloudformation describe-stacks --stack-name $PREFIX-vpc --region $REGION 1>/dev/null
  if [[ $? -ne 0 ]]; then
    err "Stack$PREFIX-vpc doesn't exist ($REGION) - Please run ./01-vpc-3az.sh first.  Exiting..."
    exit 1
  fi

  # Install common components - the schema repo and generate secrets


  # Install indidividual pipelines as requested.



}

err() {
   echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

usage() {
  echo " Install database examples for class demonstrations."
  echo " "
  echo " --demos : A comma delimited list of the demos to install (See README.md) for values."
  echo " --bucket : An existing private s3 bucket to be used to store bootstrap scripts and files (temporarily)."
  echo " --region : Region (Optional)"
  echo " --help : This help."
  echo " "
  exit 1
}

validate_arguments() {
  
  if [[ -z "$DEMOS" || -z "$BUCKET" ]]; then
    err "Missing required argumemts."
    usage
    exit 1
  fi

  # TODO: Validate that DEMOS requested are valid

}

main "$@"