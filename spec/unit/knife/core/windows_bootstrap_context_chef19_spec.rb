#
# Copyright:: Copyright (c) Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "knife_spec_helper"
require "chef/knife/core/windows_bootstrap_context"

describe Chef::Knife::Core::WindowsBootstrapContext do
  let(:config) { { foo: :bar, color: true } }
  let(:run_list) { Chef::RunList.new("recipe[tmux]", "role[base]") }
  let(:chef_config) do
    {
      config_log_level: "info",
      config_log_location: "/tmp/log",
      validation_key: File.join(CHEF_SPEC_DATA, "ssl", "private_key.pem"),
      chef_server_url: "http://chef.example.com:4444",
      validation_client_name: "chef-validator-testing",
    }
  end

  let(:secret) { nil }

  subject(:bootstrap_context) { described_class.new(config, run_list, chef_config, secret) }

  describe "Chef Infra 19 licensing support" do
    describe "#msi_url" do
      context "when using chef-ice product" do
        let(:config) { { bootstrap_version: "19.0.0", channel: "stable" } }

        it "includes chef-ice in the omnitruck URL" do
          url = bootstrap_context.msi_url("2016", "x86_64")
          expect(url).to include("chef-ice/download")
        end
      end

      context "when using chef product" do
        let(:config) { { bootstrap_version: "18.0.0", channel: "stable" } }

        it "includes chef in the omnitruck URL" do
          url = bootstrap_context.msi_url("2016", "x86_64")
          expect(url).to include("chef/download")
        end
      end

      context "when using licensed download with chef-ice" do
        let(:config) do
          {
            bootstrap_version: "19.0.0",
            channel: "stable",
            license_type: "commercial",
            license_url: "https://example.com",
            license_id: "test-license",
            omnitruck_url: "https://commercial.downloads.chef.co/%s",
          }
        end

        it "uses commercial omnitruck URL with chef-ice product" do
          url = bootstrap_context.msi_url("2016", "x86_64")
          expect(url).to include("chef-ice/download")
          expect(url).to include("license_id=test-license")
        end
      end

      context "when msi_url is explicitly provided" do
        let(:config) { { msi_url: "https://custom.example.com/chef.msi" } }

        it "returns the custom MSI URL" do
          url = bootstrap_context.msi_url("2016", "x86_64")
          expect(url).to eq "https://custom.example.com/chef.msi"
        end
      end
    end

    describe "install_command with licensing" do
      let(:executor_quote) { '"' }

      context "when license is required and license_key is provided" do
        let(:config) { { bootstrap_version: "19.0.0", license_key: "test-license-key" } }

        it "includes license environment variable in install command" do
          command = bootstrap_context.send(:install_command, executor_quote)
          expect(command).to include("set CHEF_LICENSE_KEY=test-license-key")
          expect(command).to include("msiexec /qn")
        end
      end

      context "when license is required and license_id is provided" do
        let(:config) { { bootstrap_version: "19.0.0", license_id: "test-license-id" } }

        it "includes license environment variable with license_id in install command" do
          command = bootstrap_context.send(:install_command, executor_quote)
          expect(command).to include("set CHEF_LICENSE_KEY=test-license-id")
        end
      end

      context "when license is required but no license key/id provided" do
        let(:config) { { bootstrap_version: "19.0.0" } }

        it "does not include license environment variable" do
          command = bootstrap_context.send(:install_command, executor_quote)
          expect(command).not_to include("CHEF_LICENSE_KEY")
          expect(command).to include("msiexec /qn")
        end
      end

      context "when license is not required" do
        let(:config) { { bootstrap_version: "18.0.0", license_key: "test-license-key" } }

        it "does not include license environment variable even if license key provided" do
          command = bootstrap_context.send(:install_command, executor_quote)
          expect(command).not_to include("CHEF_LICENSE_KEY")
        end
      end
    end
  end
end
