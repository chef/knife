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
require "tempfile"
require "tmpdir"

describe Chef::Knife::YamlConvert do
  let(:knife) { described_class.new }
  let(:ui) { knife.ui }

  # Minimal valid YAML recipe content
  let(:valid_yaml) do
    <<~YAML
      resources:
        - type: file
          name: /tmp/hello
          action: create
    YAML
  end

  describe "#run" do
    context "when no arguments are provided" do
      it "calls ui.fatal! and exits" do
        knife.name_args = []
        expect(ui).to receive(:fatal!).with(/Please specify/).and_raise(SystemExit)
        expect { knife.run }.to raise_error(SystemExit)
      end
    end

    context "when three or more arguments are provided" do
      it "calls ui.fatal! and exits" do
        knife.name_args = %w{a b c}
        expect(ui).to receive(:fatal!).with(/knife yaml convert/).and_raise(SystemExit)
        expect { knife.run }.to raise_error(SystemExit)
      end
    end

    context "when the input YAML file does not exist" do
      it "calls ui.fatal and continues (non-bang)" do
        knife.name_args = ["/nonexistent/path/recipe.yaml"]
        allow(ui).to receive(:fatal)
        # non-bang fatal does not exit; execution continues and hits File.read
        expect { knife.run }.to raise_error(Errno::ENOENT)
        expect(ui).to have_received(:fatal).with(/does not exist or is unreadable/)
      end
    end

    context "when the output Ruby file already exists" do
      it "calls ui.fatal! and exits" do
        Dir.mktmpdir do |dir|
          yaml_path = File.join(dir, "recipe.yml")
          ruby_path = File.join(dir, "recipe.rb")
          File.write(yaml_path, valid_yaml)
          File.write(ruby_path, "# existing")
          knife.name_args = [yaml_path]
          expect(ui).to receive(:fatal!).with(/already exists/).and_raise(SystemExit)
          expect { knife.run }.to raise_error(SystemExit)
        end
      end
    end

    context "when the YAML contains multiple documents" do
      it "calls ui.fatal! and exits" do
        Dir.mktmpdir do |dir|
          yaml_path = File.join(dir, "multi.yml")
          File.write(yaml_path, "---\nresources: []\n---\nresources: []\n")
          knife.name_args = [yaml_path]
          expect(ui).to receive(:fatal!).with(/multiple documents/).and_raise(SystemExit)
          expect { knife.run }.to raise_error(SystemExit)
        end
      end
    end

    context "when the YAML is missing the top-level 'resources' key" do
      it "calls ui.fatal! and exits" do
        Dir.mktmpdir do |dir|
          yaml_path = File.join(dir, "bad.yml")
          File.write(yaml_path, "foo: bar\n")
          knife.name_args = [yaml_path]
          expect(ui).to receive(:fatal!).with(/resources/).and_raise(SystemExit)
          expect { knife.run }.to raise_error(SystemExit)
        end
      end
    end

    context "when the YAML has an empty resources list" do
      it "warns about no resources and still writes the file" do
        Dir.mktmpdir do |dir|
          yaml_path = File.join(dir, "empty.yml")
          File.write(yaml_path, "resources:\n")
          ruby_path = File.join(dir, "empty.rb")
          knife.name_args = [yaml_path]
          allow(ui).to receive(:warn)
          allow(ui).to receive(:info)
          knife.run
          expect(ui).to have_received(:warn).with(/No resources/)
          expect(File.exist?(ruby_path)).to be true
        end
      end
    end

    context "with a valid .yml file and no explicit output path" do
      it "writes a .rb file with the same base name and reports success" do
        Dir.mktmpdir do |dir|
          yaml_path = File.join(dir, "recipe.yml")
          File.write(yaml_path, valid_yaml)
          knife.name_args = [yaml_path]
          allow(ui).to receive(:info)
          knife.run
          expect(File.exist?(File.join(dir, "recipe.rb"))).to be true
          expect(ui).to have_received(:info).with(/Converted/)
        end
      end
    end

    context "with a valid .yaml extension" do
      it "derives the output filename by removing .yaml" do
        Dir.mktmpdir do |dir|
          yaml_path = File.join(dir, "recipe.yaml")
          File.write(yaml_path, valid_yaml)
          knife.name_args = [yaml_path]
          allow(ui).to receive(:info)
          knife.run
          expect(File.exist?(File.join(dir, "recipe.rb"))).to be true
        end
      end
    end

    context "with a file that has no yaml extension" do
      it "appends .rb to the filename" do
        Dir.mktmpdir do |dir|
          yaml_path = File.join(dir, "recipe")
          File.write(yaml_path, valid_yaml)
          knife.name_args = [yaml_path]
          allow(ui).to receive(:info)
          knife.run
          expect(File.exist?(File.join(dir, "recipe.rb"))).to be true
        end
      end
    end

    context "with an explicit output filename" do
      it "writes to the specified output path" do
        Dir.mktmpdir do |dir|
          yaml_path = File.join(dir, "recipe.yml")
          out_path  = File.join(dir, "custom_output.rb")
          File.write(yaml_path, valid_yaml)
          knife.name_args = [yaml_path, out_path]
          allow(ui).to receive(:info)
          knife.run
          expect(File.exist?(out_path)).to be true
        end
      end
    end

    context "output file content" do
      it "contains a header comment and resource blocks" do
        Dir.mktmpdir do |dir|
          yaml_path = File.join(dir, "recipe.yml")
          File.write(yaml_path, valid_yaml)
          knife.name_args = [yaml_path]
          allow(ui).to receive(:info)
          knife.run
          content = File.read(File.join(dir, "recipe.rb"))
          expect(content).to include("# Autoconverted recipe")
          expect(content).to include('file "/tmp/hello"')
          expect(content).to include("action")
        end
      end
    end
  end

  describe "#resource_hash_to_string" do
    it "returns a string with an autoconvert header" do
      resources = [{ "type" => "package", "name" => "vim" }]
      result = knife.resource_hash_to_string(resources, "test.yaml")
      expect(result).to include("# Autoconverted recipe from test.yaml")
    end

    it "renders each resource as a Ruby block" do
      resources = [{ "type" => "file", "name" => "/tmp/x", "action" => "create" }]
      result = knife.resource_hash_to_string(resources, "r.yaml")
      expect(result).to include('file "/tmp/x"')
      expect(result).to include("action")
    end

    it "renders multiple resources" do
      resources = [
        { "type" => "file", "name" => "/tmp/a" },
        { "type" => "package", "name" => "curl" },
      ]
      result = knife.resource_hash_to_string(resources, "r.yaml")
      expect(result).to include('file "/tmp/a"')
      expect(result).to include('package "curl"')
    end
  end
end
