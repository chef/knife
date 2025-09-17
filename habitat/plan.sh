# Package metadata
export HAB_BLDR_CHANNEL="base-2025"
export HAB_REFRESH_CHANNEL="base-2025"
ruby_pkg="core/ruby3_4"
pkg_name="knife"
pkg_origin="chef"
pkg_description="knife is a command-line tool that provides an interface between a local chef-repo and the Chef Infra Server."
pkg_upstream_url=https://www.chef.io/
pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"
pkg_license=('Apache-2.0')

# Package dependencies
pkg_deps=(
  ${ruby_pkg}
  core/coreutils
  core/git
  core/bash
)

# Build dependencies
pkg_build_deps=(
  core/gcc
  core/make
)

pkg_version() {
  cat "../VERSION"
}

do_before() {
  update_pkg_version
}

# Directories that contain executable binaries
pkg_bin_dirs=(bin)
pkg_svc_user=root

# Setup environment variables required for building the package
do_setup_environment() {
  build_line 'Setting GEM_HOME="$pkg_prefix/vendor"'
  export GEM_HOME="$pkg_prefix/vendor"

  build_line "Setting GEM_PATH=$GEM_HOME"
  export GEM_PATH="$GEM_HOME"
}

# Unpack the source code into the Habitat cache path
do_unpack() {
  mkdir -pv "$HAB_CACHE_SRC_PATH/$pkg_dirname"
  cp -RT "$PLAN_CONTEXT"/.. "$HAB_CACHE_SRC_PATH/$pkg_dirname/"
}

# Build the Knife gem from its specification file
do_build() {
  export GEM_HOME="$pkg_prefix/vendor"
  export GEM_PATH="$GEM_HOME"
  build_line "Building the Knife gem from the gemspec"

  pushd "$HAB_CACHE_SRC_PATH/$pkg_dirname"
    bundle config set --local path "$GEM_HOME"
    bundle install --jobs=4 --retry=5

    gem build knife.gemspec

  popd
  # This will be removed once the custom branch is merged upstream
  build_chef_licensing
}

# Install the built gem into the package directory
do_install() {
  build_line "Installing the Knife gem"
  pushd "$HAB_CACHE_SRC_PATH/$pkg_dirname"
    gem install knife-*.gem --no-document --install-dir "$GEM_HOME"
  popd

  make_pkg_official_distrib
  wrap_ruby_knife
  set_runtime_env "GEM_PATH" "${pkg_prefix}/vendor"
}

wrap_ruby_knife() {
  local bin="$pkg_prefix/bin/$pkg_name"
  local real_bin="$GEM_HOME/gems/knife-${pkg_version}/bin/knife"
  wrap_bin_with_ruby "$bin" "$real_bin"
}

wrap_bin_with_ruby() {
  local bin="$1"
  local real_bin="$2"
  build_line "Adding wrapper $bin to $real_bin"
  cat <<EOF > "$bin"
#!$(pkg_path_for core/bash)/bin/bash
set -e
# Set binary path that allows knife and chef to find correct binaries
export PATH="/sbin:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:\$PATH"
# Set Ruby gem paths to include the chef gem
export GEM_HOME="$pkg_prefix/vendor/ruby/3.4.0"
export GEM_PATH="\$GEM_HOME"
exec $(pkg_path_for ${ruby_pkg})/bin/ruby $real_bin \$@
EOF
  chmod -v 755 "$bin"
}

build_chef_licensing() {
  build_line "Building chef-licensing gem from custom branch"
  git clone --depth 1 --branch nm/introducing-optional-mode https://github.com/chef/chef-licensing.git /tmp/chef-licensing
  pushd /tmp/chef-licensing/components/ruby
    gem build chef-licensing.gemspec
    gem install chef-licensing-*.gem --no-document --install-dir "$GEM_HOME/ruby/3.4.0"
  popd
  rm -rf /tmp/chef-licensing
}

make_pkg_official_distrib() {
  build_line "Installing chef-official-distribution gem"
  gem source --add "https://artifactory-internal.ps.chef.co/artifactory/omnibus-gems-local/"
  gem install chef-official-distribution --no-document --install-dir "$GEM_HOME/ruby/3.4.0"
  gem sources -r "https://artifactory-internal.ps.chef.co/artifactory/omnibus-gems-local/"
}
