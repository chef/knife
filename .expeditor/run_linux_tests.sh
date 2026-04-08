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
			curl \
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
			curl \
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
			curl \
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
	echo "--- activating ruby/rbenv"

	local rbenv_root=""
	local home_dir="${HOME:-}"

	# Buildkite docker jobs sometimes do not set HOME to /root.
	if [ -n "$home_dir" ] && [ -d "$home_dir/.rbenv" ]; then
		rbenv_root="$home_dir/.rbenv"
	elif [ -d "/root/.rbenv" ]; then
		rbenv_root="/root/.rbenv"
	fi

	if [ -n "$rbenv_root" ]; then
		export RBENV_ROOT="$rbenv_root"
		export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"

		if command -v rbenv >/dev/null 2>&1; then
			set +e
			eval "$(rbenv init - bash)"
			set -e
		fi
	fi
}

bootstrap_ruby_if_missing() {
	if command -v ruby >/dev/null 2>&1 && command -v bundle >/dev/null 2>&1; then
		return
	fi

	echo "--- bootstrapping ruby via rbenv"
	export HOME="${HOME:-/root}"

	if [ ! -d "$HOME/.rbenv" ]; then
		if ! command -v curl >/dev/null 2>&1; then
			echo "curl is required to install rbenv"
			exit 1
		fi
		curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
	fi

	export RBENV_ROOT="$HOME/.rbenv"
	export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"

	if ! command -v rbenv >/dev/null 2>&1; then
		echo "rbenv not found after installer; PATH=$PATH"
		exit 1
	fi

	set +e
	eval "$(rbenv init - bash)"
	set -e

	local ruby_version="${RUBY_VERSION:-3.4.8}"
	rbenv install -s "$ruby_version"
	rbenv global "$ruby_version"

	if ! command -v bundle >/dev/null 2>&1; then
		gem install bundler
		rbenv rehash || true
	fi
}

install_dependencies
setup_ruby_path
bootstrap_ruby_if_missing

echo "--- ruby version"
if ! command -v ruby >/dev/null 2>&1; then
	echo "ruby not found after setup; PATH=$PATH"
	echo "HOME=${HOME:-<unset>}"
	echo "RBENV_ROOT=${RBENV_ROOT:-<unset>}"
	if [ -d "/root/.rbenv" ]; then echo "/root/.rbenv exists"; fi
	if [ -n "${HOME:-}" ] && [ -d "${HOME}/.rbenv" ]; then echo "${HOME}/.rbenv exists"; fi
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
