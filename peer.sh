#!/bin/bash
# Run this on a Cloud9 or EC2 instance to get Peered to the VPC created for the databases
# This is idempotent.  Run it as many times as you like, anything already existing won't be created a second time.

main() {

  # This is an arbitrary naming identifier that is used to ensure all stadks can be clearly identified as being part of this project.
  PREFIX="database"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        shift
        usage
        exit 1
        ;;
      --instance-id)
        shift
        if [[ "$1" != "" ]]; then
          INSTANCE_ID="$1"
        else
          err "Missing value for --instance-id."
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
      --ec2-region)
        shift
        if [[ "$1" != "" ]]; then
          EC2_REGION="$1"
        else
          err "Missing value for --ec2-region."
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

  # Which region? Display to user so they can double-check.
  # Our first preference is the --region argument, then AWS_DEFAULT_REGION, lastly just use that set in the profile.
  REGION=${REGION_ARG:-${AWS_DEFAULT_REGION:-$(aws configure get default.region)}}

  # Check for pre-requisites
  ./00-check-prereqs.sh
  if [[ $? -ne 0 ]]; then
      err "Missing prerequisites... exiting..."
      exit 1
  fi

  # IMPORTANT
  # REGION is the REGION the Databases are in
  # EC2_REGION is the REGION that the EC2 / C9 Instance is in.
  #

  # OPTIONAL: You can provide the EC2 INSTANCE_ID that you want to be able to use to connect to the databases.
  # It's easier if you just run this command from the C9/EC2 instance...
  # If you pass in an INSTANCE_ID you also need to pass in the REGION.
  # For example, if you are using a WINDOWS EC2 instance to run SCT - you can peer that up by passing in Instance ID / Region (without having to run this on Windows!)
  #
  validate_arguments


  echo "Checking for EC2 Instance $INSTANCE_ID in Region $EC2_REGION"

  VPC_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].VpcId" --output text --region $EC2_REGION)
  echo "VPC_ID for the Cloud9 instance is $VPC_ID."

  PRIVATE_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PrivateIpAddress" --output text --region $EC2_REGION)
  echo "PRIVATE_IP_ADDRESS for the Cloud9 instance is $PRIVATE_IP_ADDRESS."

  EXPORT_NAME=$PREFIX-VpcId
  DB_VPC_ID=$(aws cloudformation list-exports --query "Exports[?Name=='$EXPORT_NAME'].Value" --output text --region $REGION)
  echo "DB_VPC_ID=$DB_VPC_ID"
  if [[ -z $DB_VPC_ID ]]; then
    err "Can't find DB VPC - please double check regions"
    exit 1
  fi

  DB_VPC_CIDR_BLOCK=$(aws ec2 describe-vpcs --vpc-ids $DB_VPC_ID --query ["Vpcs[*].CidrBlock"] --output text --region $REGION)
  echo "DB_VPC_CIDR_BLOCK=$DB_VPC_CIDR_BLOCK"

  # Peering from the VPC / REGION Cloud9 is in to the VPC / REGION that the databases are in.
  # NOTE: Big assumption that you have your AWS CLI pointed to the REGION with the database VPC!
  #
  PEERING_ID=$(aws ec2 create-vpc-peering-connection --region $EC2_REGION --vpc-id $VPC_ID --peer-vpc-id $DB_VPC_ID --peer-region $REGION --output text --query "VpcPeeringConnection.VpcPeeringConnectionId")
  echo "PEERING_ID=$PEERING_ID"

  echo "Gonna wait for the VPC peering connection to come into existence..."
  aws ec2 wait vpc-peering-connection-exists --vpc-peering-connection-id $PEERING_ID --region $REGION

  echo "Accepting VPC Peering connection..."
  aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $PEERING_ID --region $REGION 1> /dev/null

  echo "Sleep 30 seconds, wait for VPC peering to be Active..."
  sleep 30

  echo "Modifying VPC Peering Connection to allow DNS Name Resolution"
  aws ec2 modify-vpc-peering-connection-options --requester-peering-connection-options AllowDnsResolutionFromRemoteVpc=true --vpc-peering-connection-id $PEERING_ID --region $EC2_REGION 1> /dev/null

  echo "Now adding the routes and security group ingress rules..."
  
  echo "Checking for Cloud9/EC2 Instance $INSTANCE_ID in Region $EC2_REGION"
  echo "DB_VPC_ID=$DB_VPC_ID"
  echo "DB_VPC_CIDR_BLOCK=$DB_VPC_CIDR_BLOCK"
  EC2_VPC_ID=$VPC_ID
  echo "VPC_ID for the EC2 instance is $EC2_VPC_ID."

  PRIVATE_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PrivateIpAddress" --output text --region $EC2_REGION)
  echo "PRIVATE_IP_ADDRESS for the Cloud9 instance is $PRIVATE_IP_ADDRESS."

  EC2_SUBNET_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].SubnetId" --output text --region $EC2_REGION)
  echo "SUBNET_ID=$EC2_SUBNET_ID"

  EC2_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --region $EC2_REGION --output text --query "RouteTables[*].Associations[?SubnetId=='$EC2_SUBNET_ID'].RouteTableId")
  echo "EC2_ROUTE_TABLE_ID=$EC2_ROUTE_TABLE_ID."

  # If var is empty... 
  if [[ ! $EC2_ROUTE_TABLE_ID ]]; then
      # If not route table listed, assume IMPLICIT Associaton to the main route table.
      echo "EC2 Must be using the Main Route Table! (Implicit Association)"
      # Must combine both server side --filter and client side --query to get the Main route table
      EC2_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --region $EC2_REGION --output text --query "RouteTables[?VpcId=='$EC2_VPC_ID'].RouteTableId" --filters "Name=association.main,Values=true" )
      echo "EC2_ROUTE_TABLE_ID=$EC2_ROUTE_TABLE_ID"

  fi

  # We need to add a Route to the CIDR of the remote VPC, pointing to the peering connection

  EC2_CIDR_BLOCK=$(aws ec2 describe-subnets --subnet-ids $EC2_SUBNET_ID --region $EC2_REGION --output text --query "Subnets[0].CidrBlock")
  echo "EC2_CIDR_BLOCK (Subnet)=$EC2_CIDR_BLOCK"

  EC2_VPC_CIDR_BLOCK=$(aws ec2 describe-vpcs --vpc-ids $EC2_VPC_ID --region $EC2_REGION --query ["Vpcs[*].CidrBlock"] --output text)
  echo "EC2_VPC_CIDR_BLOCK=$EC2_VPC_CIDR_BLOCK"


  # Deal with the destination route tables first.

  #
  # Subnet 01
  # 

  EXPORT_NAME=$PREFIX-PrivateSubnet01
  DB_SUBNET_ID_1=$(aws cloudformation list-exports --query "Exports[?Name=='$EXPORT_NAME'].Value" --output text --region $REGION)
  echo "DB_SUBNET_ID_1=$DB_SUBNET_ID_1"

  DB_SUBNET_CIDR_BLOCK_1=$(aws ec2 describe-subnets --subnet-ids $DB_SUBNET_ID_1 --region $REGION --output text --query "Subnets[0].CidrBlock")
  echo "DB_SUBNET_CIDR_BLOCK_1=$DB_SUBNET_CIDR_BLOCK_1"

  ROUTE_TABLE_ID_1=$(aws ec2 describe-route-tables --region $REGION --output text --query "RouteTables[*].Associations[?SubnetId=='$DB_SUBNET_ID_1'].RouteTableId")
  echo "ROUTE_TABLE_ID_1=$ROUTE_TABLE_ID_1"

  #
  # Subnet 02
  #

  EXPORT_NAME=$PREFIX-PrivateSubnet02
  DB_SUBNET_ID_2=$(aws cloudformation list-exports --query "Exports[?Name=='$EXPORT_NAME'].Value" --output text --region $REGION)
  echo "DB_SUBNET_ID_2=$DB_SUBNET_ID_2"

  DB_SUBNET_CIDR_BLOCK_2=$(aws ec2 describe-subnets --subnet-ids $DB_SUBNET_ID_2 --region $REGION --output text --query "Subnets[0].CidrBlock")
  echo "DB_SUBNET_CIDR_BLOCK_2=$DB_SUBNET_CIDR_BLOCK_2"


  ROUTE_TABLE_ID_2=$(aws ec2 describe-route-tables --region $REGION --output text --query "RouteTables[*].Associations[?SubnetId=='$DB_SUBNET_ID_2'].RouteTableId")
  echo "ROUTE_TABLE_ID_2=$ROUTE_TABLE_ID_2"


  # Add 1 Route Table entries so Cloud9 can reach all of the DB Private Subnets.
  aws ec2 create-route --region $EC2_REGION \
      --route-table-id $EC2_ROUTE_TABLE_ID \
      --vpc-peering-connection-id $PEERING_ID \
      --destination-cidr-block $DB_VPC_CIDR_BLOCK \
      > /dev/null

  # Add 2 Route Table Entries so the DB Private Subnets can reach Cloud9    
  aws ec2 create-route --region $REGION \
      --route-table-id $ROUTE_TABLE_ID_1 \
      --vpc-peering-connection-id $PEERING_ID \
      --destination-cidr-block $EC2_CIDR_BLOCK \
      > /dev/null
      
  aws ec2 create-route --region $REGION \
      --route-table-id $ROUTE_TABLE_ID_2 \
      --vpc-peering-connection-id $PEERING_ID \
      --destination-cidr-block $EC2_CIDR_BLOCK \
      > /dev/null


  #
  # Subnet 03
  #
  # This subnet is optional and will only be present if you overrode the UseThirdAZ parameter in the VPC stack.
  #

  echo "Checking to see if a 3rd private subnet was created..."
  DB_SUBNET_ID_3=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-PrivateSubnet03'].Value" --output text --region $REGION)
  echo "DB_SUBNET_ID_3=$DB_SUBNET_ID_3."

  if [[ $DB_SUBNET_ID_3 != "" ]]; then

      DB_SUBNET_CIDR_BLOCK_3=$(aws ec2 describe-subnets --subnet-ids $DB_SUBNET_ID_3 --region $REGION --output text --query "Subnets[0].CidrBlock")
      echo "DB_SUBNET_CIDR_BLOCK_3=$DB_SUBNET_CIDR_BLOCK_3"
      
      ROUTE_TABLE_ID_3=$(aws ec2 describe-route-tables --region $REGION --output text --query "RouteTables[*].Associations[?SubnetId=='$DB_SUBNET_ID_3'].RouteTableId")
      echo "ROUTE_TABLE_ID_3=$ROUTE_TABLE_ID_3"
          
      aws ec2 create-route --region $REGION \
          --route-table-id $ROUTE_TABLE_ID_3 \
          --vpc-peering-connection-id $PEERING_ID \
          --destination-cidr-block $EC2_CIDR_BLOCK \
          > /dev/null
  else
      echo "3rd private subnet not found... that's OK."
  fi
      
  # Now, update the DB security group to accept TCP 3306, 5432, 5439, 27017 from C9 IP
  DB_SECURITY_GROUP=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-DBSecurityGroup'].Value" --output text --region $REGION)
  echo "DB_SECURITY_GROUP=$DB_SECURITY_GROUP"

  # Mysql (or postgres on 3306)
  aws ec2 authorize-security-group-ingress --region $REGION \
      --group-id $DB_SECURITY_GROUP \
      --protocol tcp \
      --port 3306 \
      --cidr $EC2_CIDR_BLOCK
      
  # Postgresql
  aws ec2 authorize-security-group-ingress --region $REGION \
      --group-id $DB_SECURITY_GROUP \
      --protocol tcp \
      --port 5432 \
      --cidr $EC2_CIDR_BLOCK

  # DocumentDB / MongoDB
  aws ec2 authorize-security-group-ingress --region $REGION \
      --group-id $DB_SECURITY_GROUP \
      --protocol tcp \
      --port 27017 \
      --cidr $EC2_CIDR_BLOCK

  # NeptuneDB
  aws ec2 authorize-security-group-ingress --region $REGION \
      --group-id $DB_SECURITY_GROUP \
      --protocol tcp \
      --port 8182 \
      --cidr $EC2_CIDR_BLOCK

  # Redshift
  aws ec2 authorize-security-group-ingress --region $REGION \
      --group-id $DB_SECURITY_GROUP \
      --protocol tcp \
      --port 5439 \
      --cidr $EC2_CIDR_BLOCK

  echo "Done."


  exit 0
}

err() {
   echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

usage() {
  echo " Enable connectivity to the databases via a VPC Peering connection, route table entries, and SG rules"
  echo " "
  echo " --instance-id : Instance ID of the machine you want to use as the source (Optional)"
  echo " --region : Region where the DATABASE stacks are (Optional)"
  echo " --ec2-region : Region where the EC2 instance is (Optional)"
  echo " --help : This help."
  echo " "
  exit 1
}

validate_arguments() {

  if [ -z "$INSTANCE_ID" ]; then
    read -p "Are you running this on the Cloud9 or EC2 instance that you wish to use for demos? (Yy) " -n 1 -r
    echo    # (optional) move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      err "Well... you need to give me the INSTANCE ID and REGION of the instance as input parameters!"
      exit 1
    fi
      
    # Get the Instance ID via IMDSv2
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
      
    # Must figure out which REGION this EC2 instance is in.
    EC2_AVAIL_ZONE=`curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone`
    if [[ -z $EC2_AVAIL_ZONE ]]; then
      err "Could not access Instance Meta Data Service (IMDS). Exiting..."
      exit 2
    fi
    EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed 's/[a-z]$//'`"

  else
      
    if [ -z "$EC2_REGION" ]; then
      err "Need to know the REGION for the instance ID $INSTANCE_ID..."
      exit 2
    fi
  fi

}

main "$@"