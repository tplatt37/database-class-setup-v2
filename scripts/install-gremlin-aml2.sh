#!/bin/bash

# This installs Gremlin console.  Works on Cloud9 (Amazon Linux 2)
# See: https://docs.aws.amazon.com/neptune/latest/userguide/access-graph-gremlin-console.html

PREFIX=database

sudo yum install java-1.8.0-devel -y

echo ""
echo "***"
echo "At this next prompt, choose Java 1.8..."
echo "***"
echo ""
sudo /usr/sbin/alternatives --config java

wget https://archive.apache.org/dist/tinkerpop/3.4.8/apache-tinkerpop-gremlin-console-3.4.8-bin.zip

# Force overwrite with -o
unzip -o apache-tinkerpop-gremlin-console-3.4.8-bin.zip 1>/dev/null

wget https://www.amazontrust.com/repository/SFSRootCAG2.cer

mkdir -p /tmp/certs/

# NOTE: Skipping this.  Doesn't seem to matter?
# I don't run anything else java though...
# cp jre_path/lib/security/cacerts /tmp/certs/cacerts

sudo keytool -importcert \
             -alias neptune-tests-ca \
             -keystore /tmp/certs/cacerts \
             -file  ./SFSRootCAG2.cer \
             -noprompt \
             -storepass changeit

# Get values that we need for the connection configuration
HOST=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-NeptuneDBEndpoint'].Value" --output text)
echo "HOST=$HOST"

PORT=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-NeptuneDBPort'].Value" --output text)
echo "PORT=$PORT"

             
cat << EoF > ./apache-tinkerpop-gremlin-console-3.4.8/conf/neptune-remote.yaml
hosts: [$HOST]
port: $PORT
connectionPool: { enableSsl: true,  trustStore: /tmp/certs/cacerts }
serializer: { className: org.apache.tinkerpop.gremlin.driver.ser.GraphBinaryMessageSerializerV1, config: { serializeResultToString: true }}
EoF

echo " "
echo " "
echo " Install done. "
echo " "
echo " "

echo "Gremlin console installed at ./apache-tinkerpop-gremlin-console-3.4.8"
echo " "
echo "When ready to connect to your Neptune instance, run this:"
echo "./scripts/connect-nep.sh"
