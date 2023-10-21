# Database Class Setup v2

This package allows you to easily setup one or more best-practices based AWS database instances for use in demonstrations.   It covers a broad variety of database types, and the intent is to be useful for the "Planning and Designing Databases" class.

This is an improvement over an older version.  This version is a non-monolithic setup to enable greater efficiency (time, cost) and flexbility when a trainer needs multiple database types for demonstrations - and it should work OK for single database demonstrations too.

# Pre-requisites

Requires:
* AWS CLI v2
* jq
* Bash shell

# Install

To install, run
```
./install.sh --bucket "private-bucket-name" --demos "multiaz-instance-mysql,redshift,documentdb,neptune,multiaz-cluster-postgress" --region us-east-1
```

The above will create multiple CodePipelines that will setup the database cluster/instance and populate with a example database schema.   

The above will create: 
* RDS MySQL Multi-Az Instance
* RDS Postgres Multi-AZ Cluster (with two readable instances)
* Redshift (data warehouse)
* Neptune database (Graph database)
* DocumentDB (document style database, MongoDB compatible)

Each CodePipeline will run separately.

# Uninstall

For convenience, there is a monolithic un-installer that will determine which stacks exist, and then delete all resources (in parallel for speed):
```
./uninstall.sh --region us-east-1 --force yes
```

# TODO

N/A - this whole project is a work in progress.