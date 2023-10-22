#!/bin/bash

#
# This is for dev use.
# Clone down the database-schemas repo, update files and commit in
# So you don't have to re-create the repo stack - which can't be updated.
#

cd ~/repo
rm -rf database-schemas
git clone codecommit::us-east-1://database-schemas

cp ~/repo/database-class-setup-v2/schemas/* ~/repo/database-schemas
cd ~/repo/database-schemas
git add . 
git commit -am "manual updates..."
git push


cd ~/repo/database-class-setup-v2