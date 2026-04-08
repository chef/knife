#
# Copyright:: Copyright (c) 2009-2026 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
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

describe Chef::Knife::Bootstrap do
  let(:knife) { described_class.new }
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:stdin) { StringIO.new }

  before do
    knife.ui = Chef::Knife::UI.new(stdout, stderr, stdin, {})
    knife.name_args = ["test-node"]
  end

  describe "Chef Infra 19 licensing support" do
    describe "#fetch_license" do
      let(:bootstrap_context) { double("bootstrap_context") }
      let(:license_handler) { double("license_handler") }

      before do
        allow(Chef::Knife::Core::BootstrapContext).to receive(:new).and_return(bootstrap_context)
        allow(Chef::Utils::LicensingHandler).to receive(:validate!).and_return(license_handler)
        allow(license_handler).to receive(:install_sh_url).and_return("https://example.com/install.sh")
        allow(license_handler).to receive(:license_key).and_return("test-key")
        allow(license_handler).to receive(:omnitruck_url).and_return("https://example.com/%s")
        allow(license_handler).to receive(:license_type).and_return("trial")
      end

      context "when license is required for Chef Infra 19" do
        before do
          allow(bootstrap_context).to receive(:chef_ice?).and_return(true)
        end

        it "fetches and sets license configuration" do
          expect(ChefLicensing::Config).to receive(:require_license_for).and_yield

          knife.config[:bootstrap_version] = "19.0.0"
          knife.send(:fetch_license)

          expect(knife.config[:license_url]).to eq("https://example.com/install.sh")
          expect(knife.config[:license_id]).to eq("test-key")
          expect(knife.config[:omnitruck_url]).to eq("https://example.com/%s")
          expect(knife.config[:license_type]).to eq("trial")
        end
      end

      context "when custom bootstrap URL is provided" do
        it "skips license fetching" do
          expect(ChefLicensing::Config).not_to receive(:require_license_for)

          knife.config[:bootstrap_url] = "https://custom.example.com/install.sh"
          knife.send(:fetch_license)

          expect(knife.config[:license_url]).to be_nil
        end
      end

      context "when custom bootstrap template is provided" do
        it "skips license fetching" do
          expect(ChefLicensing::Config).not_to receive(:require_license_for)

          knife.config[:bootstrap_template] = "custom-template"
          knife.send(:fetch_license)

          expect(knife.config[:license_url]).to be_nil
        end
      end
    end

    describe "command line options" do
      it "accepts --bootstrap-product option" do
        knife.config[:bootstrap_product] = "chef-ice"
        expect(knife.config[:bootstrap_product]).to eq("chef-ice")
      end

      it "accepts --license-key option" do
        knife.config[:chef_license_key] = "test-license-key"
        expect(knife.config[:chef_license_key]).to eq("test-license-key")
      end

      it "accepts --license-url option" do
        knife.config[:chef_license_server] = "https://example.com/license"
        expect(knife.config[:chef_license_server]).to eq("https://example.com/license")
      end
    end

    describe "option descriptions" do
      let(:bootstrap_product_option) { knife.class.options[:bootstrap_product] }
      let(:license_key_option) { knife.class.options[:chef_license_key] }
      let(:license_url_option) { knife.class.options[:chef_license_server] }

      it "has proper description for bootstrap_product" do
        expect(bootstrap_product_option[:description]).to include("Product")
      end

      it "has proper description for license_key" do
        expect(license_key_option[:description]).to include("Chef License key")
      end

      it "has proper description for license_url" do
        expect(license_url_option[:description]).to include("Chef License server")
      end
    end
  end
end
