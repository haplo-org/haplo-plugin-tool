# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  # NOTE: Also update packing.rb if this changes
  ALLOWED_PLUGIN_DIRS = ['js', 'static', 'template', 'test', 'data']

  def self.generate_manifest(directory)
    manifest = Hash.new
    Dir.glob("#{directory}/**/*").sort.each do |pathname|
      # Ignore directories
      next unless File.file? pathname
      # Ignore temporary files
      next if pathname =~ /\~/
      # Check file
      filename = pathname.slice(directory.length + 1, pathname.length)
      raise "Bad filename for #{filename}" unless filename =~ /\A([a-zA-Z0-9_\/\-]+\/)?([a-zA-Z0-9_-]+\.[a-z0-9]+)\z/
      dir = $1
      name = $2
      if dir != nil
        dir = dir.gsub(/\/\z/,'')
        raise "Bad directory #{dir}" unless dir =~ /\A([a-zA-Z0-9_\-]+)[a-zA-Z0-9_\/\-]*\z/
        raise "Bad root directory #{$1}" unless ALLOWED_PLUGIN_DIRS.include?($1)
      end
      # Get hash of file
      digest = File.open(pathname) { |f| Digest::SHA256.hexdigest(f.read) }
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

