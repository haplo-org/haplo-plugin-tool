# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module HMAC
  module SHA1
    def self.sign(key, message)
      mac = javax.crypto.Mac.getInstance("HmacSHA1")
      mac.init(javax.crypto.spec.SecretKeySpec.new(key.to_java_bytes, "HmacSHA1"))
      result = mac.doFinal(message.to_java_bytes)
      String.from_java_bytes(result).unpack('H*').join
    end
  end
end

