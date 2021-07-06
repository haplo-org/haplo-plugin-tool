# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

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

