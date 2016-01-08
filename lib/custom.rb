# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  LOCAL_CUSTOM_BEHAVIOUR_FILENAME = "server.behaviour.rb"

  # Digests of trusted code are stored outside the source code repo, so it can't be written by the repo contents
  TRUSTED_CODE_DIGESTS_FILENAME = "~/.haplo-plugin-tool-trusted.json"

  class CustomBehaviour
    def start(plugins, command, options, is_local_command)
    end
    def server_ready(plugins, command, options)
    end
  end

  @@custom = CustomBehaviour.new

  def self.set_custom_behaviour(custom)
    @@custom = custom
  end

  def self.custom_behaviour
    @@custom
  end

  def self.try_load_custom
    return unless File.exist?(LOCAL_CUSTOM_BEHAVIOUR_FILENAME)

    trusted_code = nil
    untrusted_code = File.open(LOCAL_CUSTOM_BEHAVIOUR_FILENAME) { |f| f.read }
    untrusted_code_digest = Digest::SHA256.hexdigest(untrusted_code)

    trusted_code_digests = {"trust" => []}
    trusted_code_filename = File.expand_path(TRUSTED_CODE_DIGESTS_FILENAME)
    if File.exist?(trusted_code_filename)
      trusted_code_digests = JSON.parse(File.open(trusted_code_filename) { |f| f.read })
    end

    unless trusted_code_digests["trust"].include?(untrusted_code_digest)
      # Make sure the user wants to run this code. Otherwise running the plugin tool in a repo you've just
      # downloaded could unexpectedly execute code on your local machine.
      if ARGV.length == 2 && ARGV[0] == 'trust' && ARGV[1] =~ /\A[0-9a-z]{64}\z/ && ARGV[1] == untrusted_code_digest
        trusted_code_digests["trust"].push(untrusted_code_digest)
        File.open(trusted_code_filename,"w") { |f| f.write JSON.pretty_generate(trusted_code_digests) }
        puts "Stored trust for #{LOCAL_CUSTOM_BEHAVIOUR_FILENAME} with contents #{untrusted_code_digest}."
        exit 0
      else
        puts
        puts "-------------------------------------------------------------------------------------------"
        puts "  Do you trust the code in #{LOCAL_CUSTOM_BEHAVIOUR_FILENAME} to be run every time you run the"
        puts "  plugin tool? If yes, run"
        puts "      haplo-plugin trust #{untrusted_code_digest}"
        puts "  to permanently trust this version of #{LOCAL_CUSTOM_BEHAVIOUR_FILENAME}"
        puts "-------------------------------------------------------------------------------------------"
        puts
        PluginTool.beep
        exit 1
      end
    end

    if ARGV.length > 0 && ARGV[0] == "trust"
      puts "Unexpected trust command."
      exit 1
    end

    # User trusts the code, run it
    # There is a race condition here, but we're trying to protect against code in repositories, not
    # against software running on the local machine.
    load LOCAL_CUSTOM_BEHAVIOUR_FILENAME

  end

end
