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

WORKSPACE_FILE = 'workspace.json'
LOCAL_ONLY_COMMANDS = {"license-key" => true, "pack" => true, "check" => true, "new" => true}
NO_DEPENDENCY_COMMANDS = LOCAL_ONLY_COMMANDS.dup
PLUGIN_SEARCH_PATH = ['.']

# Options for passing to plugin objects
options = Struct.new(:output, :minimiser, :no_dependency, :no_console, :show_system_audit, :args, :force, :server_substring).new

# Parse arguments
show_help = false
requested_plugins = []
opts = GetoptLong.new(
  ['--help', '-h', GetoptLong::NO_ARGUMENT],
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
auto_uninstall_unexpected_plugins = false
if File.exist?(WORKSPACE_FILE)
  workspace_json = JSON.parse(File.read(WORKSPACE_FILE))
  if workspace_json.has_key?("search")
    PLUGIN_SEARCH_PATH.clear
    workspace_json["search"].each do |entry|
      if entry.has_key?("path")
        path = File.expand_path('./'+entry["path"])
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
  if workspace_json.has_key?("autoUninstallPlugins")
    auto_uninstall_unexpected_plugins=  !!(workspace_json["autoUninstallPlugins"])
  end
end

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

# Set up server communications and get application info
application_info = nil
unless LOCAL_ONLY_COMMANDS[PLUGIN_TOOL_COMMAND]
  PluginTool.setup_auth(options)
  PluginTool.check_for_certificate_file
  application_info = PluginTool.get_application_info
  puts "Remote application name: #{(application_info["name"]||'').to_s.strip.gsub(/\s+/,' ')}"
end

# If the user didn't requested a plugin, try to use the application info to select the root plugin
if requested_plugins.empty? && application_info
  application_root_plugin = application_info["config"]["applicationRootPlugin"]
  if application_root_plugin
    requested_plugins = [application_root_plugin.to_s]
  end
end
if requested_plugins.empty?
  end_on_error "No plugin specified and remote application isn't configured with an application root plugin, use -p plugin_name to specify"
end

def find_plugin_in_list(list, name)
  list.find { |p| p.name == name }
end

# Make plugin objects, start them, sort by order the server will load them
ALL_PLUGINS = plugin_paths.map do |path|
  PluginTool::Plugin.new(path, options)
end
def plugins_with_dependencies(plugin_names, no_dependency=false)
  selected_plugins = ALL_PLUGINS.select { |plugin| plugin_names.include?(plugin.name) }
  # Attempt to resolve dependencies
  unless no_dependency
    while true
      selected_plugins_expanded = selected_plugins.dup
      selected_plugins.each do |plugin|
        plugin.depend.each do |name|
          unless name =~ /\Astd_/
            unless find_plugin_in_list(selected_plugins_expanded, name)
              add_plugin = find_plugin_in_list(ALL_PLUGINS, name)
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
  selected_plugins
end

if requested_plugins == ["ALL"]
  plugins = ALL_PLUGINS.dup
else
  plugins = plugins_with_dependencies(requested_plugins, options.no_dependency || NO_DEPENDENCY_COMMANDS[PLUGIN_TOOL_COMMAND])
end
if plugins.length == 0
  end_on_error "No plugins selected, check -p option (requested: #{requested_plugins.join(',')})"
end

# Check requested plugins should be installed on this server
unless LOCAL_ONLY_COMMANDS[PLUGIN_TOOL_COMMAND]
  application_root_plugin = application_info["config"]["applicationRootPlugin"]
  if application_root_plugin
    root_plugin_dependent_plugins = plugins_with_dependencies([application_root_plugin.to_s])
    root_plugin_dependent_plugin_names = root_plugin_dependent_plugins.map { |p| p.name }
    # Check for plugins which aren't dependents of this plugin, as user might be uploading plugins
    # in error and break their development application.
    bad_plugin_requests = false
    plugins.each do |plugin|
      unless root_plugin_dependent_plugin_names.include?(plugin.name)
        puts "Not a dependent of the application root plugin: #{plugin.name}"
        bad_plugin_requests = true
      end
    end
    # Error if any of the requested plugins aren't in this list
    if bad_plugin_requests
      end_on_error("Stopping because some requested plugins are not dependents of the application root plugin: #{application_root_plugin}")
    end
    # So that you can switch between repo branchs without worrying about having to
    # uninstall the plugins in that branch, there's an option to remove anything
    # that's not expected.
    if auto_uninstall_unexpected_plugins
      application_info["installedPlugins"].each do |name|
        unless name =~ /\Astd_/
          unless root_plugin_dependent_plugin_names.include?(name)
            s_found_info = PluginTool.post_with_json_response("/api/development-plugin-loader/find-registration", {:name => name})
            if s_found_info["found"]
              puts "Uninstalling plugin #{name} from server..."
              res = PluginTool.post_with_json_response("/api/development-plugin-loader/uninstall/#{s_found_info['plugin_id']}")
              end_on_error "Couldn't uninstall plugin" unless res["result"] == 'success'
            end
          end
        end
      end
    end
  end
end

# Sort plugins by load order, and prepare local plugin objects
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

# Set up local plugin objects against server
unless LOCAL_ONLY_COMMANDS[PLUGIN_TOOL_COMMAND]
  PluginTool.custom_behaviour.server_ready(plugins, PLUGIN_TOOL_COMMAND, options)
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

