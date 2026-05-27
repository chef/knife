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
require "chef/knife/ssh_progress_bar"

describe Chef::Knife::SshProgressBar do
  let(:output) { StringIO.new }

  before do
    allow(output).to receive(:tty?).and_return(true)
    allow(IO).to receive(:console).and_return(double(winsize: [24, 80]))
  end

  describe "#initialize" do
    it "sets total and starts at zero completed" do
      bar = described_class.new(10, output: output)
      expect(bar.total).to eq(10)
      expect(bar.completed).to eq(0)
      expect(bar.failed).to eq(0)
    end

    it "renders the initial bar when output is a TTY" do
      described_class.new(5, output: output)
      expect(output.string).to include("0/5")
    end

    it "does not render when output is not a TTY" do
      allow(output).to receive(:tty?).and_return(false)
      described_class.new(5, output: output)
      expect(output.string).to be_empty
    end
  end

  describe "#increment" do
    it "increments the completed count" do
      bar = described_class.new(10, output: output)
      bar.increment
      expect(bar.completed).to eq(1)
    end

    it "updates the rendered output" do
      bar = described_class.new(10, output: output)
      bar.increment
      expect(output.string).to include("1/10")
    end

    it "can increment to total" do
      bar = described_class.new(3, output: output)
      3.times { bar.increment }
      expect(bar.completed).to eq(3)
      expect(output.string).to include("3/3")
      expect(output.string).to include("100.0%")
    end
  end

  describe "#increment_failed" do
    it "increments both failed and completed counts" do
      bar = described_class.new(10, output: output)
      bar.increment_failed
      expect(bar.completed).to eq(1)
      expect(bar.failed).to eq(1)
    end

    it "shows failed count in output" do
      bar = described_class.new(10, output: output)
      bar.increment_failed
      expect(output.string).to include("1 failed")
    end
  end

  describe "#finish" do
    it "prints a completion summary" do
      bar = described_class.new(3, output: output)
      3.times { bar.increment }
      bar.finish
      expect(output.string).to include("3/3 nodes completed")
    end

    it "includes failed count in summary when there are failures" do
      bar = described_class.new(3, output: output)
      2.times { bar.increment }
      bar.increment_failed
      bar.finish
      expect(output.string).to include("1 failed")
    end

    it "does nothing when output is not a TTY" do
      allow(output).to receive(:tty?).and_return(false)
      bar = described_class.new(3, output: output)
      bar.finish
      expect(output.string).to be_empty
    end
  end

  describe "#clear_bar" do
    it "writes ANSI clear sequence when bar is visible" do
      bar = described_class.new(3, output: output)
      output.truncate(0)
      output.rewind
      bar.clear_bar
      expect(output.string).to include("\e[2K")
    end

    it "does nothing when output is not a TTY" do
      allow(output).to receive(:tty?).and_return(false)
      bar = described_class.new(3, output: output)
      bar.clear_bar
      expect(output.string).to be_empty
    end
  end

  describe "#active?" do
    it "returns true when output is a TTY" do
      bar = described_class.new(3, output: output)
      expect(bar.active?).to be true
    end

    it "returns false when output is not a TTY" do
      allow(output).to receive(:tty?).and_return(false)
      bar = described_class.new(3, output: output)
      expect(bar.active?).to be false
    end
  end
end
