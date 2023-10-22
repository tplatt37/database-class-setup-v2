#!/bin/bash

#
# Basic RDS Multi-AZ Instance?
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

  echo "Creating CodePipeline ... ($REGION) ..."
  aws cloudformation deploy \
   --template-file pipelines/pipeline-template.yaml \
   #--parameter-overrides Name=rds-mysql-instance DatabaseTemplate=icfn-rds-mysql.yaml Buildspec=buildspec-rds-mysql.yml \
   --parameter-overrides Name=aurora-mysql-instance DatabaseTemplate=cfn-aurora-mysql.yaml Buildspec=buildspec-aurora-mysql.yml \
   --stack-name $PREFIX-pipeline-aurora-mysql-instance \
   --capabilities CAPABILITY_NAMED_IAM \
   --region $REGION

  echo "Done."
}

err() {
   echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

usage() {
  echo " Create a RDS Instance."
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