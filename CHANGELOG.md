# Changelog

<!-- latest_release 19.0.109 -->
## [v19.0.109](https://github.com/chef/knife/tree/v19.0.109) (2026-04-13)

#### Merged Pull Requests
- Move habitat-test to public [#84](https://github.com/chef/knife/pull/84) ([tpowell-progress](https://github.com/tpowell-progress))
<!-- latest_release -->

<!-- release_rollup since=19.0.105 -->
### Changes not yet released to rubygems.org

#### Merged Pull Requests
- Move habitat-test to public [#84](https://github.com/chef/knife/pull/84) ([tpowell-progress](https://github.com/tpowell-progress)) <!-- 19.0.109 -->
- Bump crack from 0.4.5 to 1.0.1 [#80](https://github.com/chef/knife/pull/80) ([dependabot[bot]](https://github.com/dependabot[bot])) <!-- 19.0.108 -->
- Update highline requirement from &gt;= 1.6.9, &lt; 3 to &gt;= 1.6.9, &lt; 4 [#79](https://github.com/chef/knife/pull/79) ([dependabot[bot]](https://github.com/dependabot[bot])) <!-- 19.0.107 -->
- Bump streetsidesoftware/cspell-action from 8.3.0 to 8.4.0 [#78](https://github.com/chef/knife/pull/78) ([dependabot[bot]](https://github.com/dependabot[bot])) <!-- 19.0.106 -->
<!-- release_rollup -->

<!-- latest_stable_release -->
## [v19.0.105](https://github.com/chef/knife/tree/v19.0.105) (2026-04-08)

#### Merged Pull Requests
- Tweaking docs [#72](https://github.com/chef/knife/pull/72) ([johnmccrae](https://github.com/johnmccrae))
- First pass at making this repo work [#74](https://github.com/chef/knife/pull/74) ([jaymzh](https://github.com/jaymzh))
- Updated Repo urls in gemspec and Added Copyright [#76](https://github.com/chef/knife/pull/76) ([ashiqueps](https://github.com/ashiqueps))
<!-- latest_stable_release -->

## [v19.0.102](https://github.com/chef/knife/tree/v19.0.102) (2026-04-07)

#### Features & Enhancements
- COPILOT-SETUP: Add comprehensive GitHub Copilot instructions [#33](https://github.com/chef/knife/pull/33) ([ashiqueps](https://github.com/ashiqueps))

#### Merged Pull Requests
- Fixing the path to update the version on merge [#25](https://github.com/chef/knife/pull/25) ([nikhil2611](https://github.com/nikhil2611))
- CHEF-22814-Fixed ruby 3.1 windows pipeline and habitat test pipeline [#27](https://github.com/chef/knife/pull/27) ([nikhil2611](https://github.com/nikhil2611))
- CHEF-23696 - Add Habitat Packaging for Knife on Windows [#29](https://github.com/chef/knife/pull/29) ([nikhil2611](https://github.com/nikhil2611))
- Added base-2025-current, base-2025 and stable Channel for Promotion and RubyGems Publishing Workflow [#28](https://github.com/chef/knife/pull/28) ([nikhil2611](https://github.com/nikhil2611))
- Bundle knife ec2 plugin  [#31](https://github.com/chef/knife/pull/31) ([sanjain-progress](https://github.com/sanjain-progress))
- Knife version should show knife version instead of Chef Infra Client version [#21](https://github.com/chef/knife/pull/21) ([sanjain-progress](https://github.com/sanjain-progress))
- [CHEF-23439] - Mandatory License enforcemnt on knife bootstrap command [#32](https://github.com/chef/knife/pull/32) ([ashiqueps](https://github.com/ashiqueps))
- configure dependabot [#38](https://github.com/chef/knife/pull/38) ([Vasu1105](https://github.com/Vasu1105))
- [CHEF-27518] Knife changes to fetch plugins from chef-workstation hab pkg [#40](https://github.com/chef/knife/pull/40) ([ashiqueps](https://github.com/ashiqueps))
- Moved the common folder to the home dir [#41](https://github.com/chef/knife/pull/41) ([ashiqueps](https://github.com/ashiqueps))
- [CHEF-17154][CHEF-27323] Knife bootstrap: Chef infra 19 download journey [#36](https://github.com/chef/knife/pull/36) ([ashiqueps](https://github.com/ashiqueps))
- Fixed the issue with chef-18 bootstrap [#42](https://github.com/chef/knife/pull/42) ([ashiqueps](https://github.com/ashiqueps))
- Removed the temporary docs [#43](https://github.com/chef/knife/pull/43) ([ashiqueps](https://github.com/ashiqueps))
- updating chef and respective gems to something newer [#53](https://github.com/chef/knife/pull/53) ([sean-sype-simmons](https://github.com/sean-sype-simmons))
- Sync features  from chef/chef to standalone knife repo [#54](https://github.com/chef/knife/pull/54) ([nikhil2611](https://github.com/nikhil2611))
- CHEF-29675 - Sync dependabot fixes from chef/chef to standalone knife repo [#48](https://github.com/chef/knife/pull/48) ([nikhil2611](https://github.com/nikhil2611))
- CHEF-29679 - Sync bug fixes from chef/chef after 2025-01-15 [#51](https://github.com/chef/knife/pull/51) ([nikhil2611](https://github.com/nikhil2611))
- CHEF-29678 - Sync Ruby 3.4 updates from chef/chef after 2025-01-15 [#50](https://github.com/chef/knife/pull/50) ([nikhil2611](https://github.com/nikhil2611))
- CHEF-29676 - Sync knife dependency updates from chef/chef after 2025-01-15 [#47](https://github.com/chef/knife/pull/47) ([nikhil2611](https://github.com/nikhil2611))
- CHEF-29680 - Update chefstyle to cookstyle with linting configuration [#46](https://github.com/chef/knife/pull/46) ([nikhil2611](https://github.com/nikhil2611))
- Fixing argument error coming in knife bootstrap [#55](https://github.com/chef/knife/pull/55) ([nikhil2611](https://github.com/nikhil2611))
- Added explicit libyajl2 &gt;= 2.1 dependency to allow ffi-yajl 2.7.7 installation [#57](https://github.com/chef/knife/pull/57) ([nikhil2611](https://github.com/nikhil2611))
- Removing the lint roller gemfile.lock in knife  habitat package  [#59](https://github.com/chef/knife/pull/59) ([nikhil2611](https://github.com/nikhil2611))
- Stop pulling Chef gems from Artifactory and use RubyGems instead [#60](https://github.com/chef/knife/pull/60) ([nikhil2611](https://github.com/nikhil2611))
- Updating the download url&#39;s and other fixes - knife Linux hab pkg fix [#61](https://github.com/chef/knife/pull/61) ([nikhil2611](https://github.com/nikhil2611))
- Added msi_url support and and fixed the path issue [#62](https://github.com/chef/knife/pull/62) ([nikhil2611](https://github.com/nikhil2611))
- With msi-url license should not prompt and addressed comments of previous PR - 62 [#63](https://github.com/chef/knife/pull/63) ([nikhil2611](https://github.com/nikhil2611))
- Moving git dependency from package dep to build dep [#65](https://github.com/chef/knife/pull/65) ([nikhil2611](https://github.com/nikhil2611))
- Update Expeditor config to promote Habitat packages to current and base-2025 channels [#67](https://github.com/chef/knife/pull/67) ([nikhil2611](https://github.com/nikhil2611))
- Adding NOTICE file to the hab pkg [#64](https://github.com/chef/knife/pull/64) ([nikhil2611](https://github.com/nikhil2611))
- [CHEF-33284] Fix spurious SERVER COMMANDS in knife --help [#71](https://github.com/chef/knife/pull/71) ([ashiqueps](https://github.com/ashiqueps))
- Revert &quot;[CHEF-33284] Fix spurious SERVER COMMANDS in knife --help&quot; [#75](https://github.com/chef/knife/pull/75) ([ashiqueps](https://github.com/ashiqueps))
-  Update config for knife gem release [#70](https://github.com/chef/knife/pull/70) ([nikhil2611](https://github.com/nikhil2611))