# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Make sure we use a JRuby which has been tested
PLUGIN_TOOL_JRUBY_REQUIREMENT = '9.0.4.0'
PLUGIN_TOOL_JAVA_REQUIREMENT = '1.8'
PLUGIN_TOOL_JAVA_REQUIREMENT_READABLE = "at least Java 8"

unless defined? JRUBY_VERSION
  puts "haplo-plugin can only run under JRuby"
  exit 1
end

require 'rubygems'

unless Gem::Dependency.new('', '>= '+PLUGIN_TOOL_JRUBY_REQUIREMENT).match?('', JRUBY_VERSION)
  puts "haplo-plugin requires JRuby #{PLUGIN_TOOL_JRUBY_REQUIREMENT} or later, you have #{JRUBY_VERSION}"
  exit 1
end

require 'java'

unless Gem::Dependency.new('', '>= '+PLUGIN_TOOL_JAVA_REQUIREMENT).match?('', java.lang.System.getProperty("java.version").gsub(/[^0-9\.].+?\z/,''))
  puts "haplo-plugin requires #{PLUGIN_TOOL_JAVA_REQUIREMENT_READABLE}"
  exit 1
end

require 'digest/sha1'
require 'net/http'
require 'net/https'
require 'getoptlong'
require 'fileutils'
require 'thread'

gem 'json'
require 'json'

PLUGIN_TOOL_ROOT_DIR = File.expand_path(File.dirname(__FILE__)+'/..')

JS_JAR = "#{PLUGIN_TOOL_ROOT_DIR}/lib/js.jar"
unless File.exists? JS_JAR
  puts "Can't find JavaScript interpreter .jar file"
  exit 1
end
require JS_JAR

TEMPLATES_JAR = "#{PLUGIN_TOOL_ROOT_DIR}/lib/haplo-templates.jar"
unless File.exists? TEMPLATES_JAR
  puts "Can't find Haplo Templates .jar file"
  exit 1
end
require TEMPLATES_JAR

require "#{PLUGIN_TOOL_ROOT_DIR}/lib/hmac.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/manifest.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/auth.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/server.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/schema_requirements.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/hsvt_parser_config.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/syntax_checking.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/notifications.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/plugin.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/new_plugin.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/misc.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/watchers.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/minimise.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/check.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/custom.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/i18n_extract_text.rb"
require "#{PLUGIN_TOOL_ROOT_DIR}/lib/plugin_tool.rb"
