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

  context "with Chef ICE (default for version 19+)" do
    describe "Chef installation verification logic" do
      it "includes Chef installation verification section" do
        expect(rendered_template).to include("Verifying Chef installation...")
      end

      it "checks for Habitat installation" do
        expect(rendered_template).to include("WHERE hab")
      end

      it "verifies Habitat at C:\\hab\\bin" do
        expect(rendered_template).to include('C:\hab\bin\hab.exe')
      end

      it "adds Habitat directory to PATH when found" do
        expect(rendered_template).to include('SET "PATH=C:\hab\bin;%PATH%"')
      end

      it "tests chef-client command execution via hab pkg exec" do
        expect(rendered_template).to include("hab pkg exec chef/chef-infra-client chef-client --version")
      end

      it "shows success message when Chef ICE is verified" do
        expect(rendered_template).to include("Chef ICE is successfully installed and verified")
      end

      it "displays error if Habitat is not found and exits" do
        expect(rendered_template).to include("Error: Habitat installation not found")
        expect(rendered_template).to include("Chef ICE requires Habitat to be installed")
      end
    end
  end

  context "with standard Chef installation" do
    before do
      # Force standard Chef by explicitly setting the product
      knife.config[:bootstrap_product] = "chef"
      knife.config[:bootstrap_version] = "18"
    end

    describe "Chef installation verification logic" do
      it "includes Chef installation verification section" do
        expect(rendered_template).to include("Verifying Chef installation...")
      end

      it "checks for chef-client in PATH first" do
        expect(rendered_template).to include("WHERE chef-client")
      end

      it "checks standard Chef installation location C:\\opscode\\chef\\bin" do
        expect(rendered_template).to include('C:\opscode\chef\bin\chef-client')
      end

      it "checks alternate Chef installation location C:\\chef\\bin" do
        expect(rendered_template).to include('C:\chef\bin\chef-client')
      end

      it "tests chef-client command execution after finding it" do
        expect(rendered_template).to include("CHEF_CLIENT_PATH!\" --version")
      end

      it "displays error and exits if chef-client is not found" do
        # Should have error message for not found
        expect(rendered_template).to include("Error: chef-client installation not found in any standard location")
        expect(rendered_template).to include("Checked locations:")
      end

      it "shows success message when chef-client is found" do
        expect(rendered_template).to include("chef-client is successfully installed and verified")
      end

      it "tracks CHEF_FOUND variable to determine if Chef was located" do
        expect(rendered_template).to match(/CHEF_FOUND.*=.*0/)
        expect(rendered_template).to match(/CHEF_FOUND.*=.*1/)
      end

      it "provides helpful guidance when chef-client cannot be executed" do
        expect(rendered_template).to include("found but failed to execute")
        expect(rendered_template).to include("This may indicate a corrupted installation")
      end

      it "distinguishes between chef-client not found vs not executable" do
        expect(rendered_template).to include("installation not found")
        expect(rendered_template).to include("found but failed to execute")
      end
    end

    describe "PATH manipulation" do
      it "adds both bin and embedded\\bin directories to PATH at bootstrap" do
        # The PATH is set at the end before running chef-client
        expect(rendered_template).to include('opscode\chef\bin')
        expect(rendered_template).to include('opscode\chef\embedded\bin')
      end

      it "prepends Chef directories to existing PATH" do
        expect(rendered_template).to include(';%PATH%"')
      end
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

      expect(cleanup_index).to be > verification_index
    end
  end
end
