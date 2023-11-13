#!/bin/bash

# How to run this :
# source ./connect-pg.sh --database multiaz-cluster --mode rw --region us-east-1
# source ./failover-test.sh
#
# Then go to the console and "Actions" -> "Failover".
# Watch it fail, and then be OK after about 35 seconds
#
# Recommended you use Multi-AZ Cluster - which fails over the quickest.
# This assumes hr schema is in place!
#

# Timeout
export PGCONNECT_TIMEOUT=1

counter=0
failure=0

while true; do

  # Clear the output
  printf "\033c"

  # NOTE: We order by "random" to make the output more interesting and less mundane
  psql --host=$HOST --port=$PORT "dbname=hr user=$USER sslmode=verify-full sslrootcert=./global-bundle.pem" -c 'select * from jobs order by random()*20+1;';

  if [[ $? != 0 ]]; then
    failure=$((failure+1))
  fi

  counter=$((counter+1))
  echo "Iteration: $counter Failures: $failure"
  sleep 1;

done
