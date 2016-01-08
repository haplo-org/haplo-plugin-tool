# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  @@keys_pathname = "#{Dir.getwd}/.server.json"

  # ---------------------------------------------------------------------------------------------------------

  def self.setup_auth(options)
    keys = load_keys_file()
    server = keys['default']
    if options.server_substring
      server = select_server(keys, options.server_substring)
      end_on_error "No server found for substring '#{options.server_substring}'" unless server
    end
    key = keys['keys'][server]
    if key
      hostname, port, url_base = parse_hostname_with_port(server)
      set_server(hostname, port, key)
      puts "Application: #{url_base}"
    else
      end_on_error "No server authorised. Run haplo-plugin auth SERVER_NAME"
    end
  end

  # ---------------------------------------------------------------------------------------------------------

  def self.cmd_server(options)
    end_on_error "No server name substring given on command line" if options.args.empty?
    keys = load_keys_file()
    server = select_server(keys, options.args.first)
    end_on_error "No server found for substring '#{options.args.first}" unless server
    keys['default'] = server
    puts "Selected server #{server}"
    save_keys_file(keys)
  end

  # ---------------------------------------------------------------------------------------------------------

  def self.cmd_auth(options)
    end_on_error "No hostname given on command line" if options.args.empty?
    hostname, port, url_base, server_name = parse_hostname_with_port(options.args.first)

    keys = load_keys_file()
    if keys['keys'].has_key?(server_name) && !options.force
      puts
      puts "Already authorised with #{server_name}"
      puts "Use the --force argument to reauthorise with the server."
      return
    end

    set_server(hostname, port, nil)
    check_for_certificate_file()
    http = get_http()

    this_hostname = java.net.InetAddress.getLocalHost().getHostName() || "unknown"

    puts "Requesting token from #{url_base} ..."
    start_auth_path = "/api/plugin-tool-auth/start-auth?name=#{URI.encode(this_hostname)}"
    request = Net::HTTP::Get.new(start_auth_path)
    setup_request(request)
    token = nil
    begin
      response = http.request(request)
      end_on_error "Server returned an error. Check hostname and port." unless response.code == "200"
      parsed_json = JSON.parse(response.body)
      token = parsed_json['token']
      end_on_error "Server doesn't look like a Haplo server with plugin debugging enabled" unless ((parsed_json['Haplo'] == 'plugin-tool-auth') || (parsed_json['ONEIS'] == 'plugin-tool-auth')) && token
    rescue => e
      end_on_error "Failed to start authorisation process. Check hostname and port."
    end

    # Check token looks OK so we don't form dodgy URLs
    end_on_error "Bad token" unless token =~ /\A[a-z0-9A-Z_-]+\z/

    user_url = "#{url_base}/do/plugin-tool-auth/create/#{token}"
    poll_path = "/api/plugin-tool-auth/poll/#{token}"

    puts
    if java.lang.System.getProperty("os.name") == 'Mac OS X'
      puts "Attempting to open the following URL in your browser."
      puts "If the browser does not open, please visit this URL in your browser."
      system "open #{user_url}"
    else
      puts "Please visit this URL in your browser, and authenticate if necessary."
    end
    puts "  #{user_url}"
    puts

    # Poll for a few minutes, waiting for the user to authenticate
    puts "Waiting for server to authorise..."
    poll_count = 0
    key = nil
    while poll_count < 60 && !key
      delay = if poll_count < 10
        2
      elsif poll_count < 20
        4
      else
        8
      end
      sleep delay
      begin
        request = Net::HTTP::Get.new(poll_path)
        setup_request(request)
        response = http.request(request)
        parsed_json = JSON.parse(response.body)
        case parsed_json['status']
        when 'wait'
          # poll again
        when 'available'
          key = parsed_json['key']
        else
          end_on_error "Authorisation process failed."
        end
      rescue => e
        end_on_error "Error communicating with server"
      end
    end
    finish_with_connection()

    end_on_error "Didn't managed to authorise with server." unless key

    puts "Successfully authorised with server."

    keys['default'] = server_name
    keys['keys'][server_name] = key
    save_keys_file(keys)

    puts
    puts "Key stored in #{@@keys_pathname}"
    puts "#{server_name} selected as default server."
  end

  # ---------------------------------------------------------------------------------------------------------

  def self.parse_hostname_with_port(hostname_with_port)
    hostname_with_port = hostname_with_port.downcase.strip
    unless hostname_with_port =~ /\A(https?:\/\/)?([a-z0-9\.-]+)(:(\d+))?/i
      end_on_error "Bad hostname #{hostname_with_port}"
    end
    hostname = $2
    port = $4 ? $4.to_i : 443
    server_name = "#{hostname}#{(port != 443) ? ":#{port}" : ''}"
    [hostname, port, "https://#{server_name}", server_name]
  end

  # ---------------------------------------------------------------------------------------------------------

  def self.load_keys_file
    if File.exist?(@@keys_pathname)
      File.open(@@keys_pathname) { |f| JSON.parse(f.read) }
    else
      {"_" => "Contains server keys. DO NOT COMMIT TO SOURCE CONTROL.", "default" => nil, "keys" => {}}
    end
  end

  def self.save_keys_file(keys)
    pn = "#{@@keys_pathname}.n"
    File.open(pn, "w") { |f| f.write(JSON.pretty_generate(keys)) }
    File.rename(pn, @@keys_pathname)
  end

  def self.select_server(keys, substring)
    s = substring.downcase.strip
    keys['keys'].keys.sort { |a,b| (a.length == b.length) ? (a <=> b) : (a.length <=> b.length) } .find { |a| a.include? s }
  end

end
