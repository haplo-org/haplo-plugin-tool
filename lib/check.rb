# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  def self.check_plugins(plugins)
    init_syntax_checking
    @@check_report = ''
    @@check_ok = true
    @@check_warn = false
    max_plugin_name_length = plugins.map { |p| p.name.length } .max
    plugins.each { |p| check_plugin(p, max_plugin_name_length) }
    if @@check_warn || !(@@check_ok)
      puts "\nFILES WITH ERRORS"
      puts @@check_report
    end
    # Output the verdict
    puts
    if @@check_ok && !@@check_warn
      puts "PASSED"
    elsif @@check_warn
      puts "PASSED WITH WARNINGS"
    else
      puts "FAILED"
      exit 1
    end
  end

  def self.check_plugin(plugin, max_plugin_name_length)
    plugin_dir = plugin.plugin_dir
    STDOUT.write(sprintf("%#{max_plugin_name_length.to_i}s ", plugin.name))
    Dir.glob("#{plugin_dir}/**/*").each do |pathname|
      next unless File.file?(pathname)
      next if plugin.exclude_files_from_syntax_check.include?(pathname)
      plugin_relative_name = pathname[plugin_dir.length+1, pathname.length]
      if pathname =~ SYNTAX_CHECK_REGEXP
        STDOUT.write("."); STDOUT.flush
        # Check JavaScript
        report = syntax_check_one_file(plugin, plugin_relative_name)
        if report == nil
          check_file_result(plugin, plugin_relative_name, :OK)
        else
          puts "\n**** #{plugin_relative_name} has errors:\n#{report}\n"
          check_file_result(plugin, plugin_relative_name, (plugin_relative_name =~ /\A(js|template|file)\//) ? :FAIL : :WARN)
        end
      else
        # TODO: Checks for other file types, including the plugin.json
        check_file_result(plugin, plugin_relative_name, :OK)
      end
    end
    STDOUT.write("\n"); STDOUT.flush
  end

  def self.check_file_result(plugin, name, result)
    unless result == :OK
      @@check_report << "  #{plugin.plugin_dir}/#{name}: #{result}\n"
    end
    @@check_ok = false if result == :FAIL
    @@check_warn = true if result == :WARN
  end

end

