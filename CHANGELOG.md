# Changelog

<!-- latest_release 19.0.99 -->
## [v19.0.99](https://github.com/chef/knife/tree/v19.0.99) (2026-03-25)

#### Merged Pull Requests
- Adding NOTICE file to the hab pkg [#64](https://github.com/chef/knife/pull/64) ([nikhil2611](https://github.com/nikhil2611))
<!-- latest_release -->

<!-- release_rollup since=18.7.9 -->
### Changes not yet released to rubygems.org

#### Features & Enhancements
- COPILOT-SETUP: Add comprehensive GitHub Copilot instructions [#33](https://github.com/chef/knife/pull/33) ([ashiqueps](https://github.com/ashiqueps)) <!-- 19.0.75 -->

#### Merged Pull Requests
- Adding NOTICE file to the hab pkg [#64](https://github.com/chef/knife/pull/64) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.99 -->
- Update Expeditor config to promote Habitat packages to current and base-2025 channels [#67](https://github.com/chef/knife/pull/67) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.98 -->
- Moving git dependency from package dep to build dep [#65](https://github.com/chef/knife/pull/65) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.97 -->
- With msi-url license should not prompt and addressed comments of previous PR - 62 [#63](https://github.com/chef/knife/pull/63) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.96 -->
- Added msi_url support and and fixed the path issue [#62](https://github.com/chef/knife/pull/62) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.95 -->
- Updating the download url&#39;s and other fixes - knife Linux hab pkg fix [#61](https://github.com/chef/knife/pull/61) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.94 -->
- Stop pulling Chef gems from Artifactory and use RubyGems instead [#60](https://github.com/chef/knife/pull/60) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.93 -->
- Removing the lint roller gemfile.lock in knife  habitat package  [#59](https://github.com/chef/knife/pull/59) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.92 -->
- Added explicit libyajl2 &gt;= 2.1 dependency to allow ffi-yajl 2.7.7 installation [#57](https://github.com/chef/knife/pull/57) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.91 -->
- Fixing argument error coming in knife bootstrap [#55](https://github.com/chef/knife/pull/55) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.90 -->
- CHEF-29680 - Update chefstyle to cookstyle with linting configuration [#46](https://github.com/chef/knife/pull/46) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.89 -->
- CHEF-29676 - Sync knife dependency updates from chef/chef after 2025-01-15 [#47](https://github.com/chef/knife/pull/47) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.88 -->
- CHEF-29678 - Sync Ruby 3.4 updates from chef/chef after 2025-01-15 [#50](https://github.com/chef/knife/pull/50) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.87 -->
- CHEF-29679 - Sync bug fixes from chef/chef after 2025-01-15 [#51](https://github.com/chef/knife/pull/51) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.86 -->
- CHEF-29675 - Sync dependabot fixes from chef/chef to standalone knife repo [#48](https://github.com/chef/knife/pull/48) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.85 -->
- Sync features  from chef/chef to standalone knife repo [#54](https://github.com/chef/knife/pull/54) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.84 -->
- updating chef and respective gems to something newer [#53](https://github.com/chef/knife/pull/53) ([sean-sype-simmons](https://github.com/sean-sype-simmons)) <!-- 19.0.83 -->
- Removed the temporary docs [#43](https://github.com/chef/knife/pull/43) ([ashiqueps](https://github.com/ashiqueps)) <!-- 19.0.82 -->
- Fixed the issue with chef-18 bootstrap [#42](https://github.com/chef/knife/pull/42) ([ashiqueps](https://github.com/ashiqueps)) <!-- 19.0.81 -->
- [CHEF-17154][CHEF-27323] Knife bootstrap: Chef infra 19 download journey [#36](https://github.com/chef/knife/pull/36) ([ashiqueps](https://github.com/ashiqueps)) <!-- 19.0.80 -->
- Moved the common folder to the home dir [#41](https://github.com/chef/knife/pull/41) ([ashiqueps](https://github.com/ashiqueps)) <!-- 19.0.79 -->
- [CHEF-27518] Knife changes to fetch plugins from chef-workstation hab pkg [#40](https://github.com/chef/knife/pull/40) ([ashiqueps](https://github.com/ashiqueps)) <!-- 19.0.78 -->
- configure dependabot [#38](https://github.com/chef/knife/pull/38) ([Vasu1105](https://github.com/Vasu1105)) <!-- 19.0.77 -->
- [CHEF-23439] - Mandatory License enforcemnt on knife bootstrap command [#32](https://github.com/chef/knife/pull/32) ([ashiqueps](https://github.com/ashiqueps)) <!-- 19.0.76 -->
- Knife version should show knife version instead of Chef Infra Client version [#21](https://github.com/chef/knife/pull/21) ([sanjain-progress](https://github.com/sanjain-progress)) <!-- 19.0.74 -->
- Bundle knife ec2 plugin  [#31](https://github.com/chef/knife/pull/31) ([sanjain-progress](https://github.com/sanjain-progress)) <!-- 19.0.73 -->
- Added base-2025-current, base-2025 and stable Channel for Promotion and RubyGems Publishing Workflow [#28](https://github.com/chef/knife/pull/28) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.72 -->
- CHEF-23696 - Add Habitat Packaging for Knife on Windows [#29](https://github.com/chef/knife/pull/29) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.71 -->
- CHEF-22814-Fixed ruby 3.1 windows pipeline and habitat test pipeline [#27](https://github.com/chef/knife/pull/27) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.70 -->
- Fixing the path to update the version on merge [#25](https://github.com/chef/knife/pull/25) ([nikhil2611](https://github.com/nikhil2611)) <!-- 19.0.69 -->
<!-- release_rollup -->

<!-- latest_stable_release -->
<!-- latest_stable_release -->