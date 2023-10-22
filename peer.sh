#!/bin/bash
# Run this on a Cloud9 or EC2 instance to get Peered to the VPC created for the databases
# This is idempotent.  Run it as many times as you like, anything already existing won't be created a second time.

PREFIX="database"

# Assume the current region is the REGION where the Database VPC is.
REGION=${AWS_DEFAULT_REGION:-$(aws configure get default.region)}

# IMPORTANT
# REGION is the REGION the Databases are in
# C9_REGION is the REGION that the EC2 / C9 Instance is in.
#
#

# OPTIONAL: You can provide the EC2 INSTANCE_ID that you want to be able to use to connect to the databases.
# It's easier if you just run this command from the C9/EC2 instance...
# If you pass in an INSTANCE_ID you also need to pass in the REGION.
# For example, if you are using a WINDOWS EC2 instance to run SCT - you can peer that up by passing in Instance ID / Region (without having to run this on Windows!)
#

if [ -z $1 ]; then
    read -p "Are you running this on the Cloud9 or EC2 instance that you wish to use for demos? (Yy) " -n 1 -r
    echo    # (optional) move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        echo "Well... you need to give me the INSTANCE ID and REGION of the instance as input parameters!"
        exit 1
    fi
    
    # Get the Instance ID via IMDS
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    
    # Must figure out which REGION this Cloud9 instance is in.
    EC2_AVAIL_ZONE=`curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone`
    if [[ -z $EC2_AVAIL_ZONE ]]; then
            echo "Could not access Instance Meta Data Service (IMDS). Exiting..."
            exit 2
    fi
    C9_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed 's/[a-z]$//'`"

else
    INSTANCE_ID=$1
    
    if [ -z $2 ]; then
        echo "Need to know the REGION for the instance ID $INSTANCE_ID..."
        exit 2
    fi
    
    C9_REGION=$2
    
fi

echo "Checking for Cloud9/EC2 Instance $INSTANCE_ID in Region $C9_REGION"

VPC_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].VpcId" --output text --region $C9_REGION)
echo "VPC_ID for the Cloud9 instance is $VPC_ID."

PRIVATE_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PrivateIpAddress" --output text --region $C9_REGION)
echo "PRIVATE_IP_ADDRESS for the Cloud9 instance is $PRIVATE_IP_ADDRESS."

EXPORT_NAME=$PREFIX-VpcId
DB_VPC_ID=$(aws cloudformation list-exports --query "Exports[?Name=='$EXPORT_NAME'].Value" --output text)
echo "DB_VPC_ID=$DB_VPC_ID"

DB_VPC_CIDR_BLOCK=$(aws ec2 describe-vpcs --vpc-ids $DB_VPC_ID --query ["Vpcs[*].CidrBlock"] --output text)
echo "DB_VPC_CIDR_BLOCK=$DB_VPC_CIDR_BLOCK"

# Peering from the VPC / REGION Cloud9 is in to the VPC / REGION that the databases are in.
# NOTE: Big assumption that you have your AWS CLI pointed to the REGION with the database VPC!
#
PEERING_ID=$(aws ec2 create-vpc-peering-connection --region $C9_REGION --vpc-id $VPC_ID --peer-vpc-id $DB_VPC_ID --peer-region $REGION --output text --query "VpcPeeringConnection.VpcPeeringConnectionId")
echo "PEERING_ID=$PEERING_ID"

echo "Gonna wait for the VPC peering connection to come into existence..."
aws ec2 wait vpc-peering-connection-exists --vpc-peering-connection-id $PEERING_ID --region $REGION

echo "Accepting VPC Peering connection..."
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $PEERING_ID --region $REGION 1> /dev/null

echo "Sleep 30 seconds, wait for VPC peering to be Active..."
sleep 30

echo "Modifying VPC Peering Connection to allow DNS Name Resolution"
aws ec2 modify-vpc-peering-connection-options --requester-peering-connection-options AllowDnsResolutionFromRemoteVpc=true --vpc-peering-connection-id $PEERING_ID --region $C9_REGION 1> /dev/null

echo "Now calling routes.sh to add the routes and security group ingress rules..."
./routes.sh $PEERING_ID $INSTANCE_ID $C9_REGION

exit 0