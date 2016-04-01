# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


def end_on_error(err)
  puts err
  exit 1
end

File.open("#{File.dirname(__FILE__)}/version.txt") do |f|
  puts "Haplo Plugin Tool (#{f.read.chomp})"
end

PluginTool.try_load_custom

PluginTool::LocalConfig.load

# Commands not needing server
LOCAL_ONLY_COMMANDS = {"license-key" => true, "pack" => true, "check" => true}

# Plugin names
plugin_names = []

# Options for passing to plugin objects
options = Struct.new(:output, :minimiser, :no_console, :show_system_audit, :args, :force, :server_substring).new

# Parse arguments
show_help = false
opts = GetoptLong.new(
  ['--help', '-h', GetoptLong::NO_ARGUMENT],
  ['--plugin', '-p', GetoptLong::OPTIONAL_ARGUMENT],
  ['--server', '-s', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
  ['--output', GetoptLong::REQUIRED_ARGUMENT],
  ['--no-console', '-n', GetoptLong::NO_ARGUMENT],
  ['--show-system-audit', GetoptLong::NO_ARGUMENT],
  ['--minimise', '--minimize', '-m', GetoptLong::NO_ARGUMENT]
)
option_output = nil
opts.each do |opt, argument|
  case opt
  when '--help'
    show_help = true
  when '--plugin'
    plugin_names = argument.split(',').map {|n| n.gsub(/[\/\\]+\z/,'')} # remove trailing dir separators
  when '--server'
    options.server_substring = argument
  when '--output'
    options.output = argument
  when '--no-console'
    options.no_console = true
  when '--show-system-audit'
    options.show_system_audit = true
  when '--minimise', '--minimize'
    options.minimiser = PluginTool::Minimiser.new
  when '--force'
    options.force = true
  end
end
# Handle rest of command line -- first arg is the command, the rest are passed on
PLUGIN_TOOL_COMMAND = (ARGV.shift || 'develop')
options.args = ARGV

automatic_plugin_exclusion = false

# Help message?
if show_help || PLUGIN_TOOL_COMMAND == 'help'
  puts File.open("#{File.dirname(__FILE__)}/usage.txt") { |f| f.read }
  exit 0
end

# Plugin names handling
def find_all_plugins()
  all_plugins = []
  Dir.glob("**/plugin.json").each do |p|
    if p =~ /\A([a-zA-Z0-9_]+)\/plugin\.json\z/
      all_plugins << $1
    end
  end
  all_plugins
end

if plugin_names.length == 1 && plugin_names[0] == 'ALL'
  plugin_names = find_all_plugins()
  automatic_plugin_exclusion = true
end

# Some commands don't require a server or plugin to be specified
case PLUGIN_TOOL_COMMAND
when 'new'
  end_on_error "Plugin name not specified, use --plugin option." if plugin_names.empty?
  end_on_error "Only one plugin name should be specified for new command" if plugin_names.length > 1
  PluginTool.make_new_plugin(plugin_names.first)
  exit 0
when 'auth'
  PluginTool.cmd_auth options
  exit 0
when 'server'
  PluginTool.cmd_server options
  exit 0
end

# Find a plugin if none was specified
if plugin_names.empty?
  all_plugins = find_all_plugins()
  end_on_error "No plugin found" if all_plugins.length == 0
  if all_plugins.length > 1
    puts "Too many plugins in the current directory for automatic selection."
    puts "Use -p plugin_name to specify. Eg:"
    all_plugins.each do |name|
      puts "  #{$0} -p #{name}"
    end
    exit 1
  end
  plugin_names = all_plugins
end

# Make plugin objects, start them, sort by order the server will load them
plugins = plugin_names.map do |name|
  PluginTool::Plugin.new(name, options)
end
plugins.each { |p| p.start }
plugins.sort! do |a,b|
  pri_a = a.plugin_load_priority
  pri_b = b.plugin_load_priority
  (pri_a == pri_b) ? (a.name <=> b.name) : (pri_a <=> pri_b)
end
puts "#{plugins.length} plugin#{plugins.length != 1 ? 's' : ''}"

# Custom behaviour for this repo?
PluginTool.custom_behaviour.start(plugins, PLUGIN_TOOL_COMMAND, options, LOCAL_ONLY_COMMANDS[PLUGIN_TOOL_COMMAND])

# Special handling for some commands
case PLUGIN_TOOL_COMMAND
when 'pack'
  end_on_error "Output directory not specified, use --output option." unless options.output != nil
  require "#{File.dirname(__FILE__)}/packing.rb"
when 'check'
  PluginTool.check_plugins(plugins)
  exit 0
end

# Set up server communications
unless LOCAL_ONLY_COMMANDS[PLUGIN_TOOL_COMMAND]
  PluginTool.setup_auth(options)
  PluginTool.check_for_certificate_file

  PluginTool.custom_behaviour.server_ready(plugins, PLUGIN_TOOL_COMMAND, options)

  if automatic_plugin_exclusion
    exclusions = PluginTool::LocalConfig.get_list("exclude")
    plugins = plugins.select do |plugin|
      if exclusions.include?(plugin.name)
        puts "NOTICE: Excluded plugin #{plugin.name}"
        false
      else
        true
      end
    end
  end

  plugins.each { |p| p.setup_for_server }
end

# Run the command
errors = []
plugins.each { |p| p.command(PLUGIN_TOOL_COMMAND, errors) }

# It this isn't the long-running develop command, output errors and stop now
if PLUGIN_TOOL_COMMAND != 'develop'
  errors.each { |error| puts error }
  exit(errors.empty? ? 0 : 1)
end

# Syntax checking in the background
PluginTool.start_syntax_check

# Notifications support (including console)
PluginTool.start_notifications(options) unless options.no_console

# Open watcher
watcher = PluginTool.make_watcher(plugins.map { |p| p.plugin_dir })

# Start plugins
plugins.each { |p| p.develop_setup }

# Upload changes
first_run = true
while(true)
  puts "Scanning plugin files..."
  plugins.each { |p| p.develop_scan_and_upload(first_run) }
  PluginTool::Plugin.do_apply
  PluginTool.finish_with_connection
  puts "Waiting for changes..."
  if first_run
    puts "  Any changes you make to your local copy of the plugin will be automatically"
    puts "  uploaded to the server."
  end
  first_run = false
  watcher.wait(3600)
end

