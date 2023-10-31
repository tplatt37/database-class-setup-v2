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
   
  DEMOS="test,rds-cluster"

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

       "rds-cluster")
          aws cloudformation deploy \
          --template-file pipelines/pipeline-template.yaml \
          --parameter-overrides Name=rds-cluster DatabaseTemplate=rds-cluster.yaml Buildspec=buildspec-postgres-cluster.yml \
           --stack-name $PREFIX-pipeline-rds-cluster \
          --capabilities CAPABILITY_NAMED_IAM \
          --region $REGION
          ;;

        "xxxpostgres-cluster")

          # Resource handler returned message: "The specified resource name does not match an RDS resource in this region. (Service: Rds, Status Code: 400, Request ID: 656ccd70-ce9e-4076-8570-172b7aeabb85)" (RequestToken: 340b4865-11bc-cfc9-db4f-3d8c7762576b, HandlerErrorCode: InvalidRequest)

          # This one is DIFFERENT 
          # We have to deploy the database stack here in the Bash.
          # Long story short - I could not get it to work without a 400 error via pipeline 
          # You MUST MUST MUST do a create-stack -not a deploy
          echo "PREFIX=$PREFIX"
          echo "REGION=$REGION"
          export AWS_DEFAULT_REGION=$REGION
          aws cloudformation create-stack  --template-body file://schemas/rds-cluster.yaml --stack-name $PREFIX-rds-cluster 
          
          exit 0
          
          # Then deploy the pipeline that will specify the schema
          # note this uses the other template.
          aws cloudformation deploy \
          --template-file pipelines/pipeline-no-deploy-template.yaml \
          --parameter-overrides Name=postgres-cluster Buildspec=buildspec-postgres-cluster.yml \
          --stack-name $PREFIX-pipeline-postgres-cluster \
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