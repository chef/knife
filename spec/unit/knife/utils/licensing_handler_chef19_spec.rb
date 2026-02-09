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
require "chef/utils/licensing_handler"

describe Chef::Utils::LicensingHandler do
  let(:license_key) { "test-license-key" }
  let(:license_type) { "trial" }
  let(:handler) { described_class.new(license_key, license_type) }

  describe "#initialize" do
    it "sets license_key and license_type" do
      expect(handler.license_key).to eq(license_key)
      expect(handler.license_type).to eq(license_type)
    end
  end

  describe "#omnitruck_url" do
    context "with trial license" do
      let(:license_type) { "trial" }

      it "returns chefdownload-trial.chef.io URL with license_id parameter" do
        expected_url = "https://chefdownload-trial.chef.io/%s?license_id=#{license_key}"
        expect(handler.omnitruck_url).to eq(expected_url)
      end
    end

    context "with free license" do
      let(:license_type) { "free" }

      it "returns chefdownload-trial.chef.io URL with license_id parameter" do
        expected_url = "https://chefdownload-trial.chef.io/%s?license_id=#{license_key}"
        expect(handler.omnitruck_url).to eq(expected_url)
      end
    end

    context "with commercial license" do
      let(:license_type) { "commercial" }

      it "returns commercial download URL with license_id parameter" do
        expected_url = "https://chefdownload-commercial.chef.io/%s?license_id=#{license_key}"
        expect(handler.omnitruck_url).to eq(expected_url)
      end
    end
  end

  describe "#install_sh_url" do
    it "returns formatted URL for install.sh" do
      expected_url = handler.omnitruck_url.gsub("%s", "install.sh")
      expect(handler.install_sh_url).to eq(expected_url)
    end
  end

  describe "OMNITRUCK_URLS constant" do
    it "has correct URLs for each license type" do
      expect(described_class::OMNITRUCK_URLS["free"]).to eq("https://chefdownload-trial.chef.io")
      expect(described_class::OMNITRUCK_URLS["trial"]).to eq("https://chefdownload-trial.chef.io")
      expect(described_class::OMNITRUCK_URLS["commercial"]).to eq("https://chefdownload-commercial.chef.io")
    end
  end

  describe ".validate!" do
    let(:license_metadata) { double("license_metadata", id: "test-id", license_type: "trial") }
    let(:licenses_metadata) { double("licenses_metadata", last: license_metadata) }

    before do
      allow(ChefLicensing).to receive(:fetch_and_persist).and_return(["test-license"])
      allow(ChefLicensing::Api::Describe).to receive(:list).and_return(licenses_metadata)
    end

    it "validates license and returns handler instance" do
      result = described_class.validate!

      expect(result).to be_a(described_class)
      expect(result.license_key).to eq("test-id")
      expect(result.license_type).to eq("trial")
    end

    it "fetches licenses from licensing service" do
      expect(ChefLicensing).to receive(:fetch_and_persist).and_return(["test-license"])

      described_class.validate!
    end

    it "describes licenses with license keys" do
      expect(ChefLicensing::Api::Describe).to receive(:list).with(
        hash_including(license_keys: ["test-license"])
      )

      described_class.validate!
    end
  end

  describe ".check_software_entitlement!" do
    let(:ui) { double("ui") }

    context "when entitlement check succeeds" do
      it "calls ChefLicensing.check_software_entitlement!" do
        expect(ChefLicensing).to receive(:check_software_entitlement!)

        described_class.check_software_entitlement!(ui)
      end
    end

    context "when software is not entitled" do
      before do
        allow(ChefLicensing).to receive(:check_software_entitlement!).and_raise(ChefLicensing::SoftwareNotEntitled)
      end

      it "displays error message and exits" do
        expect(ui).to receive(:error).with("License is not entitled to use Workstation.")
        expect { described_class.check_software_entitlement!(ui) }.to raise_error(SystemExit)
      end
    end

    context "when licensing error occurs" do
      let(:licensing_error) { ChefLicensing::Error.new("Test error") }

      before do
        allow(ChefLicensing).to receive(:check_software_entitlement!).and_raise(licensing_error)
      end

      it "displays error message and exits" do
        expect(ui).to receive(:error).with("Test error")
        expect { described_class.check_software_entitlement!(ui) }.to raise_error(SystemExit)
      end
    end
  end
end
