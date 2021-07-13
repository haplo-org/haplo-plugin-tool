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

