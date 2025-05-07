#!/bin/bash
#
# This script runs a passed in command, but first setups up the bundler caching on the repo

set -ue

export USER="root"
export LANG=C.UTF-8 LANGUAGE=C.UTF-8
echo "---- getting chef gem"
ARTIFACTORY_ENDPOINT="artifactory-internal.ps.chef.co/artifactory"
ARTIFACTORY_USERNAME="buildkite"
lita_password=$(aws ssm get-parameter --name "artifactory-lita-password" --with-decryption --query Parameter.Value --output text --region us-west-2)
ARTIFACTORY_PASSWORD=$lita_password
echo  "---- getting chef gem done"
echo "--- bundle install"

bundle config --local path vendor/bundle
bundle install --jobs=7 --retry=3

echo "+++ bundle exec task"
RUBYOPT="-W0" bundle exec $@
