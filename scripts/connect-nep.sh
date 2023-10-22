#!/bin/bash
# Easy connect to your Neptune cluster using Gremlin

# First, is Gremlin installed already ? 
#
if [[ ! -d ./apache-tinkerpop-gremlin-console-3.6.5 ]]; then
    echo "Gremlin doesn't appear to be installed. Please run or re-run ./scripts/install-gremlin.sh first."
    echo "Exiting..."
    exit 1
fi

if [[ ! -f ./apache-tinkerpop-gremlin-console-3.6.5/conf/neptune-remote.yaml ]]; then
    echo "Gremlin doesn't appear to be installed (conf/neptune-remote.yaml missing). Please run or re-run ./scripts/install-gremlin.sh first."
    echo "Exiting..."
    exit 1
fi

echo ""
echo "When the Gremlin command line appears (gremlin>), please run the following:"
echo ""
echo ":remote connect tinkerpop.server conf/neptune-remote.yaml"
echo ":remote console"
echo ""
echo "Here's a query you can run:"
echo "g.V().limit(5)"
echo " "
echo ":exit  (when done)"
echo ""

./apache-tinkerpop-gremlin-console-3.6.5/bin/gremlin.sh