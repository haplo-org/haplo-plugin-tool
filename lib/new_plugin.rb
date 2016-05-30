# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  def self.make_new_plugin(plugin_name)
    unless plugin_name =~ /\A[a-z0-9_]+\z/ && plugin_name.length > 8
      end_on_error "Bad plugin name - must use a-z0-9_ only, and more than 8 characters."
    end
    if File.exist?(plugin_name)
      end_on_error "File or directory #{plugin_name} already exists"
    end
    FileUtils.mkdir(plugin_name)
    ['js', 'static', 'template', 'test', 'file/form'].each do |dir|
      FileUtils.mkdir_p("#{plugin_name}/#{dir}")
    end
    random = java.security.SecureRandom.new()
    rbytes = Java::byte[20].new
    random.nextBytes(rbytes)
    install_secret = String.from_java_bytes(rbytes).unpack('H*').join
    plugin_url_fragment = plugin_name.gsub('_','-')
    File.open("#{plugin_name}/plugin.json",'w') do |file|
      file.write(<<__E)
{
  "pluginName": "#{plugin_name}",
  "pluginAuthor": "TODO Your Company",
  "pluginVersion": 1,
  "displayName": "#{plugin_name.split('_').map {|e| e.capitalize} .join(' ')}",
  "displayDescription": "TODO Longer description of plugin",
  "installSecret": "#{install_secret}",
  "apiVersion": 4,
  "load": [
      "js/#{plugin_name}.js"
    ],
  "respond": ["/do/#{plugin_url_fragment}"]
}
__E
    end
    File.open("#{plugin_name}/js/#{plugin_name}.js",'w') do |file|
      file.write(<<__E)

P.respond("GET", "/do/#{plugin_url_fragment}/example", [
], function(E) {
    E.render({
        // view goes here: http://docs.haplo.org/dev/plugin/request-handling
    });
});

__E
    end
    File.open("#{plugin_name}/template/example.hsvt",'w') do |file|
      file.write(<<__E)
// HSVT documentation: http://docs.haplo.org/dev/plugin/templates

pageTitle("Example page")

<p class="example"> "This is an example template." </p>
__E
    end
    File.open("#{plugin_name}/test/#{plugin_name}_test1.js",'w') do |file|
      file.write(<<__E)

t.test(function() {

    // For documentation, see
    //   http://docs.haplo.org/dev/plugin/tests

    t.assert(true);

});

__E
    end
    File.open("#{plugin_name}/requirements.schema",'w') do |file|
      file.write("\n\n\n")
    end
    puts <<__E

Plugin #{plugin_name} has been created. Run

  haplo-plugin -p #{plugin_name}

to upload it to the server, then visit

  https://<HOSTNAME>/do/#{plugin_url_fragment}/example

to see a sample page.

See http://docs.haplo.org/dev/plugin for more information.

__E
  end

end
