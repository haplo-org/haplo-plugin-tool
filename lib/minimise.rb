# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  class Minimiser
    Context = Java::OrgMozillaJavascript::Context

    def initialize
      # Load UglifyJS into a JavaScript interpreter
      raise "Another JS Context is active" unless nil == Context.getCurrentContext()
      @cx = Context.enter();
      @cx.setLanguageVersion(Context::VERSION_1_7)
      @javascript_scope = @cx.initStandardObjects()
      ['js_min.js','uglifyjs/parse-js.js','uglifyjs/process.js','uglifyjs/squeeze-more.js'].each do |filename|
        js = File.open("#{File.dirname(__FILE__)}/#{filename}") { |f| f.read }
        @cx.evaluateString(@javascript_scope, js, "<#{filename}>", 1, nil);
      end
      @js_min = @javascript_scope.get("js_min", @javascript_scope);
    end

    def process(data, filename)
      if filename =~ /\.js\z/
        # JavaScript - use UglifyJS loaded into the JavaScript interpreter
        @js_min.call(@cx, @javascript_scope, @javascript_scope, [data])

      elsif filename =~ /\.html\z/
        # Simple processing of HTML
        # Remove HTML comments
        html = data.gsub(/\<\!\-\-.+?\-\-\>/m,'')
        # Remove indents
        html.gsub!(/^\s+/,'')
        # Remove any unnecessary line breaks (fairly conservative)
        html.gsub!(/\>[\r\n]+\</m,'><')
        html.gsub!(/([\>}])[\r\n]+([\<{])/m,'\1\2')
        html

      elsif filename =~ /\.css\z/
        # Simple processing of CSS
        css = data.gsub(/(^|\s)\/\*.+?\*\/($|\s)/m,'') # remove C style comments
        out = []
        css.split(/[\r\n]+/).each do |line|
          line.chomp!; line.gsub!(/^\s+/,''); line.gsub!(/\s+$/,'')
          line.gsub!(/\s+/,' ')       # contract spaces
          line.gsub!(/\s*:\s*/,':')   # remove unnecessary spaces
          if line =~ /\S/
            out << line
          end
        end
        css = out.join("\n")
        # Remove unnecessary line endings
        css.gsub!(/[\r\n]*(\{[^\}]+\})/m) do |m|
          $1.gsub(/[\r\n]/m,'')
        end
        css

      else
        # No processing
        data
      end
    end

    def finish
      Context.exit()
    end

  end

end

