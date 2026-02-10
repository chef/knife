#
# Author:: Seth Chisamore (<schisamo@chef.io>)
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

require_relative "bootstrap_context"
require "chef-config/path_helper" unless defined?(ChefConfig::PathHelper)
require "chef-utils/dist" unless defined?(ChefUtils::Dist)

class Chef
  class Knife
    module Core
      # Instances of BootstrapContext are the context objects (i.e., +self+) for
      # bootstrap templates. For backwards compatibility, they +must+ set the
      # following instance variables:
      # * @config   - a hash of knife's config values
      # * @run_list - the run list for the node to bootstrap
      #
      class WindowsBootstrapContext < BootstrapContext
        attr_accessor :config
        attr_accessor :chef_config
        attr_accessor :secret

        def initialize(config, run_list, chef_config, secret = nil)
          @config       = config
          @run_list     = run_list
          @chef_config  = chef_config
          @secret       = secret
          super(config, run_list, chef_config, secret)
        end

        def validation_key
          if File.exist?(File.expand_path(chef_config[:validation_key]))
            File.read(File.expand_path(chef_config[:validation_key]))
          else
            false
          end
        end

        def encrypted_data_bag_secret
          escape_and_echo(@secret)
        end

        def trusted_certs_script
          @trusted_certs_script ||= trusted_certs_content
        end

        def config_content
          # The windows: true / windows: false in the block that follows is more than a bit weird.  The way to read this is that we need
          # the e.g. var_chef_dir to be rendered for the windows value ("C:\chef"), but then we are rendering into a file to be read by
          # ruby, so we don't actually care about forward-vs-backslashes and by rendering into unix we avoid having to deal with the
          # double-backwhacking of everything.  So we expect to see:
          #
          # file_cache_path "C:/chef"
          #
          # Which is mildly odd, but should be entirely correct as far as ruby cares.
          #
          client_rb = <<~CONFIG
            chef_server_url  "#{chef_config[:chef_server_url]}"
            validation_client_name "#{chef_config[:validation_client_name]}"
            file_cache_path   "#{ChefConfig::PathHelper.escapepath(chef_config[:windows_bootstrap_file_cache_path] || "")}"
            file_backup_path  "#{ChefConfig::PathHelper.escapepath(chef_config[:windows_bootstrap_file_backup_path] || "")}"
            cache_options     ({:path => "#{ChefConfig::PathHelper.escapepath(ChefConfig::Config.etc_chef_dir(windows: true))}\\\\cache\\\\checksums", :skip_expires => true})
          CONFIG

          unless chef_config[:chef_license].nil?
            client_rb << "chef_license \"#{chef_config[:chef_license]}\"\n"
          end

          if config[:chef_node_name]
            client_rb << %Q{node_name "#{config[:chef_node_name]}"\n}
          else
            client_rb << "# Using default node name (fqdn)\n"
          end

          if chef_config[:config_log_level]
            client_rb << %Q{log_level :#{chef_config[:config_log_level]}\n}
          else
            client_rb << "log_level        :auto\n"
          end

          client_rb << "log_location       #{get_log_location}"

          # We configure :verify_api_cert only when it's overridden on the CLI
          # or when specified in the knife config.
          if !config[:node_verify_api_cert].nil? || config.key?(:verify_api_cert)
            value = config[:node_verify_api_cert].nil? ? config[:verify_api_cert] : config[:node_verify_api_cert]
            client_rb << %Q{verify_api_cert #{value}\n}
          end

          # We configure :ssl_verify_mode only when it's overridden on the CLI
          # or when specified in the knife config.
          if config[:node_ssl_verify_mode] || config.key?(:ssl_verify_mode)
            value = case config[:node_ssl_verify_mode]
                    when "peer"
                      :verify_peer
                    when "none"
                      :verify_none
                    when nil
                      config[:ssl_verify_mode]
                    else
                      nil
                    end

            if value
              client_rb << %Q{ssl_verify_mode :#{value}\n}
            end
          end

          if config[:ssl_verify_mode]
            client_rb << %Q{ssl_verify_mode :#{config[:ssl_verify_mode]}\n}
          end

          if config[:bootstrap_proxy]
            client_rb << "\n"
            client_rb << %Q{http_proxy        "#{config[:bootstrap_proxy]}"\n}
            client_rb << %Q{https_proxy       "#{config[:bootstrap_proxy]}"\n}
            client_rb << %Q{no_proxy          "#{config[:bootstrap_no_proxy]}"\n} if config[:bootstrap_no_proxy]
          end

          if config[:bootstrap_no_proxy]
            client_rb << %Q{no_proxy       "#{config[:bootstrap_no_proxy]}"\n}
          end

          if secret
            client_rb << %Q{encrypted_data_bag_secret "#{ChefConfig::PathHelper.escapepath(ChefConfig::Config.etc_chef_dir(windows: true))}\\\\encrypted_data_bag_secret"\n}
          end

          unless trusted_certs_script.empty?
            client_rb << %Q{trusted_certs_dir "#{ChefConfig::PathHelper.escapepath(ChefConfig::Config.etc_chef_dir(windows: true))}\\\\trusted_certs"\n}
          end

          if chef_config[:fips]
            client_rb << "fips true\n"
          end

          escape_and_echo(client_rb)
        end

        def get_log_location
          if chef_config[:config_log_location].equal?(:win_evt)
            %Q{:#{chef_config[:config_log_location]}\n}
          elsif chef_config[:config_log_location].equal?(:syslog)
            raise "syslog is not supported for log_location on Windows OS\n"
          elsif chef_config[:config_log_location].equal?(STDOUT)
            "STDOUT\n"
          elsif chef_config[:config_log_location].equal?(STDERR)
            "STDERR\n"
          elsif chef_config[:config_log_location].nil? || chef_config[:config_log_location].empty?
            "STDOUT\n"
          elsif chef_config[:config_log_location]
            %Q{"#{chef_config[:config_log_location]}"\n}
          else
            "STDOUT\n"
          end
        end

        def start_chef
          path_command = build_path_command
          chef_executable = build_chef_executable
          license_argument = build_license_argument

          client_rb = clean_etc_chef_file("client.rb")
          first_boot = clean_etc_chef_file("first-boot.json")
          bootstrap_environment_option = build_environment_option

          "#{path_command}#{chef_executable} -c #{client_rb} -j #{first_boot}#{bootstrap_environment_option}#{license_argument}\n"
        end

        def build_path_command
          base_path = "SET \"PATH=%SYSTEM32%;%SystemRoot%;%SYSTEM32%\\Wbem;%SYSTEM32%\\WindowsPowerShell\\v1.0\\;"

          additional_paths = if chef_ice?
                               "C:\\hab\\bin"
                             else
                               c_opscode_dir = ChefConfig::PathHelper.cleanpath(ChefConfig::Config.c_opscode_dir, windows: true)
                               "C:\\ruby\\bin;#{c_opscode_dir}\\bin;#{c_opscode_dir}\\embedded\\bin"
                             end

          "#{base_path}#{additional_paths};%PATH%\"\n"
        end

        def build_chef_executable
          ChefUtils::Dist::Infra::CLIENT
        end

        def build_license_argument
          return "" if config[:disable_license_activation]
          return "" unless chef_ice? && config[:license_id]

          " --chef-license-key #{config[:license_id]}"
        end

        def build_environment_option
          bootstrap_environment.nil? ? "" : " -E #{bootstrap_environment}"
        end

        def win_wget
          # I tried my best to figure out how to properly url decode and switch / to \
          # but this is VBScript - so I don't really care that badly.
          win_wget = <<~WGET
            url = WScript.Arguments.Named("url")
            path = WScript.Arguments.Named("path")
            proxy = null
            '* Vaguely attempt to handle file:// scheme urls by url unescaping and switching all
            '* / into . Also assume that file:/// is a local absolute path and that file://<foo>
            '* is possibly a network file path.
            If InStr(url, "file://") = 1 Then
            url = Unescape(url)
            If InStr(url, "file:///") = 1 Then
            sourcePath = Mid(url, Len("file:///") + 1)
            Else
            sourcePath = Mid(url, Len("file:") + 1)
            End If
            sourcePath = Replace(sourcePath, "/", "\\")

            Set objFSO = CreateObject("Scripting.FileSystemObject")
            If objFSO.Fileexists(path) Then objFSO.DeleteFile path
            objFSO.CopyFile sourcePath, path, true
            Set objFSO = Nothing

            Else
            Set objXMLHTTP = CreateObject("MSXML2.ServerXMLHTTP")
            Set wshShell = CreateObject( "WScript.Shell" )
            Set objUserVariables = wshShell.Environment("USER")

            rem http proxy is optional
            rem attempt to read from HTTP_PROXY env var first
            On Error Resume Next

            If NOT (objUserVariables("HTTP_PROXY") = "") Then
            proxy = objUserVariables("HTTP_PROXY")

            rem fall back to named arg
            ElseIf NOT (WScript.Arguments.Named("proxy") = "") Then
            proxy = WScript.Arguments.Named("proxy")
            End If

            If NOT isNull(proxy) Then
            rem setProxy method is only available on ServerXMLHTTP 6.0+
            Set objXMLHTTP = CreateObject("MSXML2.ServerXMLHTTP.6.0")
            objXMLHTTP.setProxy 2, proxy
            End If

            On Error Goto 0

            objXMLHTTP.open "GET", url, false
            objXMLHTTP.send()
            If objXMLHTTP.Status = 200 Then
            Set objADOStream = CreateObject("ADODB.Stream")
            objADOStream.Open
            objADOStream.Type = 1
            objADOStream.Write objXMLHTTP.ResponseBody
            objADOStream.Position = 0
            Set objFSO = Createobject("Scripting.FileSystemObject")
            If objFSO.Fileexists(path) Then objFSO.DeleteFile path
            Set objFSO = Nothing
            objADOStream.SaveToFile path
            objADOStream.Close
            Set objADOStream = Nothing
            ElseIf objXMLHTTP.Status = 400 Then
            errorBody = objXMLHTTP.ResponseText
            WScript.Echo "Error: 400 BadRequest"
            WScript.Echo "Error Body:"
            WScript.Echo errorBody
            Else
            WScript.Echo "An error occurred while downloading the file:"
            errorBody = objXMLHTTP.ResponseText
            WScript.Echo "Status: "
            WScript.Echo objXMLHTTP.Status
            WScript.Echo "Status Text: "
            WScript.Echo errorBody
            End If
            Set objXMLHTTP = Nothing
            End If
          WGET
          escape_and_echo(win_wget)
        end

        def win_wget_ps
          win_wget_ps = <<~WGET_PS
            param(
               [String] $remoteUrl,
               [String] $localPath
            )

            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            $ProxyUrl = $env:http_proxy;
            $webClient = new-object System.Net.WebClient;

            if ($ProxyUrl -ne '') {
              $WebProxy = New-Object System.Net.WebProxy($ProxyUrl,$true)
              $WebClient.Proxy = $WebProxy
            }

            try {
              $webClient.DownloadFile($remoteUrl, $localPath);

              Write-Host "Download complete. The file has been saved to $localPath."
            } catch [System.Net.WebException] {
              $response = $_.Exception.Response

              if ($response.StatusCode -eq [System.Net.HttpStatusCode]::BadRequest) {
                $streamReader = New-Object System.IO.StreamReader($response.GetResponseStream())
                $errorBody = $streamReader.ReadToEnd()
                $streamReader.Dispose()

                Write-Host "Error: 400 BadRequest"
                Write-Host "Error Body:"
                Write-Host $errorBody
              }
              else {
                Write-Host "An error occurred while downloading the file:"
                Write-Host $_.Exception.Message
              }
              Exit 1
            }
          WGET_PS

          escape_and_echo(win_wget_ps)
        end

        def first_boot
          escape_and_echo(super.to_json)
        end

        def clean_etc_chef_file(path)
          ChefConfig::PathHelper.cleanpath(etc_chef_file(path), windows: true)
        end

        def etc_chef_file(path)
          "#{bootstrap_directory}/#{path}"
        end

        def bootstrap_directory
          ChefConfig::Config.etc_chef_dir(windows: true)
        end

        # Build a URL for the PowerShell install script (install.ps1)
        def install_ps1_url
          if config[:bootstrap_url]
            # Use custom bootstrap URL if provided
            config[:bootstrap_url]
          elsif config[:license_url]
            # Use license-aware install script URL
            config[:license_url].gsub("install.sh", "install.ps1")
          else
            # Default to public omnitruck install script
            "https://omnitruck.chef.io/install.ps1"
          end
        end

        # escape WIN BATCH special chars
        # and prefixes each line with an
        # echo
        def escape_and_echo(file_contents)
          file_contents.gsub(/^(.*)$/, 'echo.\1').gsub(/([(<|>)^])/, '^\1')
        end

        # Returns the MSI URL for downloading Chef Infra Client
        # Supports both chef and chef-ice products, and custom URLs
        def msi_url(machine_os = nil, machine_arch = nil, download_context = nil)
          # If a custom MSI URL is provided, use it directly
          return @config[:msi_url] if @config[:msi_url] && !@config[:msi_url].empty?

          # Determine the product to download
          product = product_to_install

          # Build the omnitruck URL
          base_url = @config[:omnitruck_url] || "https://omnitruck.chef.io"

          # Build URL with product name
          url_path = "#{product}/download"

          # Add parameters in the expected order
          params = []
          params << "p=windows"
          params << "pv=#{machine_os}" if machine_os
          params << "m=#{machine_arch}" if machine_arch
          params << "DownloadContext=#{download_context}" if download_context
          params << "channel=#{@config[:channel]}" if @config[:channel]
          params << "v=#{version_to_install}"
          params << "license_id=#{@config[:license_id]}" if @config[:license_id]

          # Format the URL based on whether omnitruck_url contains %s placeholder
          if base_url.include?("%s")
            # Custom omnitruck URL with placeholder (e.g., from licensing)
            url = format(base_url, url_path)
          else
            # Standard omnitruck URL
            url = "#{base_url}/#{url_path}"
          end

          # Add query parameters if any
          url += "?#{params.join("&")}" unless params.empty?

          url
        end

        private

        # Returns a string for copying the trusted certificates on the workstation to the system being bootstrapped
        # This string should contain both the commands necessary to both create the files, as well as their content
        def trusted_certs_content
          content = ""
          if chef_config[:trusted_certs_dir]
            Dir.glob(File.join(ChefConfig::PathHelper.escape_glob_dir(chef_config[:trusted_certs_dir]), "*.{crt,pem}")).each do |cert|
              content << "> #{bootstrap_directory}/trusted_certs/#{File.basename(cert)} (\n" +
                escape_and_echo(File.read(File.expand_path(cert))) + "\n)\n"
            end
          end
          content
        end

        def client_d_content
          content = ""
          if chef_config[:client_d_dir] && File.exist?(chef_config[:client_d_dir])
            root = Pathname(chef_config[:client_d_dir])
            root.find do |f|
              relative = f.relative_path_from(root)
              if f != root
                file_on_node = "#{bootstrap_directory}/client.d/#{relative}".tr("/", "\\")
                if f.directory?
                  content << "mkdir #{file_on_node}\n"
                else
                  content << "> #{file_on_node} (\n" +
                    escape_and_echo(File.read(File.expand_path(f))) + "\n)\n"
                end
              end
            end
          end
          content
        end

        # Returns the install command for Windows including license environment variable if needed
        def install_command(executor_quote)
          commands = []

          # Add license environment variable if applicable
          license_key = @config[:license_key] || @config[:license_id]

          # Only add license environment variable for Chef Infra 19+
          if license_key && chef_ice?
            commands << "set CHEF_LICENSE_KEY=#{license_key}"
          end

          # Add the msiexec installation command
          commands << "msiexec /qn /i chef-client.msi"

          commands.join("\n")
        end
      end
    end
  end
end
