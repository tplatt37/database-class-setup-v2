#!/bin/bash

#
# Install database demos.
#

main() {

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

  # Do work here

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
  
  if [[ -z "$demos" || -z "$bucket" ]]; then
    err "Missing required argumemts."
    usage
    exit 1
  fi

}

main "$@"