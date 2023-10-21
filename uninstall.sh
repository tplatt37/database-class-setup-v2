#!/bin/bash

#
# Uninstall database demos.
#

main() {

  FORCE=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --region)
        shift
        if [[ "$1" != "" ]]; then
          REGION_ARG="$1"
        else
          err "Missing value for --region."
          usage
        fi
        ;;
      --help)
        shift
        usage
        exit 1
        ;;
      --yes)
        shift
        if [[ "$1" != "" ]]; then
          FORCE=true
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
  echo " Uninstall database examples for class demonstrations."
  echo " "
  echo " --yes : include --yes to skip any confirmation prompts."
  echo " --region : Region (Optional)"
  echo " --help : This help."
  echo " "
  exit 1
}

validate_arguments() {
  
  return

}

main "$@"