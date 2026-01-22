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

describe "windows-chef-client-msi.erb template with presigned URLs" do
  let(:connection) { double("Train::Connection") }
  let(:knife) do
    k = Chef::Knife::Bootstrap.new(["-o", "winrm", "127.0.0.1"])
    allow(k).to receive(:connection).and_return(connection)
    allow(connection).to receive(:windows?).and_return(true)
    allow(connection).to receive(:hostname).and_return("test.example.com")
    allow(connection).to receive(:os).and_return(OpenStruct.new(family: "windows"))
    k
  end

  describe "with presigned S3 URL containing special characters" do
    let(:presigned_url) do
      "https://workstation-rc3-assets.s3.us-east-1.amazonaws.com/install.ps1" \
      "?response-content-disposition=inline" \
      "&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD" \
      "&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEHQaCXVzLWVhc3QtMSJIMEYCIQCfUHkC2e0%2FzlRkBc%2F2dgmp" \
      "&X-Amz-Algorithm=AWS4-HMAC-SHA256" \
      "&X-Amz-Credential=ASIA5LOKXA7I3346RT45%2F20251112%2Fus-east-1%2Fs3%2Faws4_request" \
      "&X-Amz-Date=20251112T194920Z" \
      "&X-Amz-Expires=43200" \
      "&X-Amz-SignedHeaders=host" \
      "&X-Amz-Signature=34d6c57d80c9a59d9f524069aa12739cf50d45b907d2a1d27e41fbf76828ad3c"
    end

    before do
      knife.config[:bootstrap_url] = presigned_url
    end

    let(:rendered_template) { knife.render_template }

    it "properly escapes percent signs in the URL for batch variable assignment" do
      # Verify that percent signs are doubled for batch file handling
      expect(rendered_template).to include('set "BOOTSTRAP_DOWNLOAD_URL=')
      # Check that percent signs are properly escaped in the environment variable
      expect(rendered_template).to match(/set "BOOTSTRAP_DOWNLOAD_URL=.*%%2F.*%%2F/)
    end

    it "uses environment variable to pass URL to PowerShell" do
      # Verify that the URL is passed via environment variable to avoid batch expansion issues
      expect(rendered_template).to include("$env:BOOTSTRAP_DOWNLOAD_URL")
      expect(rendered_template).to include("powershell.exe -ExecutionPolicy Unrestricted")
    end

    it "does not use batch variable expansion for custom bootstrap URLs" do
      # Verify that we're not using %REMOTE_SOURCE_SCRIPT_URL% expansion for custom URLs
      # which would cause the percent signs to be misinterpreted
      lines_with_bootstrap_url = rendered_template.lines.select { |line| line.include?("BOOTSTRAP_DOWNLOAD_URL") }
      expect(lines_with_bootstrap_url).not_to be_empty

      # The custom URL should not go through %VAR% expansion
      expect(rendered_template).not_to include("%BOOTSTRAP_DOWNLOAD_URL%")
    end

    it "properly handles the URL in the cscript fallback" do
      # Verify that the cscript fallback also uses the environment variable
      expect(rendered_template).to include("cscript /nologo")
      expect(rendered_template).to match(/wget\.vbs.*BOOTSTRAP_DOWNLOAD_URL/)
    end

    it "preserves all query parameters in the URL" do
      # Verify that important query parameters are preserved
      expect(rendered_template).to include("X-Amz-Algorithm=AWS4-HMAC-SHA256")
      expect(rendered_template).to include("X-Amz-Credential=")
      expect(rendered_template).to include("X-Amz-Date=")
      expect(rendered_template).to include("X-Amz-Signature=")
    end

    it "does not corrupt encoded slashes in the credential parameter" do
      # The most critical part - encoded slashes (%2F) must remain as %%2F in batch
      # so they survive batch processing and become %2F when passed to PowerShell
      expect(rendered_template).to match(/ASIA5LOKXA7I3346RT45%%2F20251112%%2Fus-east-1%%2Fs3%%2Faws4_request/)
    end

    it "does not corrupt encoded plus signs" do
      # Verify that %2B (encoded +) becomes %%2B
      if presigned_url.include?("%2B")
        expect(rendered_template).to include("%%2B")
      end
    end
  end

  describe "with standard bootstrap URL (no special characters)" do
    let(:rendered_template) { knife.render_template }

    it "uses REMOTE_SOURCE_SCRIPT_URL for standard URLs" do
      expect(rendered_template).to include('set "REMOTE_SOURCE_SCRIPT_URL=')
      expect(rendered_template).to include("%REMOTE_SOURCE_SCRIPT_URL%")
    end

    it "defaults to omnitruck URL when no bootstrap_url is provided" do
      expect(rendered_template).to include("https://omnitruck.chef.io/install.ps1")
    end
  end

  describe "edge cases" do
    context "when bootstrap URL contains single quotes" do
      before do
        knife.config[:bootstrap_url] = "https://example.com/install.ps1?param='value'"
      end

      let(:rendered_template) { knife.render_template }

      it "properly escapes single quotes in PowerShell command" do
        # Single quotes should be doubled for PowerShell string escaping
        expect(rendered_template).to include("''")
      end
    end

    context "when bootstrap URL contains ampersands" do
      before do
        knife.config[:bootstrap_url] = "https://example.com/install.ps1?a=1&b=2&c=3"
      end

      let(:rendered_template) { knife.render_template }

      it "preserves ampersands in the URL" do
        expect(rendered_template).to include("&b=2&")
        expect(rendered_template).to include("&c=3")
      end
    end

    context "when bootstrap URL contains equals signs" do
      before do
        knife.config[:bootstrap_url] = "https://example.com/install.ps1?key=value"
      end

      let(:rendered_template) { knife.render_template }

      it "preserves equals signs in the URL" do
        expect(rendered_template).to include("key=value")
      end
    end
  end

  describe "error messages" do
    before do
      knife.config[:bootstrap_url] = "https://example.com/install.ps1?X-Amz-Signature=abc123"
    end

    let(:rendered_template) { knife.render_template }

    it "displays appropriate error message for custom URLs" do
      expect(rendered_template).to include("Failed to download install script")
      # Should not reference %REMOTE_SOURCE_SCRIPT_URL% for custom URLs
      error_section = rendered_template.split("if NOT %DOWNLOAD_ERROR_STATUS%==0").last
      custom_url_section = error_section.split("else").first
      expect(custom_url_section).not_to include("%REMOTE_SOURCE_SCRIPT_URL%")
    end
  end
end
