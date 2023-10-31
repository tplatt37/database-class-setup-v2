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
   
  DEMOS="test"
  
  for demo in $(echo $DEMOS | tr ',' ' ')
  do
    echo "Installing $demo ($REGION)..."

    case "$demo" in 
      
      "redshift")  
        aws cloudformation deploy \
        --template-file pipelines/pipeline-template.yaml \
        --parameter-overrides Name=redshift DatabaseTemplate=cfn-redshift.yaml Buildspec=buildspec-redshift.yml \
        --stack-name $PREFIX-pipeline-redshift \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION
        ;;

       "rds-mysql")
          aws cloudformation deploy \
          --template-file pipelines/pipeline-template.yaml \
          --parameter-overrides Name=rds-mysql-instance DatabaseTemplate=cfn-rds-mysql.yaml Buildspec=buildspec-rds-mysql.yml \
          --stack-name $PREFIX-pipeline-mysql-instance \
          --capabilities CAPABILITY_NAMED_IAM \
          --region $REGION
          ;;

       "aurora-mysql")
          aws cloudformation deploy \
          --template-file pipelines/pipeline-template.yaml \
          --parameter-overrides Name=aurora-mysql-instance DatabaseTemplate=cfn-aurora-mysql.yaml Buildspec=buildspec-aurora-mysql.yml \
          --stack-name $PREFIX-pipeline-aurora-mysql \
          --capabilities CAPABILITY_NAMED_IAM \
          --region $REGION
          ;;

       "aurora-postgres")
          aws cloudformation deploy \
          --template-file pipelines/pipeline-template.yaml \
          --parameter-overrides Name=aurora-postgres-instance DatabaseTemplate=cfn-aurora-postgres.yaml Buildspec=buildspec-aurora-postgres.yml \
           --stack-name $PREFIX-pipeline-aurora-postgres \
          --capabilities CAPABILITY_NAMED_IAM \
          --region $REGION
          ;;
  
        "postgres-cluster")

          # This one is DIFFERENT 
          # We have to deploy the database stack here in the Bash.
          # Long story short - I could not get it to work without a 400 error via pipeline 
          aws cloudformation deploy \
          --template-file schemas/cfn-postgres-cluster.yaml \
          --parameter-overrides Prefix=$PREFIX \
          --stack-name $PREFIX-postgres-cluster \
          --region $REGION 
          
          # Then deploy the pipeline that will specify the schema
          # note this uses the other template.
          aws cloudformation deploy \
          --template-file pipelines/pipeline-no-deploy-template.yaml \
          --parameter-overrides Name=postgres-cluster DatabaseTemplate=cfn-postgres-cluster.yaml Buildspec=buildspec-postgres-cluster.yml \
           --stack-name $PREFIX-pipeline-aurora-postgres \
          --capabilities CAPABILITY_NAMED_IAM \
          --region $REGION
          ;;

        "test")
          echo "Test..."
          ;;

    esac




  done

  exit 0


  
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