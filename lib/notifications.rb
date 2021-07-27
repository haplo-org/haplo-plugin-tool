# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  @@notification_options = nil
  @@notification_have_suppressed_first_system_audit_entry = false
  @@notification_announce_reconnect = false

  def self.start_notifications(options)
    @@notification_options = options
    @@notification_queue_name = nil
    Thread.new do
      while true
        begin
          self.do_notifications
        rescue => e
          puts "NOTICE: Lost notification connection, will attempt to reconnect soon."
          @@notification_announce_reconnect = true
          sleep(5)  # throttle errors
        end
      end
    end
  end

  def self.do_notifications
    http = make_http_connection
    puts "NOTICE: Notification connection established." if @@notification_announce_reconnect
    while true
      sleep(0.25) # small throttle of requests
      path = '/api/development-plugin-loader/get-notifications'
      path << "?queue=#{@@notification_queue_name}" if @@notification_queue_name
      request = Net::HTTP::Get.new(path)
      setup_request(request)
      # Server uses long-polling, and will respond after a long timeout, or when a notification
      # has been queued for sending to this process.
      response = http.request(request)
      if response.kind_of?(Net::HTTPOK)
        @@notification_queue_name = response['X-Queue-Name']
        begin
          decode_and_handle_notifications response.body
        rescue
          puts "NOTICE: Error handling notification from server."
        end
      else
        raise "Bad response"
      end
    end
  end

  def self.decode_and_handle_notifications(encoded)
    size = encoded.length
    pos = 0
    while pos < (size - 12)
      type = encoded[pos, 4]
      data_size = encoded[pos + 4, 8].to_i(16)
      data = encoded[pos + 12, data_size]
      pos += 12 + data_size
      handle_notification(type, data)
    end
  end

  def self.handle_notification(type, data)
    case type
    when 'log '
      # Output from console.log()
      puts "LOG:#{data}"
      DebugAdapterProtocolTunnel.log_message_from_server(data)
    when 'DAP1'
      DebugAdapterProtocolTunnel.dap_message_from_server(data)
    when 'prof'
      # Profiler report
      PluginTool.profiler_handle_report(data)
    when 'audt'
      decoded = JSON.parse(data)
      kind = decoded.find { |name,value| name == 'auditEntryType' }.last
      if kind =~ /\A[A-Z\-]+\z/
        # System audit entry - suppressed by default
        unless @@notification_options.show_system_audit
          unless @@notification_have_suppressed_first_system_audit_entry
            @@notification_have_suppressed_first_system_audit_entry = true
            puts "NOTICE: System audit trail entries are not being shown. Run with --show-system-audit to display."
          end
          return
        end
      end
      puts "AUDIT -------------------------------------------"
      decoded.each do |key, value|
        puts sprintf("%22s: %s", key, value.to_s)
      end
    else
      puts "WARNING: Unknown notification received from server. Upgrade the plugin tool using 'jgem update haplo'."
      sleep(5) # throttle problematic responses
    end
  end

end
