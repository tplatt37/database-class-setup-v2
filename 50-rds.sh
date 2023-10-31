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
   
  DEMOS="test,postgres-cluster"

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
          #
          # Resource handler returned message: "The specified resource name does not match an RDS resource in this region. (Service: Rds, Status Code: 400, Request ID: 24e5832f-c01c-4f3a-92a2-5b108d1a84ea)" (RequestToken: 98a044a7-44f6-1d86-205d-7a6844fccaaa, HandlerErrorCode: InvalidRequest)
          # This will sound crazy, but don't change the stack name of rds-cluster (Name parameter below)
          # For some reason it is very picky about the stack name and sometimes it won't work - it'll fail with a 400 error.
          # It *might* be the LENGTH of the name.  It's gotta be not longer than 11 chars?
          # That's a theory. It took LOTS of trial and error to pinpoint this limitation.
          # Stack name can't be > 21 in length.
        
          # database-rds-cluster works
          # database-rds-cluster-abc (us-east-2) failed
          # database-rds-cluster-ab (us-east-1) failed
          # database-rds-cluster-a (us-east-2) failed
          # database-rds-cluster- (us-east-1) works
          # database-1234567890123 - (us-east-2) Failed
          # database-123456789012 - (us-east-2) works 
          # 123456789012345678901

          aws cloudformation deploy \
          --template-file pipelines/pipeline-template.yaml \
          --parameter-overrides Name=rds-cluster DatabaseTemplate=rds-cluster.yaml Buildspec=buildspec-postgres-cluster.yml \
           --stack-name $PREFIX-pipeline-rds-cluster \
          --capabilities CAPABILITY_NAMED_IAM \
          --region $REGION
          ;;

        "test")
          echo "Test...nothing created (PREFIX=$PREFIX) (REGION=$REGION)"
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