# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  class WatcherPoll
    def initialize(dirs)
      @dirs = dirs
      @last_contents = make_contents
    end
    def wait(timeout)
      while timeout > 0
        c = make_contents
        if @last_contents != c
          @last_contents = c
          return
        end
        timeout -= 1
        sleep 1
      end
    end
    def make_contents
      c = ''
      @dirs.each do |dir|
        Dir.glob("#{dir}/**/*").each do |file|
          c << file
          c << ":#{File.mtime(file).to_i}\n"
        end
      end
      c
    end
  end

  def self.make_watcher(dirs)
    # TODO: Option to use external watcher task
    # pipe = IO.popen(watcher_cmd)
    # wait with pipe.read
    WatcherPoll.new(dirs)
  end

end
