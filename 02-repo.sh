#!/bin/bash

#
# Creates a CodeCommit Repo to store database schema files, data, scripts, etc.
#

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
      --bucket)
        shift
        if [[ "$1" != "" ]]; then
          BUCKET="$1"
        else
          err "Missing value for --bucket."
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

  # Zip up the schemas folder, we'll need to put this into CodeCommit so we can access it via the Pipeline.
  rm database-schemas.zip 2>/dev/null

  # NOTE: When we zip, we ignore .git folder (there shouldn't be one!), but include other hidden files and folders! 
  cd schemas && zip -r --exclude=*.git/* ../database-schemas.zip ./* .[^.]* && cd ..

  ls -lha database-schemas.zip

  aws s3 cp database-schemas.zip s3://$BUCKET

  # Cleanup
  rm database-schemas.zip

  echo "Setting up CodeCommit repo..."
  aws cloudformation deploy --template-file core/repo.yaml --stack-name $PREFIX-repo --parameter-overrides CodeBucketName=$BUCKET --region $REGION

}

err() {
   echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

usage() {
  echo " Create a CodeCommit repo used for staging schema files, data , scripts, etc."
  echo " "
  echo " --bucket : Private S3 bucket to stage temporary files"
  echo " --region : Region (Optional)"
  echo " --help : This help."
  echo " "
  exit 1
}

validate_arguments() {

  if [[ -z "$BUCKET" ]]; then
    err "Missing required argumemts."
    usage
    exit 1
  fi

}

main "$@"