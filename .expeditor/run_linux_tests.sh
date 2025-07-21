#!/bin/bash
#
# This script runs a passed in command, but first setups up the bundler caching on the repo

set -ue

echo "--- Current gem sources"
gem source

export USER="root"
export LANG=C.UTF-8 LANGUAGE=C.UTF-8

export ARTIFACTORY_ENDPOINT="https://artifactory-internal.ps.chef.co/artifactory"
export ARTIFACTORY_USERNAME="REDACTED@chef.io"

ruby_version=$(ruby -e 'puts RUBY_VERSION')
echo "--- Detected Ruby version: $ruby_version"

# Fix bundler double load on Ruby 3.1 by installing compatible RubyGems + Bundler
if [[ "$ruby_version" == 3.1* ]]; then
  echo "--- Installing RubyGems 3.6.9 for Ruby 3.1"
  gem install rubygems-update -v 3.6.9
  update_rubygems
fi

echo "--- Adding Artifactory gem source"
gem source -a "${ARTIFACTORY_ENDPOINT}/api/gems/omnibus-gems-local" || true

echo "--- Installing dependencies"
bundle config --local path vendor/bundle
bundle install --jobs=7 --retry=3

echo "+++ Running bundle exec task"
bundle exec $@
