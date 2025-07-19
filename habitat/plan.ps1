$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction']='Stop'

$env:HAB_BLDR_CHANNEL = "base-2025"
$env:HAB_REFRESH_CHANNEL = "base-2025"
$pkg_name="knife"
$pkg_origin="chef"
$pkg_version=$(Get-Content "$PLAN_CONTEXT/../VERSION")
$pkg_maintainer="The Chef Maintainers <humans@chef.io>"

$pkg_deps=@(
  "core/ruby3_4-plus-devkit"
  "core/git"
)
$pkg_bin_dirs=@("bin"
                "vendor/bin")
$project_root= (Resolve-Path "$PLAN_CONTEXT/../").Path

function pkg_version {
    Get-Content "$SRC_PATH/VERSION"
}

function Invoke-Before {
    Set-PkgVersion
}
function Invoke-SetupEnvironment {
    Push-RuntimeEnv -IsPath GEM_PATH "$pkg_prefix/vendor"

    Set-RuntimeEnv APPBUNDLER_ALLOW_RVM "true" # prevent appbundler from clearing out the carefully constructed runtime GEM_PATH
    Set-RuntimeEnv FORCE_FFI_YAJL "ext"
    Set-RuntimeEnv LANG "en_US.UTF-8"
    Set-RuntimeEnv LC_CTYPE "en_US.UTF-8"
}

function Handle-ArtifactoryChefGem {
    Write-Host "--- Handling temporary Chef gem workaround from Artifactory"

    $env:ARTIFACTORY_ENDPOINT = "https://artifactory-internal.ps.chef.co/artifactory"
    $env:ARTIFACTORY_USERNAME = "REDACTED@chef.io"
    $gem_source = "$env:ARTIFACTORY_ENDPOINT/api/gems/omnibus-gems-local"

    $downloaded_path = "$env:TEMP\chef-19.1.36-universal-unknown.gem"
    $corrected_path = "$env:TEMP\chef-19.1.36-universal-mingw-ucrt.gem"
    $cache_path = "$project_root/vendor/cache"

    Write-Host "--- Downloading Chef gem from Artifactory"
    Invoke-WebRequest -Uri "$gem_source/gems/chef-19.1.36-universal-unknown.gem" -OutFile $downloaded_path -UseBasicParsing

    Write-Host "--- Renaming gem file to correct platform"
    Rename-Item -Path $downloaded_path -NewName (Split-Path $corrected_path -Leaf)

    Write-Host "--- Ensuring vendor/cache exists and moving gem"
    if (!(Test-Path $cache_path)) {
        New-Item -ItemType Directory -Path $cache_path | Out-Null
    }
    Move-Item -Path $corrected_path -Destination "$cache_path/chef-19.1.36-universal-mingw-ucrt.gem" -Force
}

function Invoke-Build {
    try {
        $env:Path += ";c:\\Program Files\\Git\\bin"
        Push-Location $project_root
        $env:GEM_HOME = "$HAB_CACHE_SRC_PATH/$pkg_dirname/vendor"

        # TEMP: Inject Chef gem manually until Rubygems.org version is fixed
        Handle-ArtifactoryChefGem

        Write-BuildLine " ** Configuring bundler for this build environment"
        bundle config --local without integration deploy maintenance
        bundle config set --local path vendor/bundle
        bundle config set --local force_ruby_platform false
        bundle config set --local no_prune true
        bundle config set --local jobs 4
        bundle config set --local retry 5
        bundle config set --local silence_root_warning 1
        bundle lock --add-platform x64-mingw-ucrt
        Write-BuildLine " ** Using bundler to retrieve the Ruby dependencies"
        bundle install

        gem build knife.gemspec
	    Write-BuildLine " ** Using gem to  install"
	    gem install knife*.gem --no-document

        If ($lastexitcode -ne 0) { Exit $lastexitcode }
    } finally {
        Pop-Location
    }
}

function Invoke-Install {
    Write-BuildLine "** Copy built & cached gems to install directory"
    Copy-Item -Path "$HAB_CACHE_SRC_PATH/$pkg_dirname/*" -Destination $pkg_prefix -Recurse -Force -Exclude @("gem_make.out", "mkmf.log", "Makefile",
                     "*/latest", "latest",
                     "*/JSON-Schema-Test-Suite", "JSON-Schema-Test-Suite")

    try {
        Push-Location $pkg_prefix
        bundle config --local gemfile $project_root/Gemfile
         Write-BuildLine "** generating binstubs for knife with precise version pins"
	 Write-BuildLine "** generating binstubs for knife with precise version pins $project_root $pkg_prefix/bin " 
            Invoke-Expression -Command "appbundler.bat $project_root $pkg_prefix/bin knife"
            If ($lastexitcode -ne 0) { Exit $lastexitcode }
	Write-BuildLine " ** Running the knife project's 'rake install' to install the path-based gems so they look like any other installed gem."

        If ($lastexitcode -ne 0) { Exit $lastexitcode }
    } finally {
        Pop-Location
    }
}

function Invoke-After {
    # We don't need the cache of downloaded .gem files ...
    Remove-Item $pkg_prefix/vendor/cache -Recurse -Force
    # We don't need the gem docs.
    Remove-Item $pkg_prefix/vendor/doc -Recurse -Force
    # We don't need to ship the test suites for every gem dependency,
    # only inspec's for package verification.
    Get-ChildItem $pkg_prefix/vendor/gems -Filter "spec" -Directory -Recurse -Depth 1 `
        | Where-Object -FilterScript { $_.FullName -notlike "*knife*" }             `
        | Remove-Item -Recurse -Force
    # Remove the byproducts of compiling gems with extensions
    Get-ChildItem $pkg_prefix/vendor/gems -Include @("gem_make.out", "mkmf.log", "Makefile") -File -Recurse `
        | Remove-Item -Force
}