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
require "chef/knife/bootstrap"
require "chef/knife/core/windows_bootstrap_context"

describe "windows-chef-client-msi.erb Chef installation verification" do
  let(:connection) { double("Train::Connection") }
  let(:knife) do
    k = Chef::Knife::Bootstrap.new(["-o", "winrm", "127.0.0.1"])
    allow(k).to receive(:connection).and_return(connection)
    allow(connection).to receive(:windows?).and_return(true)
    allow(connection).to receive(:hostname).and_return("test.example.com")
    allow(connection).to receive(:os).and_return(OpenStruct.new(family: "windows"))
    k
  end

  let(:rendered_template) { knife.render_template }

  # Chef verification logic has been removed from the template
  # The template now focuses on downloading and installing Chef without post-install verification
  
  context "installation process" do
    it "downloads the install script using PowerShell" do
      expect(rendered_template).to include("Attempting to download install script using PowerShell")
    end

    it "executes the install script" do
      expect(rendered_template).to include("Installing Chef Infra Client using PowerShell install script")
    end

    it "handles download errors with retry logic" do
      expect(rendered_template).to include("Failed PowerShell download with status code")
      expect(rendered_template).to include("Retrying download with cscript")
    end

    it "handles installation errors appropriately" do
      expect(rendered_template).to include("install script failed with status code")
    end

    it "cleans up the downloaded script after installation" do
      expect(rendered_template).to include("Clean up the downloaded script")
    end
  end

  context "with default bootstrap URL" do
    it "uses -File parameter for wget.ps1 download" do
      expect(rendered_template).to match(/powershell\.exe -ExecutionPolicy Unrestricted -InputFormat None -NoProfile -NonInteractive -File.*wget\.ps1/)
    end

    it "passes download URL as command argument" do
      expect(rendered_template).to include("%REMOTE_SOURCE_SCRIPT_URL%")
    end

    it "uses -Command parameter for install execution with parameters" do
      expect(rendered_template).to include("powershell.exe -ExecutionPolicy Unrestricted -Command")
      expect(rendered_template).to include("install -Channel")
      expect(rendered_template).to include("-Project")
      expect(rendered_template).to include("-Version")
    end
  end

  describe "custom bootstrap scenarios" do
    context "when using custom bootstrap_url with Chef ICE" do
      before do
        knife.config[:bootstrap_url] = "https://example.com/custom-install.ps1"
      end

      let(:rendered_template) { knife.render_template }

      it "still includes Chef verification logic" do
        expect(rendered_template).to include("Verifying Chef installation...")
      end

      it "checks for Habitat installation (Chef ICE default)" do
        expect(rendered_template).to include("WHERE hab")
      end
    end

    context "when using custom bootstrap_url with standard Chef" do
      before do
        knife.config[:bootstrap_url] = "https://example.com/custom-install.ps1"
        knife.config[:bootstrap_product] = "chef"
        knife.config[:bootstrap_version] = "18"
      end

      let(:rendered_template) { knife.render_template }

      it "still includes Chef verification logic" do
        expect(rendered_template).to include("Verifying Chef installation...")
        expect(rendered_template).to include("WHERE chef-client")
      end

      it "checks both standard installation locations" do
        expect(rendered_template).to include('C:\opscode\chef\bin')
        expect(rendered_template).to include('C:\chef\bin')
      end
    end
  end

  describe "integration with bootstrap workflow" do
    it "performs verification after installation completes" do
      # Verification should come after install script execution
      install_section = rendered_template.index("powershell.exe -ExecutionPolicy Unrestricted")
      verification_section = rendered_template.index("Verifying Chef installation")

      expect(verification_section).to be > install_section
    end

    it "cleans up downloaded script after verification" do
      verification_index = rendered_template.index("Verifying Chef installation")
      cleanup_index = rendered_template.index("Clean up the downloaded script")
URL scenarios" do
    context "when using custom bootstrap_url" do
      before do
        knife.config[:bootstrap_url] = "https://example.com/custom-install.ps1?signature=abc123"
      end

      let(:rendered_template) { knife.render_template }

      it "sets BOOTSTRAP_DOWNLOAD_URL environment variable with escaped percent signs" do
        expect(rendered_template).to include('set "BOOTSTRAP_DOWNLOAD_URL=')
      end

      it "uses -Command parameter for wget.ps1 with environment variable" do
        expect(rendered_template).to match(/powershell\.exe -ExecutionPolicy Unrestricted -InputFormat None -NoProfile -NonInteractive -Command "& '.*wget\.ps1' -remoteUrl \$env:BOOTSTRAP_DOWNLOAD_URL/)
      end

      it "uses -File parameter for install script execution" do
        expect(rendered_template).to include('powershell.exe -ExecutionPolicy Unrestricted -File "%LOCAL_DESTINATION_SCRIPT_PATH%"')
      end

      it "does not pass install function parameters for custom URLs" do
        # Custom URLs are executed as-is without install function invocation
        custom_section = rendered_template.split("Custom bootstrap URL").last
        expect(custom_section).not_to include("install -Channel"downloads install script before executing it" do
      download_section = rendered_template.index("Attempting to download install script")
      install_section = rendered_template.index("Installing Chef Infra Client using PowerShell")

      expect(download_section).to be < install_section
    end

    it "cleans up downloaded script after installation" do
      install_section = rendered_template.index("Installing Chef Infra Client using PowerShell")
      cleanup_index = rendered_template.index("Clean up the downloaded script")

      expect(cleanup_index).to be > install_section
    end

    it "starts chef-client after successful installation" do
      cleanup_section = rendered_template.index("Clean up the downloaded script")
      chef_run_section = rendered_template.index("Starting chef-client to bootstrap")

      expect(chef_run_section).to be > cleanup_section