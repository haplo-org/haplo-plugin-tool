# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  PLUGIN_ACCEPTABLE_FILENAME = /\A(js|static|template|test|file|i18n)\/([A-Za-z0-9_\.-]+\/)*[A-Za-z0-9_\.-]+\.[A-Za-z0-9]+\z/
  PLUGIN_ACCEPTABLE_FILENAME_EXCEPTIONS = ['plugin.json', 'requirements.schema', 'global.js', 'certificates-temp-http-api.pem', 'developer.json', 'readme.txt']
  def self.plugin_filename_allowed?(filename)
    (filename =~ PLUGIN_ACCEPTABLE_FILENAME) || (PLUGIN_ACCEPTABLE_FILENAME_EXCEPTIONS.include?(filename))
  end

  def self.generate_manifest(directory)
    manifest = Hash.new
    Dir.glob("#{directory}/**/*").sort.each do |pathname|
      # Ignore directories
      next unless File.file? pathname
      # Ignore temporary files
      next if pathname =~ /\~/
      # Check file
      filename = pathname.slice(directory.length + 1, pathname.length)
      unless plugin_filename_allowed?(filename)
        puts "WARNING: Ignoring #{filename}"
        next
      end
      # Get hash of file
      digest = File.open(pathname, "rb") { |f| Digest::SHA256.hexdigest(f.read) }
      # And add to manifest
      manifest[filename] = digest
    end
    manifest
  end

  def self.determine_manifest_changes(from, to)
    changes = []
    from.each_key do |name|
      changes << [name, :delete] unless to.has_key?(name)
    end
    to.each do |name,hash|
      changes << [name, hash] unless from[name] == hash
    end
    changes
  end

end

