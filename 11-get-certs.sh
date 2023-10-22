#!/bin/bash

# Get various certs we'll need to securely connect to the databses using SSL/TLS

# First, clean-up
rm -f scripts/*.pem*
rm -f scripts/*.crt*

# Certificate Bundle for SSL/TLS connections - Get latest rds-combined-ca-bundle-pem (all regions)
# We put it in scripts folder, because we'll run various helper connect commands from there.
# https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html
wget -P scripts https://s3.amazonaws.com/redshift-downloads/amazon-trust-ca-bundle.crt
wget -P scripts https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem
wget -P scripts https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem