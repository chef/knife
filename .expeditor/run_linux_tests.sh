#!/bin/bash
#
# This script runs a passed in command, but first setups up the bundler caching on the repo

set -ue

export USER="root"
export LANG=C.UTF-8 LANGUAGE=C.UTF-8

install_dependencies() {
	if command -v apt-get >/dev/null 2>&1; then
		echo "--- installing native dependencies via apt-get"
		apt-get update -y
		DEBIAN_FRONTEND=noninteractive apt-get install -y \
			build-essential \
			git \
			libarchive-dev \
			libffi-dev \
			libssl-dev \
			libyaml-dev \
			pkg-config \
			zlib1g-dev
	elif command -v dnf >/dev/null 2>&1; then
		echo "--- installing native dependencies via dnf"
		dnf clean metadata
		if [ -r /etc/os-release ]; then
			. /etc/os-release
		fi

		DNF_OPTS="-y"
		if [ "${ID:-}" = "rocky" ] && dnf repolist all 2>/dev/null | grep -q '^devel'; then
			DNF_OPTS="$DNF_OPTS --enablerepo=devel"
		fi

		dnf install $DNF_OPTS \
			gcc \
			gcc-c++ \
			git \
			libarchive-devel \
			libffi-devel \
			libyaml-devel \
			make \
			openssl-devel \
			readline-devel \
			zlib-devel
	elif command -v yum >/dev/null 2>&1; then
		echo "--- installing native dependencies via yum"
		yum install -y \
			gcc \
			gcc-c++ \
			git \
			libarchive-devel \
			libffi-devel \
			libyaml-devel \
			make \
			openssl-devel \
			readline-devel \
			zlib-devel
	else
		echo "--- no supported package manager found; continuing without dependency installation"
	fi
}

setup_ruby_path() {
	if command -v ruby >/dev/null 2>&1 && command -v bundle >/dev/null 2>&1; then
		return
	fi

	if [ -d "$HOME/.rbenv" ]; then
		echo "--- attempting rbenv ruby activation"
		export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"

		if command -v rbenv >/dev/null 2>&1; then
			eval "$(rbenv init - bash --no-rehash)" || true

			if ! command -v ruby >/dev/null 2>&1; then
				if [ -n "${RUBY_VERSION:-}" ] && rbenv versions --bare | grep -qx "$RUBY_VERSION"; then
					rbenv global "$RUBY_VERSION"
				elif rbenv versions --bare | grep -q .; then
					rbenv global "$(rbenv versions --bare | tail -n 1)"
				fi
			fi
		fi
	fi

	if ! command -v ruby >/dev/null 2>&1; then
		for candidate in /opt/chef/bin /opt/chef/embedded/bin /opt/chef-workstation/embedded/bin; do
			if [ -x "$candidate/ruby" ]; then
				export PATH="$candidate:$PATH"
				break
			fi
		done
	fi
}

install_dependencies
setup_ruby_path

echo "--- ruby version"
if ! command -v ruby >/dev/null 2>&1; then
	echo "ruby not found after setup; PATH=$PATH"
	exit 1
fi
ruby --version

if ! command -v bundle >/dev/null 2>&1; then
	echo "bundle not found after setup; PATH=$PATH"
	exit 1
fi

echo "--- bundle install"

bundle config --local path vendor/bundle
bundle install --jobs=7 --retry=3

echo "+++ bundle exec task"
bundle exec $@
