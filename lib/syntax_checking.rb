# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  @@syntax_check_queue = []
  @@syntax_check_queue_lock = Mutex.new
  @@syntax_check_queue_semaphore = Mutex.new
  @@syntax_check_queue_semaphore_var = ConditionVariable.new

  Context = Java::OrgMozillaJavascript::Context

  def self.start_syntax_check
    Thread.new do
      begin
        do_syntax_checking
      rescue => e
        puts "EXCEPTION IN SYNTAX CHECKER\n#{e.inspect}"
        exit 1
      end
    end
  end

  def self.init_syntax_checking
    # Set up interpreter and get a syntax checker function
    raise "Another JS Context is active" unless nil == Context.getCurrentContext()
    @@cx = Context.enter();
    @@javascript_scope = @@cx.initStandardObjects();
    jshint = File.open("#{File.dirname(__FILE__)}/jshint.js") { |f| f.read }
    @@cx.evaluateString(@@javascript_scope, jshint, "<jshint.js>", 1, nil);
    testerfn = File.open("#{File.dirname(__FILE__)}/js_syntax_test.js") { |f| f.read }
    @@cx.evaluateString(@@javascript_scope, testerfn, "<js_syntax_test.js>", 1, nil);
    @@syntax_tester = @@javascript_scope.get("syntax_tester", @@javascript_scope);
  end

  def self.syntax_check_one_file(plugin, file)
    # Is this file excluded from syntax checking?
    return nil if plugin.exclude_files_from_syntax_check.include?(file)
    # Load the plugin.json file
    plugin_dir = plugin.plugin_dir
    plugin_json = File.open("#{plugin_dir}/plugin.json") { |f| JSON.parse(f.read) }
    api_version = (plugin_json["apiVersion"] || '0').to_i
    # Determine kind of file
    return syntax_check_haplo_template(plugin, file) if file =~ /\.hsvt\z/i
    kind = (file =~ /\A(\w+)\//) ? $1 : file
    # Is this file referenced?
    report = nil
    unless kind != 'js' || plugin_json['load'].include?(file)
      puts "\nWARNING: #{plugin_dir}/plugin.json doesn't mention #{file} in the load directive.\n"
      report = "Couldn't check file - not mentioned in plugin.json"
    else
      schema_requirements = (api_version < 4) ? nil : SchemaRequirements.new("#{plugin_dir}/requirements.schema")
      extra_globals = schema_requirements ? schema_requirements.locals.dup : []
      # Load the file
      js = File.open("#{plugin_dir}/#{file}") { |f| f.read }
      if api_version < 3
        # If it's not the first file, need to tell JSHint about the extra var
        unless plugin_json['load'].first == file
          extra_globals << plugin_json["pluginName"];
        end
      else
        if kind == 'js' || kind == 'test'
          extra_globals << plugin_json["pluginName"]
          extra_globals << 'P'
          locals = plugin_json["locals"]
          if locals
            locals.each_key { |local| extra_globals << local }
          end
        end
        if kind == 'test'
          extra_globals << 't'
        end
        # global.js requires server side syntax checking, but doesn't have any extra globals, not even the plugin name.
        kind = 'js' if kind == 'global.js'
      end
      # Do syntax checking
      lint_report = @@syntax_tester.call(@@cx, @@javascript_scope, @@javascript_scope, [js, kind, JSON.generate(extra_globals)])
      schema_report = schema_requirements ? schema_requirements.report_usage(js) : nil
      report = [lint_report, schema_report].compact.join("\n\n")
      report = nil if report.empty?
    end
    report
  end

  def self.syntax_check_haplo_template(plugin, file)
    begin
      Java::OrgHaploTemplateHtml::Parser.new(File.read("#{plugin.plugin_dir}/#{file}"), file).parse()
      nil
    rescue => e
      "  #{e.message}"
    end
  end

  def self.do_syntax_checking
    init_syntax_checking
    while(true)
      plugin, file = @@syntax_check_queue_lock.synchronize do
        @@syntax_check_queue.shift
      end
      if file == nil
        # Wait for another file
        @@syntax_check_queue_semaphore.synchronize { @@syntax_check_queue_semaphore_var.wait(@@syntax_check_queue_semaphore) }
      else
        report = syntax_check_one_file(plugin, file)
        if report != nil
          puts "\n#{plugin.plugin_dir}/#{file} has syntax errors:\n#{report}\n\n"
          beep
        end
      end
    end
  end

  def self.syntax_check(plugin, filename)
    @@syntax_check_queue_lock.synchronize do
      @@syntax_check_queue << [plugin, filename]
      @@syntax_check_queue.uniq!
    end
    @@syntax_check_queue_semaphore.synchronize { @@syntax_check_queue_semaphore_var.signal }
  end

end

