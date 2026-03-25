# Package metadata
export HAB_BLDR_CHANNEL="base-2025"
export HAB_REFRESH_CHANNEL="base-2025"
ruby_pkg="core/ruby3_4"

# Ruby version for gem directory structure
# NOTE: Bundler normalizes Ruby versions to major.minor.0 format for gem compatibility.
# Even if running Ruby 3.4.2, Bundler creates ruby/3.4.0 directory structure.
# This is standard behavior - gems built for 3.4.0 are compatible with 3.4.x patch versions.
ruby_gem_version="3.4.0"

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
  core/bash
)

# Build dependencies
pkg_build_deps=(
  core/gcc
  core/make
  core/git
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
  build_line "Building the Knife gem from the gemspec with GEM_HOME=$GEM_HOME and GEM_PATH=$GEM_PATH"
  pushd "$HAB_CACHE_SRC_PATH/$pkg_dirname"
    bundle config set --local path "$GEM_HOME"
    bundle config --local without integration deploy maintenance
    bundle config --local jobs 4
    bundle config --local retry 5
    bundle config --local silence_root_warning 1
    bundle install

    gem build knife.gemspec

    # Set GEM_HOME to ruby version directory for cleanup script to find lint_roller gem
    export GEM_HOME="$pkg_prefix/vendor/ruby/${ruby_gem_version}"
    export GEM_PATH="$pkg_prefix/vendor"
    ruby ./scripts/cleanup_lint_roller.rb

  popd
}

# Install the built gem into the package directory
do_install() {

  # Copy NOTICE.TXT to the package directory
  if [[ -f "$PLAN_CONTEXT/../NOTICE" ]]; then
    build_line "Copying NOTICE to package directory"
    cp "$PLAN_CONTEXT/../NOTICE" "$pkg_prefix/"
  else
    build_line "Warning: NOTICE not found at $PLAN_CONTEXT/../NOTICE"
  fi

   export GEM_HOME="$pkg_prefix/vendor"

  build_line " do_install Setting GEM_PATH=$GEM_HOME"
  export GEM_PATH="$GEM_HOME"
   build_line "Installing the Knife gem"
    pushd "$HAB_CACHE_SRC_PATH/$pkg_dirname"
    # Install the specific knife gem version that was just built to avoid conflicts
    # Use the VERSION file from the source directory since pkg_version() uses relative path
    local knife_version=$(cat VERSION)
    gem install "knife-${knife_version}.gem" --no-document
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
export PATH="/sbin:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:$pkg_prefix/vendor/bin:\$PATH"

# Set Ruby paths defined from 'do_setup_environment()'
export GEM_HOME="$pkg_prefix/vendor/ruby/${ruby_gem_version}"
export GEM_PATH="$pkg_prefix/vendor"

export GEM_PATH="\$HOME/.hab/knife/ruby/${ruby_gem_version}:$GEM_PATH"

exec $(pkg_path_for ${ruby_pkg})/bin/ruby $real_bin \$@
EOF
  chmod -v 755 "$bin"
}

make_pkg_official_distrib() {
  build_line "Installing chef-official-distribution gem"
  gem source --add "https://artifactory-internal.ps.chef.co/artifactory/omnibus-gems-local/"
  # Install to the Bundler-created ruby gem directory structure
  gem install chef-official-distribution --no-document --install-dir "$GEM_HOME/ruby/${ruby_gem_version}"
  gem sources -r "https://artifactory-internal.ps.chef.co/artifactory/omnibus-gems-local/"
}
