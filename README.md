# Database Class Setup v2

This package allows you to easily setup one or more best-practices based AWS database instances for use in demonstrations.   It covers a broad variety of database types, and the intent is to be useful for the "Planning and Designing Databases" class.

This is an improvement over an older version.  This new version is a non-monolithic setup to enable greater efficiency (time, cost) and flexbility when a trainer needs multiple database types for demonstrations - and it should work OK for single database demonstrations too.  This means it is appropriate for any class demonstrations requiring a database.

All databases will leverage the same VPC, and a common admin user/password stored in Secrets Manager, for simplicity.

# Pre-requisites

Requires:
* AWS CLI v2
* jq
* Bash shell

Additional pre-requisites:
* A VPC created via the Super-VPC package.


# Demo Options

This package is capable of creating:
* RDS Aurora MySQL Multi-Az Instance (with primary/standby)
* RDS Aurora Postgres Multi-Az Instance (with primary/standby)
* RDS Postgres Multi-AZ Cluster (with primary and two readable standbys)
* Redshift cluster (data warehouse)
* Neptune cluster (Graph database)
* DocumentDB (document style database, MongoDB compatible)

All databases will include a sample Schema appropriate for the type:
* HR sample database for MySQL/Postgres
* TICKIT sample database for Redshift
* Cases sample for DocumentDB
* Collaborative filtering example for Neptune 

This package can also install the required client tools (CLI) for demonstrating functionality, including certificates, etc.

# Install

To install, run
```
./install.sh --bucket "private-bucket-name" --demos "multiaz-instance-mysql,redshift,documentdb,neptune,multiaz-cluster-postgress" --region us-east-1
```

The above will create multiple CodePipelines that will setup the database cluster/instance and populate with a example database schema.   

The above will create a subset of the available types, as dictated by the --demos option.

Each CodePipeline will run separately.

# Connecting to the databases

For ease of use, there are a set of helper scripts that make it easy to connect to and utilize the databases from the command line.

For example, to use the psql CLI to connect to the Multi-AZ PostgresSQL Cluster :
```
./11-get-certs.sh
scripts/connect-pg ....
```

The helper script retrieves the endpoint, ports, username, password, etc. automatically.


# Uninstall

For convenience, there is a monolithic un-installer that will determine which stacks exist, and then delete all resources (in parallel for speed):
```
./uninstall.sh --region us-east-1 --force yes
```

# TODO

N/A - this whole project is a work in progress.