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

class Chef
  class Knife
    class SshProgressBar
      BAR_CHARS = { filled: "\u2588", empty: "\u2591" }.freeze unless defined?(BAR_CHARS)

      attr_reader :total, :completed, :failed

      def initialize(total, output: $stderr)
        @total = total
        @completed = 0
        @failed = 0
        @output = output
        @active = @output.tty?
        @started_at = Time.now
        @mutex = Mutex.new
        @bar_visible = false
        render if @active
      end

      def increment
        @mutex.synchronize do
          @completed += 1
          do_render if @active
        end
      end

      def increment_failed
        @mutex.synchronize do
          @failed += 1
          @completed += 1
          do_render if @active
        end
      end

      def finish
        return unless @active

        @mutex.synchronize do
          clear_bar
          print_summary
          @bar_visible = false
        end
      end

      def active?
        @active
      end

      def clear_bar
        return unless @active && @bar_visible

        @output.write("\e[s")
        @output.write("\e[#{terminal_rows};1H")
        @output.write("\e[2K")
        @output.write("\e[u")
        @output.flush
        @bar_visible = false
      end

      def render
        return unless @active

        @mutex.synchronize { do_render }
      end

      private

      def do_render
        elapsed = Time.now - @started_at
        pct = @total > 0 ? (@completed.to_f / @total * 100).round(1) : 0
        bar = build_bar(pct)
        status = format_status(elapsed)

        @output.write("\e[s")
        @output.write("\e[#{terminal_rows};1H")
        @output.write("\e[2K")
        @output.write(status_line(bar, status, pct))
        @output.write("\e[u")
        @output.flush
        @bar_visible = true
      end

      def build_bar(pct)
        width = [terminal_cols - 40, 10].max
        filled_width = (pct / 100.0 * width).round
        empty_width = width - filled_width

        "\e[32m#{BAR_CHARS[:filled] * filled_width}\e[90m#{BAR_CHARS[:empty] * empty_width}\e[0m"
      end

      def format_status(elapsed)
        if @completed > 0 && @completed < @total
          rate = elapsed / @completed
          eta = ((@total - @completed) * rate).round
          " ETA #{format_duration(eta)}"
        elsif @completed == @total && @total > 0
          " done in #{format_duration(elapsed.round)}"
        else
          ""
        end
      end

      def status_line(bar, status, pct)
        failed_str = @failed > 0 ? " \e[31m(#{@failed} failed)\e[0m" : ""
        " #{bar} #{@completed}/#{@total} (#{pct}%)#{failed_str}#{status}"
      end

      def format_duration(seconds)
        if seconds >= 3600
          format("%dh%02dm%02ds", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        elsif seconds >= 60
          format("%dm%02ds", seconds / 60, seconds % 60)
        else
          "#{seconds}s"
        end
      end

      def print_summary
        elapsed = Time.now - @started_at
        failed_str = @failed > 0 ? ", \e[31m#{@failed} failed\e[0m" : ""
        @output.puts("\e[1m#{@completed}/#{@total} nodes completed#{failed_str} in #{format_duration(elapsed.round)}\e[0m")
      end

      def terminal_rows
        require "io/console" unless IO.respond_to?(:console)
        IO.console&.winsize&.first || 24
      end

      def terminal_cols
        require "io/console" unless IO.respond_to?(:console)
        IO.console&.winsize&.last || 80
      end
    end
  end
end
