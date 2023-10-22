#!/bin/bash
# Run this on a Cloud9 instance to get Peered to the VPC created for the databases
#
# This basically UNDOES what peer.sh and routes.sh do.
#
# Removes the Routing Table entries that were added for peering (from both sides)
# Removes the DB Security Group ingress rules that were added to allow traffic from C9
# Removes the Peering Connection.
#
#

PREFIX="database"

# This is the REGION where the Database VPC is.
REGION=${AWS_DEFAULT_REGION:-$(aws configure get default.region)}

# IMPORTANT
# REGION is the REGION the Databases are in
# C9_REGION is the REGION that the EC2 / C9 Instance is in.
#
#

# OPTIONAL: You can provide the EC2 INSTANCE_ID that you want to be able to use to connect to the databases.
# It's easier if you just run this command from the C9/EC2 instance...
# If you pass in an INSTANCE_ID you also need to pass in the REGION.

if [ -z $1 ]; then
    read -p "Are you running this on the Cloud9 or EC2 instance that you wish to UNPEER? (Yy) " -n 1 -r
    echo    # (optional) move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        echo "Well... I need you to give me the INSTANCE ID and REGION as parameters, please!"
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

echo "Checking for Cloud9 Instance $INSTANCE_ID in Region $C9_REGION"

VPC_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].VpcId" --output text --region $C9_REGION)
echo "VPC_ID for the Cloud9 instance is $VPC_ID."

EXPORT_NAME=$PREFIX-VpcId
DB_VPC_ID=$(aws cloudformation list-exports --query "Exports[?Name=='$EXPORT_NAME'].Value" --output text)
echo "DB_VPC_ID=$DB_VPC_ID"

# NOTE: We're using server side --filter to make sure we find the proper ACTIVE peering connection between the two VPCs.
# See: https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-vpc-peering-connections.html (--filters)
PCX_ID=$(aws ec2 describe-vpc-peering-connections --filters "Name=accepter-vpc-info.vpc-id,Values=$DB_VPC_ID" "Name=requester-vpc-info.vpc-id,Values=$VPC_ID" "Name=status-code,Values=active" --query "VpcPeeringConnections[*].VpcPeeringConnectionId" --output text --region $C9_REGION)
echo "PCX_ID=$PCX_ID"

echo "Deleting Route in the Cloud9 Subnet Route table"

C9_VPC_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].VpcId" --output text --region $C9_REGION)
echo "VPC_ID for the Cloud9 instance is $C9_VPC_ID."

C9_SUBNET_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].SubnetId" --output text --region $C9_REGION)
echo "SUBNET_ID=$C9_SUBNET_ID"

C9_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --region $C9_REGION --output text --query "RouteTables[*].Associations[?SubnetId=='$C9_SUBNET_ID'].RouteTableId")
echo "C9_ROUTE_TABLE_ID=$C9_ROUTE_TABLE_ID."

if [[ $C9_ROUTE_TABLE_ID -eq "" ]]; then
    # If not route table listed, assume IMPLICIT Associaton to the main route table.
    echo "C9 Must be using the Main Route Table! (Implicit Association)"
    # Based off this : https://stackoverflow.com/questions/66599866/aws-api-how-to-get-main-route-table-id-by-subnet-id-association-subnet-id-fil
    # Must combine both server side --filter and client side --query to get the Main route table
    # I have NOT tested this extensively...
    C9_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --region $C9_REGION --output text --query "RouteTables[?VpcId=='$C9_VPC_ID'].RouteTableId" --filters "Name=association.main,Values=true" )
    echo "C9_ROUTE_TABLE_ID=$C9_ROUTE_TABLE_ID"

fi

C9_CIDR_BLOCK=$(aws ec2 describe-subnets --subnet-ids $C9_SUBNET_ID --region $C9_REGION --output text --query "Subnets[0].CidrBlock")
echo "C9_CIDR_BLOCK=$C9_CIDR_BLOCK"


# We need to remove the route from the C9 route table BEFORE we delete the Peering Connection.
EXPORT_NAME=$PREFIX-VpcId
DB_VPC_ID=$(aws cloudformation list-exports --query "Exports[?Name=='$EXPORT_NAME'].Value" --output text)
echo "DB_VPC_ID=$DB_VPC_ID"

DB_VPC_CIDR_BLOCK=$(aws ec2 describe-vpcs --vpc-ids $DB_VPC_ID --query ["Vpcs[*].CidrBlock"] --output text)
echo "DB_VPC_CIDR_BLOCK=$DB_VPC_CIDR_BLOCK"

aws ec2 delete-route --route-table-id $C9_ROUTE_TABLE_ID --destination-cidr-block $DB_VPC_CIDR_BLOCK --region $C9_REGION

#
# Subnet 01
# 

EXPORT_NAME=$PREFIX-PrivateSubnet01
DB_SUBNET_ID_1=$(aws cloudformation list-exports --query "Exports[?Name=='$EXPORT_NAME'].Value" --output text)
echo "DB_SUBNET_ID_1=$DB_SUBNET_ID_1"

DB_SUBNET_CIDR_BLOCK_1=$(aws ec2 describe-subnets --subnet-ids $DB_SUBNET_ID_1 --region $REGION --output text --query "Subnets[0].CidrBlock")
echo "DB_SUBNET_CIDR_BLOCK_1=$DB_SUBNET_CIDR_BLOCK_1"

ROUTE_TABLE_ID_1=$(aws ec2 describe-route-tables --region $REGION --output text --query "RouteTables[*].Associations[?SubnetId=='$DB_SUBNET_ID_1'].RouteTableId")
echo "ROUTE_TABLE_ID_1=$ROUTE_TABLE_ID_1"

echo "Removing Route Table entry 1 ..."
aws ec2 delete-route --route-table-id $ROUTE_TABLE_ID_1 --destination-cidr-block $C9_CIDR_BLOCK

#
# Subnet 02
#

EXPORT_NAME=$PREFIX-PrivateSubnet02
DB_SUBNET_ID_2=$(aws cloudformation list-exports --query "Exports[?Name=='$EXPORT_NAME'].Value" --output text)
echo "DB_SUBNET_ID_2=$DB_SUBNET_ID_2"

DB_SUBNET_CIDR_BLOCK_2=$(aws ec2 describe-subnets --subnet-ids $DB_SUBNET_ID_2 --region $REGION --output text --query "Subnets[0].CidrBlock")
echo "DB_SUBNET_CIDR_BLOCK_2=$DB_SUBNET_CIDR_BLOCK_2"


ROUTE_TABLE_ID_2=$(aws ec2 describe-route-tables --region $REGION --output text --query "RouteTables[*].Associations[?SubnetId=='$DB_SUBNET_ID_2'].RouteTableId")
echo "ROUTE_TABLE_ID_2=$ROUTE_TABLE_ID_2"

echo "Removing Route Table entry 2 ..."
aws ec2 delete-route --route-table-id $ROUTE_TABLE_ID_2 --destination-cidr-block $C9_CIDR_BLOCK

#
# Subnet 03
#
# This subnet is optional and will only be present if you overrode the UseThirdAZ parameter in the VPC stack.
#

echo "Checking to see if a 3rd private subnet was created..."
DB_SUBNET_ID_3=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-PrivateSubnet03'].Value" --output text)
echo "DB_SUBNET_ID_3=$DB_SUBNET_ID_3."

if [[ $DB_SUBNET_ID_3 != "" ]]; then

    DB_SUBNET_CIDR_BLOCK_3=$(aws ec2 describe-subnets --subnet-ids $DB_SUBNET_ID_3 --region $REGION --output text --query "Subnets[0].CidrBlock")
    echo "DB_SUBNET_CIDR_BLOCK_3=$DB_SUBNET_CIDR_BLOCK_3"
    
    ROUTE_TABLE_ID_3=$(aws ec2 describe-route-tables --region $REGION --output text --query "RouteTables[*].Associations[?SubnetId=='$DB_SUBNET_ID_3'].RouteTableId")
    echo "ROUTE_TABLE_ID_3=$ROUTE_TABLE_ID_3"
    
    echo "Removing Route Table entry 3 ..."
    aws ec2 delete-route --route-table-id $ROUTE_TABLE_ID_3 --destination-cidr-block $C9_CIDR_BLOCK

fi

# Now, update the security group to no longer allow TCP 3306, 5432, and 27017 from C9 IP
EXPORT_NAME=$PREFIX-DBSecurityGroup
DB_SECURITY_GROUP=$(aws cloudformation list-exports --query "Exports[?Name=='$EXPORT_NAME'].Value" --output text)
echo "DB_SECURITY_GROUP=$DB_SECURITY_GROUP"

# Mysql
aws ec2 revoke-security-group-ingress --region $REGION \
    --group-id $DB_SECURITY_GROUP \
    --protocol tcp \
    --port 3306 \
    --cidr $C9_CIDR_BLOCK
    
# Postgresql
aws ec2 revoke-security-group-ingress --region $REGION \
    --group-id $DB_SECURITY_GROUP \
    --protocol tcp \
    --port 5432 \
    --cidr $C9_CIDR_BLOCK

# DocumentDB / MongoDB
aws ec2 revoke-security-group-ingress --region $REGION \
    --group-id $DB_SECURITY_GROUP \
    --protocol tcp \
    --port 27017 \
    --cidr $C9_CIDR_BLOCK

# NeptuneDB
aws ec2 revoke-security-group-ingress --region $REGION \
    --group-id $DB_SECURITY_GROUP \
    --protocol tcp \
    --port 8182 \
    --cidr $C9_CIDR_BLOCK
    
# Redshift
aws ec2 revoke-security-group-ingress --region $REGION \
    --group-id $DB_SECURITY_GROUP \
    --protocol tcp \
    --port 5439 \
    --cidr $C9_CIDR_BLOCK

# The LAST thing we do is remove the Peering Connection...
echo "Removing Peering connection..."
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $PCX_ID --region $C9_REGION

echo "Done."