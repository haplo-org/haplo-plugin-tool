#!/usr/bin/env ruby

# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


OUTPUT_DIR = 'distribute'
BUILD_DIR = 'tmp-output'
TO_COPY = ['README.md','LICENSE','bin','lib']

require 'fileutils'
require "#{File.dirname(__FILE__)}/../../khq/lib/common/source_control/source_control"

puts "Making plugin tool distribution..."

if File.exist? BUILD_DIR
  puts "Removing old build directory..."
  FileUtils.rm_rf BUILD_DIR
end

FileUtils.mkdir BUILD_DIR
FileUtils.mkdir "#{BUILD_DIR}/haplo-plugin"

# Source control version
source_control = SourceControl.current_revision
revision = source_control.displayable_id

# Copy in files
TO_COPY.each do |file|
  FileUtils.cp_r file, "#{BUILD_DIR}/haplo-plugin/#{file}"
end
# Remove source control or other dot files
Dir.glob("#{BUILD_DIR}/haplo-plugin/**/.*").each do |pathname|
  next if pathname.include?('..') # safety
  next if pathname =~ /\/\.+\z/
  FileUtils.rm_rf pathname
end

# Set permissions
Dir.glob("#{BUILD_DIR}/**/*.*") { |f| FileUtils.chmod 0644, f }
FileUtils.chmod 0755, "#{BUILD_DIR}/haplo-plugin/bin/haplo-plugin"

# Make sure js.jar is in there
unless File.exist?("#{BUILD_DIR}/haplo-plugin/lib/js.jar")
  puts "ERROR: lib/js.jar not in archive"
  exit 1
end

# Put the version in the archive
File.open("#{BUILD_DIR}/haplo-plugin/lib/version.txt", "w") { |f| f.write "#{revision}\n" }

# Copy in the gemspec
FileUtils.cp "haplo.gemspec-in", "#{BUILD_DIR}/haplo-plugin/haplo.gemspec"

# Make the gem file
system "( cd #{BUILD_DIR}/haplo-plugin; jgem build haplo.gemspec )"

# Move the gem file
Dir.glob("#{BUILD_DIR}/**/*.gem").each do |g|
  FileUtils.mv g, "distribute/"
end
