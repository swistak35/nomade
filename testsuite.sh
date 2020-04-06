#!/bin/bash
export PATH="$HOME/.rbenv/shims:$PATH"
eval "$(rbenv init -)"

set -euxo pipefail
ruby_versions=( "2.4.10" "2.5.8" "2.6.6" "2.7.1" )

for ruby_version in "${ruby_versions[@]}"
do
  echo "Running tests for $ruby_version"

  rbenv shell "$ruby_version" && \
  gem install bundler && \
  bundle install && \
  QUIET_NOMADE=1 bundle exec rspec spec
done
