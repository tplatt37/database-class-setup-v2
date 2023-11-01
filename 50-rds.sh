#!/bin/bash

#
# Basic RDS Multi-AZ Instance?
#

function create_cfn_stack() {
  local stack_name=$1
  local template_file=$2
  shift 2
  local cli_args=$@
  
  aws cloudformation create-stack \
    --stack-name "${stack_name}" \
    --template-body "file://pipelines/${template_file}" \
    --parameters ${cli_args} \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION
}

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

      --demos)
        shift
        if [[ "$1" != "" ]]; then
          DEMOS="$1"
        else
          err "Missing value for --demos."
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

  echo "Creating CodePipeline ... ($REGION) ..."

  for demo in $(echo $DEMOS | tr ',' ' ')
  do
    echo "Installing $demo ($REGION)..."

    case "$demo" in 

      # TODO: use create-stack for greater parrallelization

      "redshift")  
        create_cfn_stack $PREFIX-pipeline-redshift pipeline-template.yaml ParameterKey=Name,ParameterValue=redshift ParameterKey=DatabaseTemplate,ParameterValue=cfn-redshift.yaml ParameterKey=Buildspec,ParameterValue=buildspec-redshift.yml
        ;;

       "rds-mysql")
          create_cfn_stack $PREFIX-pipeline-mysql-instance pipeline-template.yaml ParameterKey=Name,ParameterValue=rds-mysql-instance ParameterKey=DatabaseTemplate,ParameterValue=cfn-rds-mysql.yaml ParameterKey=Buildspec,ParameterValue=buildspec-rds-mysql.yml
          ;;

       "aurora-mysql")
          create_cfn_stack $PREFIX-pipeline-aurora-mysql pipeline-template.yaml ParameterKey=Name,ParameterValue=aurora-mysql-instance ParameterKey=DatabaseTemplate,ParameterValue=cfn-aurora-mysql.yaml ParameterKey=Buildspec,ParameterValue=buildspec-aurora-mysql.yml
          ;;

       "aurora-postgres")
          create_cfn_stack $PREFIX-pipeline-aurora-postgres pipeline-template.yaml ParameterKey=Name,ParameterValue=aurora-postgres-instance ParameterKey=DatabaseTemplate,ParameterValue=cfn-aurora-postgres.yaml ParameterKey=Buildspec,ParameterValue=buildspec-aurora-postgres.yml
          ;;

       "docdb")
          create_cfn_stack $PREFIX-pipeline-docdb pipeline-template.yaml ParameterKey=Name,ParameterValue=docdb ParameterKey=DatabaseTemplate,ParameterValue=cfn-docdb.yaml ParameterKey=Buildspec,ParameterValue=buildspec-docdb.yml
          ;;

       "neptune")
          create_cfn_stack $PREFIX-pipeline-neptune pipeline-template.yaml ParameterKey=Name,ParameterValue=neptune ParameterKey=DatabaseTemplate,ParameterValue=cfn-neptune.yaml ParameterKey=Buildspec,ParameterValue=buildspec-neptune.yml
          ;;

       "postgres-cluster")
          #
          # For an RDS Multi-AZ Cluster - the stack name must be <=21 chars (or 400 will happen)!
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

          create_cfn_stack $PREFIX-pipeline-postgres-cluster pipeline-template.yaml ParameterKey=Name,ParameterValue=rds-cluster ParameterKey=DatabaseTemplate,ParameterValue=cfn-postgres-cluster.yaml ParameterKey=Buildspec,ParameterValue=buildspec-postgres-cluster.yml
          ;;

        "test")
          echo "Test...nothing created (PREFIX=$PREFIX) (REGION=$REGION)"
          ;;

    esac

  done

  echo "Done."
}

err() {
   echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

usage() {
  echo " Create one or more RDS or Database Instances."
  echo " "
  echo " --demos : Any (or all) of the following in a comma-delimited list: redshift,rds-mysql,aurora-mysql,aurora-postgres,docdb,neptune,postgres-cluster"
  echo " --region : Region (Optional)"
  echo " --help : This help."
  echo " "
  exit 1
}

validate_arguments() {

  for demo in $(echo $DEMOS | tr ',' ' ')
  do
   
    case "$demo" in 
      
      "redshift")  
        ;;

       "rds-mysql")
        ;;

       "aurora-mysql")
        ;;

       "aurora-postgres")
        ;;

       "docdb")
        ;;

       "neptune")
        ;;

       "postgres-cluster")
        ;;

        "test")
        ;;

        *)
        err "Invalid demo: $demo"
        exit 1

    esac

  done

  return

}



main "$@"