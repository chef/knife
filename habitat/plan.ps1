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
)

$pkg_build_deps=@(
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

function Invoke-Build {
    try {
        $env:Path += ";C:\Program Files\Git\bin"
        Push-Location $project_root
        $env:GEM_HOME = "$HAB_CACHE_SRC_PATH/$pkg_dirname/vendor"

        Write-BuildLine " ** Configuring bundler for this build environment"
        bundle config --local without integration deploy maintenance development omnibus_package test
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
        # Set GEM_HOME for cleanup script to find lint_roller gem (Windows uses vendor/gems directly)
        $env:GEM_HOME = "$HAB_CACHE_SRC_PATH/$pkg_dirname/vendor"
        $env:GEM_PATH = "$HAB_CACHE_SRC_PATH/$pkg_dirname/vendor"
        ruby .\scripts\cleanup_lint_roller.rb

        If ($LASTEXITCODE -ne 0) { Exit $LASTEXITCODE }
    } finally {
        Pop-Location
    }
}

function Invoke-Install {

    write-output "*** invoke-install"
    $NoticeFile = "$PLAN_CONTEXT\..\NOTICE"

    if (Test-Path $NoticeFile) {
        Write-BuildLine "** Copying NOTICE to package directory"
        Copy-Item -Path $NoticeFile -Destination $pkg_prefix -Force
    } else {
        Write-BuildLine "** Warning: NOTICE not found at $NoticeFile"
    }

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

    # Remove .github directories from vendored gems to avoid CVE false positives
    Get-ChildItem $pkg_prefix/vendor/gems -Filter ".github" -Directory -Recurse `
        | Remove-Item -Recurse -Force

    Get-ChildItem $pkg_prefix/vendor/gems -Filter "spec" -Directory -Recurse -Depth 1 |
        Where-Object { $_.FullName -notlike "*knife*" } |
        Remove-Item -Recurse -Force

    Get-ChildItem $pkg_prefix/vendor/gems -Include @("gem_make.out", "mkmf.log", "Makefile") -File -Recurse |
        Remove-Item -Force
}

function Install-ChefOfficialDistribution {
    Write-BuildLine "Installing chef-official-distribution gem from Artifactory"

    # Test artifactory access and install chef-official-distribution if accessible
    Write-BuildLine "******* Testing access to artifactory *******"
    $artifactorySource = "https://artifactory-internal.ps.chef.co/artifactory/omnibus-gems-local/"

    try {
        $null = Invoke-WebRequest -Uri $artifactorySource -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-BuildLine "******* Artifactory is accessible, installing chef-official-distribution gem *******"
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

        # Verify chef-official-distribution installation
        Write-BuildLine "******* Verifying chef-official-distribution installation *******"
        gem list chef-official-distribution
        If ($lastexitcode -ne 0) {
          Exit $lastexitcode
        } else {
          Write-BuildLine "chef-official-distribution gem installed successfully"
        }
    }
    catch {
        Write-BuildLine "******* Artifactory is not accessible, skipping chef-official-distribution installation *******"
        Write-BuildLine "******* Error: $($_.Exception.Message) *******"
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
