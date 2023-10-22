#!/bin/bash

# This installs Gremlin console.  For Amazon Linux 2023.
# See: https://docs.aws.amazon.com/neptune/latest/userguide/access-graph-gremlin-console.html

main(){

  DIST=$(cat /etc/os-release | grep -oP 'PRETTY_NAME="\K[^"]+')
  if [[ "$DIST" != "Amazon Linux 2023" ]]; then
    err "This script only works on Amazon Linux 2023"
    exit 1
  fi

  # This will be aarch64 or x86_64
  ARCH_TYPE=$(uname -m)
  echo "ARCH_TYPE=$ARCH_TYPE"

  if [[ "$ARCH_TYPE" != "x86_64" ]]; then
    err "This script only works for x86_64 / AMD64."
    exit 1
  fi  

  PREFIX=database
  sudo yum install java-11-amazon-corretto-devel
  
  echo ""
  echo "***"
  echo "At this next prompt, choose Java 11..."
  echo "***"
  echo ""
  sudo /usr/sbin/alternatives --config java

  wget https://archive.apache.org/dist/tinkerpop/3.6.5/apache-tinkerpop-gremlin-console-3.6.5-bin.zip

  # Force overwrite with -o
  unzip -o apache-tinkerpop-gremlin-console-3.6.5-bin.zip 1>/dev/null

  # Got certs? 
  # https://docs.aws.amazon.com/neptune/latest/userguide/security-ssl.html

  # I don't believe any of this is required any longer. 
  # See above
  # wget https://www.amazontrust.com/repository/SFSRootCAG2.cer
  # mkdir -p /tmp/certs/
  # sudo keytool -importcert \
  #              -alias neptune-tests-ca \
  #              -keystore /tmp/certs/cacerts \
  #              -file  ./SFSRootCAG2.cer \
  #              -noprompt \
  #              -storepass changeit

  # Get values that we need for the connection configuration
  HOST=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-NeptuneDBEndpoint'].Value" --output text)
  echo "HOST=$HOST"

  PORT=$(aws cloudformation list-exports --query "Exports[?Name=='$PREFIX-NeptuneDBPort'].Value" --output text)
  echo "PORT=$PORT"
              
  # We no longer need this.  There's a public wildcard cert now. (See below)
  #connectionPool: { enableSsl: true,  trustStore: /tmp/certs/cacerts }

  cat << EoF > ./apache-tinkerpop-gremlin-console-3.6.5/conf/neptune-remote.yaml
hosts: [$HOST]
port: $PORT
connectionPool: { enableSsl: true }
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

}

# Any error should got to STDERR
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

main "$@"