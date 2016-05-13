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
PLUGIN_SEARCH_PATH = ['.']

# Options for passing to plugin objects
options = Struct.new(:output, :minimiser, :no_dependency, :no_console, :show_system_audit, :args, :force, :server_substring).new

# Parse arguments
show_help = false
workspace_file = nil
requested_plugins = []
opts = GetoptLong.new(
  ['--help', '-h', GetoptLong::NO_ARGUMENT],
  ['--workspace', '-w', GetoptLong::REQUIRED_ARGUMENT],
  ['--plugin', '-p', GetoptLong::OPTIONAL_ARGUMENT],
  ['--no-dependency', GetoptLong::NO_ARGUMENT],
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
  when '--workspace'
    workspace_file = argument
  when '--plugin'
    requested_plugins = argument.split(',').map {|n| n.gsub(/[\/\\]+\z/,'')} # remove trailing dir separators
  when '--no-dependency'
    options.no_dependency = true
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

# Parse workspace file
if workspace_file
  workspace_json = JSON.parse(File.read(workspace_file))
  if workspace_json.has_key?("base")
    workspace_base_json = JSON.parse(File.read(File.dirname(workspace_file)+'/'+workspace_json["base"]))
    workspace_json = workspace_base_json.merge(workspace_json)
  end
  if workspace_json.has_key?("search")
    PLUGIN_SEARCH_PATH.clear
    workspace_json["search"].each do |entry|
      if entry.has_key?("path")
        path = File.expand_path(File.dirname(workspace_file)+'/'+entry["path"])
        unless Dir.exist?(path)
          puts "Can't find directory: #{path}"
          puts "  #{entry["name"]}" if entry.has_key?("name")
          puts "  #{entry["obtain"]}" if entry.has_key?("obtain")
          exit 1
        end
        PLUGIN_SEARCH_PATH.push(path)
      end
    end
  end
  if workspace_json.has_key?("plugins")
    if requested_plugins.empty?
      requested_plugins = workspace_json["plugins"]
    end
  end
end

automatic_plugin_exclusion = false

# Help message?
if show_help || PLUGIN_TOOL_COMMAND == 'help'
  puts File.open("#{File.dirname(__FILE__)}/usage.txt") { |f| f.read }
  exit 0
end

# Find all plugins in the repository
plugin_paths = []
PLUGIN_SEARCH_PATH.each do |directory|
  Dir.glob("#{directory}/*/plugin.json").each do |p|
    if p =~ /\A(.+)\/plugin\.json\z/
      plugin_paths << $1
    end
  end
end

if plugin_paths.length == 1 && plugin_paths[0] == 'ALL'
  plugin_paths = find_all_plugins()
  automatic_plugin_exclusion = true
end

# Some commands don't require a server or plugin to be specified
case PLUGIN_TOOL_COMMAND
when 'new'
  end_on_error "Plugin name not specified, use --plugin option." if requested_plugins.empty?
  end_on_error "Only one plugin name should be specified for new command" if requested_plugins.length > 1
  PluginTool.make_new_plugin(requested_plugins.first)
  exit 0
when 'auth'
  PluginTool.cmd_auth options
  exit 0
when 'server'
  PluginTool.cmd_server options
  exit 0
end

# Check that the user requested a plugin
if requested_plugins.empty?
  end_on_error "No plugin specified, use -p plugin_name to specify or use workspace"
end

def find_plugin_in_list(list, name)
  list.find { |p| p.name == name }
end

# Make plugin objects, start them, sort by order the server will load them
plugins = plugin_paths.map do |path|
  PluginTool::Plugin.new(path, options)
end
unless requested_plugins == ["ALL"]
  selected_plugins = plugins.select { |plugin| requested_plugins.include?(plugin.name) }
  # Attempt to resolve dependencies
  unless options.no_dependency
    while true
      selected_plugins_expanded = selected_plugins.dup
      selected_plugins.each do |plugin|
        plugin.depend.each do |name|
          unless name =~ /\Astd_/
            unless find_plugin_in_list(selected_plugins_expanded, name)
              add_plugin = find_plugin_in_list(plugins, name)
              if add_plugin
                selected_plugins_expanded << add_plugin
              else
                puts "WARNING: Can't find dependency #{name}"
              end
            end
          end
        end
      end
      break if selected_plugins_expanded.length == selected_plugins.length
      selected_plugins = selected_plugins_expanded
    end
  end
  plugins = selected_plugins
end
if plugins.length == 0
  end_on_error "No plugins selected, check -p option (requested: #{requested_plugins.join(',')})"
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

