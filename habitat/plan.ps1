$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'

$env:HAB_BLDR_CHANNEL = "LTS-2024"
$env:HAB_REFRESH_CHANNEL = "LTS-2024"

$pkg_name = "knife"
$pkg_origin = "core"
$pkg_version = Get-Content "$PLAN_CONTEXT/../VERSION"
$pkg_maintainer = "The Chef Maintainers <humans@chef.io>"

$pkg_deps = @(
  "chef/ruby31-plus-devkit"
  "core/coreutils"
  "core/git"
  "core/bash"
)
$pkg_build_deps = @(
  "core/gcc"
  "core/make"
)
$pkg_bin_dirs = @("bin")

$project_root = (Resolve-Path "$PLAN_CONTEXT/../").Path

function pkg_version {
  Get-Content "$SRC_PATH/VERSION"
}

function Invoke-Before {
  Set-PkgVersion
}

function Invoke-SetupEnvironment {
  Push-RuntimeEnv -IsPath GEM_PATH "$pkg_prefix/vendor"
  Set-RuntimeEnv APPBUNDLER_ALLOW_RVM "true"
  Set-RuntimeEnv LANG "en_US.UTF-8"
  Set-RuntimeEnv LC_CTYPE "en_US.UTF-8"
}

function Invoke-Unpack {
  Copy-Item -Recurse -Force "$PLAN_CONTEXT/../" "$SRC_PATH/$pkg_dirname"
}

function Invoke-DownloadAndPrepareGem {
  Write-Host "--- Configuring Artifactory access"
  $env:ARTIFACTORY_ENDPOINT = "https://artifactory-internal.ps.chef.co/artifactory"
  $gem_source = "$env:ARTIFACTORY_ENDPOINT/api/gems/omnibus-gems-local"

  Write-Host "--- Downloading Chef gem from Artifactory"
  $downloaded_path = "$env:TEMP\chef-19.1.36-universal-unknown.gem"
  Invoke-WebRequest -Uri "$gem_source/gems/chef-19.1.36-universal-unknown.gem" -OutFile $downloaded_path -UseBasicParsing

  Write-Host "--- Renaming gem file to match correct platform"
  $corrected_path = "$env:TEMP\chef-19.1.36-universal-mingw-ucrt.gem"
  Rename-Item -Path $downloaded_path -NewName (Split-Path $corrected_path -Leaf)

  Write-Host "--- Moving gem to vendor/cache"
  $cache_path = "$SRC_PATH/$pkg_dirname/vendor/cache"
  if (!(Test-Path $cache_path)) { New-Item -ItemType Directory -Path $cache_path | Out-Null }
  Move-Item -Path $corrected_path -Destination "$cache_path/chef-19.1.36-universal-mingw-ucrt.gem" -Force
}

function Invoke-Build {
  Invoke-DownloadAndPrepareGem

  $env:GEM_HOME = "$HAB_CACHE_SRC_PATH/$pkg_dirname/vendor"
  $env:GEM_PATH = "$env:GEM_HOME"

  Push-Location "$SRC_PATH/$pkg_dirname"
  try {
    Write-Host "--- Configuring bundler for Windows platform"
    bundle config set --local path vendor/bundle
    bundle config set --local force_ruby_platform false
    bundle config set --local no_prune true
    bundle lock --add-platform x64-mingw-ucrt

    Write-Host "--- Installing gems from Gemfile"
    bundle install --jobs=7 --retry=3
    if ($LASTEXITCODE -ne 0) { throw "Bundle install failed with exit code $LASTEXITCODE" }

    gem build knife.gemspec
    gem install knife-*.gem --no-document
    If ($LASTEXITCODE -ne 0) { Exit $LASTEXITCODE }
  } finally {
    Pop-Location
  }
}

function Invoke-Install {
  Copy-Item -Path "$HAB_CACHE_SRC_PATH/$pkg_dirname/*" -Destination $pkg_prefix -Recurse -Force -Exclude @(
    "gem_make.out", "mkmf.log", "Makefile",
    "*/latest", "latest"
  )

  Push-Location $pkg_prefix
  try {
    bundle config --local gemfile "$project_root/Gemfile"

    Write-BuildLine "** Generating binstubs for knife using appbundler"
    Invoke-Expression -Command "appbundler.bat $project_root $pkg_prefix/bin knife"
    If ($LASTEXITCODE -ne 0) { Exit $LASTEXITCODE }
  } finally {
    Pop-Location
  }
}

function Invoke-After {
  Remove-Item "$pkg_prefix/vendor/cache" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item "$pkg_prefix/vendor/doc" -Recurse -Force -ErrorAction SilentlyContinue

  Get-ChildItem "$pkg_prefix/vendor/gems" -Filter "spec" -Directory -Recurse -Depth 1 |
    Where-Object { $_.FullName -notlike "*knife*" } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

  Get-ChildItem "$pkg_prefix/vendor/gems" -Include @("gem_make.out", "mkmf.log", "Makefile") -Recurse -File |
    Remove-Item -Force -ErrorAction SilentlyContinue
}
