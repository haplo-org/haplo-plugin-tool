# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  PACKING_EXCLUDE = ['developer.json', 'readme.txt']

  def self.pack_plugin(plugin, output_directory, errors = [])
    STDOUT.write("#{plugin.name}: ")
    raise "Bad plugin name when packing" unless plugin.name =~ /\A[a-zA-Z0-9_]+\z/
    # Get filenames and sort
    plugin_dir = plugin.plugin_dir
    files = Dir.glob("#{plugin_dir}/**/*").map do |filename|
      if File.file? filename
        filename[plugin_dir.length+1, filename.length]
      else
        nil
      end
    end .compact.select do |filename|
      ok = plugin_filename_allowed?(filename) && !PACKING_EXCLUDE.include?(filename)
      unless ok || PACKING_EXCLUDE.include?(filename)
        STDOUT.write("!")
        errors.push("IGNORED: #{plugin_dir}/#{filename}")
      end
      ok
    end .sort
    # Clean output directory
    output_plugin_dir = "#{output_directory}/#{plugin.name}"
    if File.exist? output_plugin_dir
      FileUtils.rm_r(output_plugin_dir)
    end
    # Make file structure
    FileUtils.mkdir(output_plugin_dir)
    # Process each file, building a manifest
    manifest = ''
    minimiser = PluginTool::Minimiser.new
    files.each do |filename|
      STDOUT.write("."); STDOUT.flush
      data = File.open("#{plugin_dir}/#{filename}") { |f| f.read }
      # Minimise file?
      unless filename =~ /\Ajs\//
        data = minimiser.process(data, filename)
      end
      hash = Digest::SHA256.hexdigest(data)
      # Make sure output directory exists, write file
      output_pathname = "#{output_plugin_dir}/#{filename}"
      output_directory = File.dirname(output_pathname)
      FileUtils.mkdir_p(output_directory) unless File.directory?(output_directory)
      File.open(output_pathname, "w") { |f| f.write data }
      # Filename entry in Manifest
      manifest << "F #{hash} #{filename}\n"
    end
    STDOUT.write("\n")
    minimiser.finish
    # Write manifest and version
    File.open("#{output_plugin_dir}/manifest", "w") { |f| f.write manifest }
    version = Digest::SHA256.hexdigest(manifest)
    File.open("#{output_plugin_dir}/version", "w") { |f| f.write "#{version}\n" }
  end

end
