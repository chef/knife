$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction']='Stop'

$env:HAB_BLDR_CHANNEL = "base-2025"
$env:HAB_REFRESH_CHANNEL = "base-2025"
$pkg_name = "knife"
$pkg_origin = "chef"
$pkg_version = Get-Content "$PLAN_CONTEXT/../VERSION"
$pkg_maintainer = "The Chef Maintainers <humans@chef.io>"

$pkg_deps = @(
  "core/ruby3_4-plus-devkit"
  "core/git"
)
$pkg_bin_dirs = @("bin", "vendor/bin")
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
    Set-RuntimeEnv FORCE_FFI_YAJL "ext"
    Set-RuntimeEnv LANG "en_US.UTF-8"
    Set-RuntimeEnv LC_CTYPE "en_US.UTF-8"
}

# Todo: Remove this function once the Chef gem is published with the correct name in Artifactory or rubygems.org.
function Handle-ArtifactoryChefGem {
    Write-Host "--- Handling temporary Chef gem workaround from Artifactory"

    $gem_source = "https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local"
    $downloaded_path = "$env:TEMP\chef-19.1.116-universal-unknown.gem"
    $corrected_path = "$env:TEMP\chef-19.1.116-universal-mingw-ucrt.gem"
    $cache_path = "$project_root/vendor/cache"

    Write-Host "--- Downloading Chef gem from Artifactory"
    Invoke-WebRequest -Uri "$gem_source/gems/chef-19.1.116-universal-unknown.gem" -OutFile $downloaded_path -UseBasicParsing

    Write-Host "--- Renaming gem file to correct platform"
    Rename-Item -Path $downloaded_path -NewName (Split-Path $corrected_path -Leaf)

    Write-Host "--- Moving gem to vendor/cache"
    if (!(Test-Path $cache_path)) {
        New-Item -ItemType Directory -Path $cache_path | Out-Null
    }
    Move-Item -Path $corrected_path -Destination "$cache_path/chef-19.1.116-universal-mingw-ucrt.gem" -Force
}

function Invoke-Build {
    try {
        $env:Path += ";C:\Program Files\Git\bin"
        Push-Location $project_root
        $env:GEM_HOME = "$HAB_CACHE_SRC_PATH/$pkg_dirname/vendor"

        # Add only the chef gem manually
        # Todo: Remove this function once the Chef gem is published with the correct name in Artifactory or rubygems.org.
        Handle-ArtifactoryChefGem

        Write-BuildLine " ** Configuring bundler for this build environment"
        bundle config --local without integration deploy maintenance
        bundle config --local jobs 4
        bundle config --local retry 5
        bundle config --local silence_root_warning 1

        # Lock in Windows platform and avoid remote fetching
        bundle lock --add-platform x64-mingw-ucrt
        Write-BuildLine " ** Using bundler to retrieve the Ruby dependencies"
        bundle install

        gem build knife.gemspec
        Write-BuildLine " ** Installing built gem"
        gem install knife*.gem --no-document
        Install-ChefOfficialDistribution

        Write-BuildLine " ** Cleaning up lint_roller Gemfile.lock"
        # Set GEM_HOME to ruby version directory for cleanup script to find lint_roller gem
        $env:GEM_HOME = "$HAB_CACHE_SRC_PATH/$pkg_dirname/vendor/ruby/3.4.0"
        $env:GEM_PATH = "$HAB_CACHE_SRC_PATH/$pkg_dirname/vendor"
        ruby .\scripts\cleanup_lint_roller.rb

        If ($LASTEXITCODE -ne 0) { Exit $LASTEXITCODE }
    } finally {
        Pop-Location
    }
}

function Invoke-Install {
    Write-BuildLine "** Copy built & cached gems to install directory"
    Copy-Item -Path "$HAB_CACHE_SRC_PATH/$pkg_dirname/*" -Destination $pkg_prefix -Recurse -Force -Exclude @(
        "gem_make.out", "mkmf.log", "Makefile", "*/latest", "latest", "*/JSON-Schema-Test-Suite", "JSON-Schema-Test-Suite"
    )

    try {
        Push-Location $pkg_prefix
        bundle config --local gemfile $project_root/Gemfile
        Write-BuildLine "** generating binstubs for knife"
        Invoke-Expression -Command "appbundler.bat $project_root $pkg_prefix/bin knife"
        If ($lastexitcode -ne 0) { Exit $lastexitcode }
    } finally {
        Pop-Location
    }
}

function Invoke-After {
    Remove-Item $pkg_prefix/vendor/cache -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $pkg_prefix/vendor/doc -Recurse -Force -ErrorAction SilentlyContinue

    Get-ChildItem $pkg_prefix/vendor/gems -Filter "spec" -Directory -Recurse -Depth 1 |
        Where-Object { $_.FullName -notlike "*knife*" } |
        Remove-Item -Recurse -Force

    Get-ChildItem $pkg_prefix/vendor/gems -Include @("gem_make.out", "mkmf.log", "Makefile") -File -Recurse |
        Remove-Item -Force
}

function Install-ChefOfficialDistribution {
    Write-BuildLine "Installing chef-official-distribution gem from Artifactory"

    $artifactorySource = "https://artifactory-internal.ps.chef.co/artifactory/omnibus-gems-local/"

    try {
        # Add Artifactory as gem source
        gem sources --add $artifactorySource
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to add Artifactory gem source"
        }

        # Install the gem
        gem install chef-official-distribution --no-document
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install chef-official-distribution gem"
        }

        Write-BuildLine "Successfully installed chef-official-distribution"
    }
    catch {
        Write-Error "Error installing chef-official-distribution: $_"
        exit 1
    }
    finally {
        # Always clean up gem sources
        try {
            gem sources --remove $artifactorySource
        } catch {
            # Ignore errors during cleanup
        }
    }
}