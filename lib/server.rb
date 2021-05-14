# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  def self.set_server(hostname, port, key)
    @@server_hostname = hostname
    @@server_port = port
    @@server_key = key
  end

  def self.get_server_hostname
    @@server_hostname
  end

  def self.check_for_certificate_file
    @@server_ca = nil
    hostname_parts = (@@server_hostname || '').split('.')
    search_list = (0..hostname_parts.length).map do |n|
      filename = "server"
      search_parts = hostname_parts[n..hostname_parts.length]
      filename << '.' unless search_parts.empty?
      filename << search_parts.join('.')
      filename << ".crt"
    end
    @@server_ca = search_list.find { |f| File.file?(f) }
    if @@server_ca
      puts "NOTICE: Using alternative CAs for SSL from #{@@server_ca}"
    else
      # Use build in certificate bundle
      @@server_ca = "#{File.dirname(__FILE__)}/CertificateBundle.pem"
    end
  end

  def self.make_http_connection
    http = Net::HTTP.new(@@server_hostname, @@server_port)
    ssl_ca = OpenSSL::X509::Store.new
    unless ssl_ca.respond_to? :add_file
      puts
      puts "jruby-openssl gem is not installed or bouncy castle crypto not available on CLASSPATH."
      puts "See installation instructions."
      puts
      exit 1
    end
    ssl_ca.add_file(@@server_ca)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.cert_store = ssl_ca
    http.read_timeout = 3600 # 1 hour, in case a test runs for a very long time
    http.start
    http
  end

  @@http = nil
  def self.get_http
    @@http ||= make_http_connection
  end

  def self.finish_with_connection
    if @@http != nil
      @@http.finish
      @@http = nil
    end
  end

  def self.setup_request(req)
    req['User-Agent'] = 'plugin-tool'
    req['X-ONEIS-Key'] = @@server_key if @@server_key
  end

  def self.get(path)
    http = get_http
    request = Net::HTTP::Get.new(path)
    setup_request(request)
    http.request(request).body
  end

  def self.get_with_json_response(path)
    report_errors_from_server(JSON.parse(get(path)))
  end

  def self.post(path, params = nil, files = nil)
    http = get_http
    request = Net::HTTP::Post.new(path)
    setup_request(request)
    if files == nil
      request.set_form_data(params) if params != nil
    else
      boundary = "----------XnJLe9ZIbbGUYtzPQJ16u1"
      request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      body = ''
      if params != nil
        params.each do |key,value|
        body << <<-EOF
--#{boundary}\r
Content-Disposition: form-data; name="#{key}"\r
\r
#{value}\r
EOF
        end
      end
      files.each do |key,info|
        pathname, data = info
        body << <<-EOF
--#{boundary}\r
Content-Disposition: form-data; name="#{key}"; filename="#{pathname}"\r
Content-Type: application/octet-stream\r
Content-Length: #{data.length}\r
\r
#{data}\r
EOF
      end
      body << "--#{boundary}--\r"
      request.body = body
    end
    http.request(request).body
  end

  def self.post_with_json_response(path, params = nil, files = nil)
    report_errors_from_server(JSON.parse(post(path, params, files)))
  end

  def self.report_errors_from_server(r)
    unless r.kind_of? Hash
      r = {
        "result" => 'error',
        "protocol_error" => true,
        "message" => "Unknown error. Either the server is not enabled for development, or the credentials in #{SERVER_INFO} are not valid."
      }
    end
    if r["result"] != 'success' && r.has_key?("message")
      puts "\n\n**************************************************************"
      puts "                   ERROR REPORTED BY SERVER"
      puts "**************************************************************\n\n"
      puts r["message"]
      puts "\n**************************************************************\n\n"
      beep
    end
    r
  end

  def self.get_application_info
    @@server_application_info ||= JSON.parse(get("/api/development-plugin-loader/application-info"))
  end

end
