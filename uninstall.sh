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
        FORCE=true
        ;;
      *)
        echo "Unknown argument: $1"
        usage
        ;;
    esac
    shift
  done

  validate_arguments

  PREFIX="database"

  # Which region? Display to user so they can double-check.
  # Our first preference is the --region argument, then AWS_DEFAULT_REGION, lastly just use that set in the profile.
  REGION=${REGION_ARG:-${AWS_DEFAULT_REGION:-$(aws configure get default.region)}}

  echo "FORCE=$FORCE"

  # NOTE: if you invoke with --yes it will skip these "Are you sure?" prompts
  if [[ "$FORCE" != true ]]; then
      read -p "This will delete all the $PREFIX-* stacks in $REGION! Are you sure? (Yy) " -n 1 -r
      echo    # (optional) move to a new line
      if [[ ! $REPLY =~ ^[Yy]$ ]]
      then
          exit 1
      fi
      
      read -p "Are you sure you are sure???? (Yy) " -n 1 -r
      echo    # (optional) move to a new line
      if [[ ! $REPLY =~ ^[Yy]$ ]]
      then
          exit 1
      fi
  fi

  echo "Deleting all database stacks ($REGION). Here we go..."

  # Get the artifacts bucket from the Pipeline stack
  ARTIFACT_BUCKET_STORE=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-ArtifactStoreBucket'].Value" --output text --region $REGION)

  # Empty the artifacts bucket (Otherwise stack delete will fail)
  if [[ "$ARTIFACT_BUCKET_STORE" != "" ]]; then
    echo "Will empty bucket $ARTIFACT_BUCKET_STORE - to prevent stack delete from failing..."
    aws s3 rm s3://$ARTIFACT_BUCKET_STORE --recursive
  fi

  # Get the bucket used for the Neptune data load.
  NEPTUNE_BUCKET=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-NeptuneLoaderBucket'].Value" --output text --region $REGION)

  if [[ "$NEPTUNE_BUCKET" != "" ]]; then
    # Empty the artifacts bucket (Otherwise stack delete will fail)
    echo "Will empty bucket $NEPTUNE_BUCKET - to prevent stack delete from failing..."
    aws s3 rm s3://$NEPTUNE_BUCKET  --recursive
  fi

  # Get the bucket used for the Redshift data load.
  RED_BUCKET=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-RedshiftCopyBucket'].Value" --output text --region $REGION)

  if [[ "$RED_BUCKET" != "" ]]; then
    # Empty the artifacts bucket (Otherwise stack delete will fail)
    echo "Will empty bucket $RED_BUCKET - to prevent stack delete from failing..."
    aws s3 rm s3://$RED_BUCKET  --recursive
  fi

  # Keep this order! 
  # NOTE: We are deleting both the PIPELINE and the Stack it produced (the actual datsbase.)
  STACK_NAME=$PREFIX-pipeline-mysql-instance
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-rds-mysql-instance
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-pipeline-aurora-mysql
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-aurora-mysql-instance
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-pipeline-aurora-postgres
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-aurora-postgres-instance
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-pipeline-redshift
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-redshift
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-pipeline-rds-cluster
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-rds-cluster
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-pipeline-docdb
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-docdb
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-pipeline-neptune
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-neptune
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  
  #
  # The  Repo and Secrets can't be deleted until the db stacks are gone.
  # Otherwise you'll get:
  # Export database-DBAdminSecretArn cannot be deleted as it is in use by database-pipeline-aurora-mysql-instance, database-pipeline-rds-mysql-instance and database-rds-mysql-instance
  #
  STACK_NAME=$PREFIX-rds-instance
  aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-rds-mysql-instance
  aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION
  
  STACK_NAME=$PREFIX-aurora-mysql-instance
  aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION
  
  STACK_NAME=$PREFIX-aurora-postgres-instance
  aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION
  
  STACK_NAME=$PREFIX-rds-cluster
  aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION
  
  STACK_NAME=$PREFIX-redshift
  aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-docdb
  aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-neptune
  aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION
   
  # Now, we can delete these...
  # ... but only after a 5 minute sleep. THere are some delays between the db stacks being 
  # gone and the ability to delete these!
  echo "Sleeping 5 minutes due to delays in dependencies..."
  sleep 300

  STACK_NAME=$PREFIX-repo
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

  STACK_NAME=$PREFIX-secrets
  echo "Deleting ($STACK_NAME) ..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
  aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION 

  # Get rid of snapshots
  VPC_ID=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-VpcId'].Value" --output text)
  echo "VPC_ID=$VPC_ID"
  ./97-cleanup-snapshots.sh $VPC_ID

  echo "Done."

  echo "Before you remove the $PREFIX-vpc stack you might want to ./unpeer.sh"

  exit 0
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