# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  @@profile_output = nil

  def self.request_profile(options)
    output_file = $stdout
    close_output_file = false
    if options.profile_file
      output_file = File.open(options.profile_file, "a")
      close_output_file = true
    end

    formatter = nil
    case options.profile_format || 'tree'
    when 'tree'
      @@profile_output = ProfilerFormatterTree.new(output_file)
    when 'raw'
      @@profile_output = ProfilerFormatterRaw.new(output_file)
    else
      puts "Unknown profiler format: #{options.profile_format}"
      exit 1
    end

    if 'OK' == PluginTool.post("/api/development-plugin-loader/debugger-profile-start", {:min => options.profile})
      puts "JavaScript profiler started."
    else
      puts "Error starting JavaScript profiler."
      exit 1
    end
    at_exit do
      puts
      puts "Disabling JavaScript profiler..."
      PluginTool.post("/api/development-plugin-loader/debugger-profile-stop")
      puts "JavaScript profiler disabled."
      output_file.close if close_output_file
    end
  end

  class ProfilerFormatter
    def initialize(output_file)
      @output_file = output_file
    end
    def format(report)
      _format(report, @output_file)
      @output_file.flush
    end
  end

  class ProfilerFormatterRaw < ProfilerFormatter
    def _format(report, output_file)
      output_file.write(report)
    end
  end

  class ProfilerFormatterTree < ProfilerFormatter
    def _format(report, output_file)
      report.split("\n").each do |line|
        depth, time, percent, count, position = line.split("\t")
        if depth == 'REPORT'
          output_file.write("PROFILE -- #{Time.new(time)}\n")
        elsif depth == 'OMIT'
          output_file.write(("  "*time.to_i)+"... children omitted\n")
        else
          output_file.write(("  "*depth.to_i)+"#{percent} #{count} #{time.to_i / 1000000} #{position}\n")
        end
      end
    end
  end

  def self.profiler_handle_report(report)
    if @@profile_output
      @@profile_output.format(report)
    end
  end

  # -------------------------------------------------------------------------

  def self.request_coverage(options)

    format = options.coverage_format || 'raw'
    if format != 'raw'
      puts "Unknown coverage format: #{format}"
      exit 1
    end

    if 'OK' == PluginTool.post("/api/development-plugin-loader/debugger-coverage-start")
      puts "Coverage capture started."
    else
      puts "Error starting coverage capture."
      exit 1
    end

    at_exit do
      coverage = PluginTool.post("/api/development-plugin-loader/debugger-coverage-stop")
      # TODO: Check errors
      File.open(options.coverage_file, "w") { |f| f.write coverage }
    end

  end

end

# -------------------------------------------------------------------------

module DebugAdapterProtocolTunnel

  @@dap_plugins = nil
  @@dap_debugger_option = nil
  @@dap_server = nil
  @@dap_connection = nil

  def self.prepare(plugins, options)
    @@dap_plugins = plugins
    @@dap_debugger_option = options.debugger
    raise "BAD DEBUGGER OPTION #{@@dap_debugger_option}" unless @@dap_debugger_option =~ /\A(\d+)\z/
    @@dap_server = TCPServer.new("127.0.0.1", @@dap_debugger_option.to_i)
    Thread.new do
      while true
        connection = @@dap_server.accept
        if connection
          if @@dap_connection
            connection.close
          else
            @@dap_connection = DAPConnection.new(connection, @@dap_plugins)
            Thread.new do
              @@dap_connection.run
              _stop_remote_debugger()
              @@dap_connection = nil
            end
          end
        end
      end
    rescue => e
      # ignore
    end
    at_exit do
      @@dap_server.close
      @@dap_connection.close if @@dap_connection
      _stop_remote_debugger()
    end
  end

  def self._stop_remote_debugger
    puts "DEBUGGER: Stopping remote debugger..."
    result = PluginTool.post("/api/development-plugin-loader/debugger-dap-stop")
    if result == 'OK'
      puts "DEBUGGER: Remote debugger stopped."
    else
      puts "DEBUGGER: Error stopping remote debugger, application server may be in non-functioning state."
    end
  end

  def self.log_message_from_server(text)
    if @@dap_connection
      @@dap_connection._write({
        'type' => 'event',
        'event' => 'output',
        'body' => {
          'category' => 'console',
          'output' => text+"\n"
        }
      })
    end
  end

  def self.dap_message_from_server(json)
    if @@dap_connection
      @@dap_connection._write(JSON.parse(json))
    end
  end

  class DAPConnection
    def initialize(connection, plugins)
      @connection = connection
      @plugins = plugins
      @running = false
      @next_seq = 1
      @write_mutex = Mutex.new
      @_dump_messages = (ENV['HAPLO_DAP_DEBUG'] == '1')
    end

    def close
      begin
        @connection.close
      rescue => e
        # ignore any errors
      end
    end

    def run
      begin
        run2
      rescue => e
        puts "DEBUGGER: Local connection closed"
      end
      self.close
    end

    def run2
      @running = true
      have_initialized = false
      while @running
        header = @connection.readline
        blank = @connection.readline
        if header =~ /\Acontent-length:\s+(\d+)\r\n\z/i && blank == "\r\n"
          body = @connection.read($1.to_i)
          message = JSON.parse(body)
          puts "DAP READ: #{JSON.pretty_generate(message)}\n" if @_dump_messages
          unless have_initialized
            if message['type'] == 'request' && message['command'] == 'initialize'
              puts "DEBUGGER: Local connection from #{message['arguments']['clientName']} (#{message['arguments']['clientID']})\nDEBUGGER: Starting remote debugger..."
              plugin_locations = {}
              @plugins.each { |p| plugin_locations[p.name] = p.plugin_dir }
              start_response = PluginTool.post("/api/development-plugin-loader/debugger-dap-start", {
                :plugin_locations => JSON.generate(plugin_locations)
              })
              unless start_response =~ /\ATOKEN: (.+)\z/
                raise "Remote debugger failed to start"
              end
              @token = $1
              puts "DEBUGGER: Remote debugger started."
              have_initialized = true
            else
              raise "Expected initialize message after DAP connection"
            end
          end
          # TODO: Send messages in another thread, so that they can be batched together
          message_response = PluginTool.post_with_json_response("/api/development-plugin-loader/debugger-dap-messages", {
            :token => @token,
            :messages => JSON.generate([message])
          })
          if message_response['error']
            puts "DEBUGGER: Server responded with error: #{message_response['error']}"
          else
            message_response['messages'].each do |response|
              _write(response) if response
            end
          end
        end
      end
    end

    def _write(message)
      @write_mutex.synchronize do
        m = {'seq' => @next_seq}
        @next_seq += 1
        m.merge!(message)
        puts "DAP WRITE: #{JSON.pretty_generate(m)}\n" if @_dump_messages
        msg_json = JSON.generate(m)
        @connection.write("Content-Length: #{msg_json.bytesize}\r\n\r\n")
        @connection.write(msg_json)
      end
    end
  end

end
