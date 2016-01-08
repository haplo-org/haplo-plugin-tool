# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  module LocalConfig

    LOCAL_CONFIG_FILENAME = "server.config.json"

    def self.load
      if File.exist? LOCAL_CONFIG_FILENAME
        @@local_config = JSON.parse(File.open(LOCAL_CONFIG_FILENAME) { |f| f.read })
      else
        @@local_config = {}
      end
    end

    def self.get_list(list_name)
      lookup = @@local_config[list_name]
      return [] unless lookup
      list = []
      server_name = PluginTool.get_server_hostname
      list.concat(lookup['*']) if lookup.has_key?('*')
      list.concat(lookup[server_name]) if server_name && lookup.has_key?(server_name)
      list
    end

  end

end
