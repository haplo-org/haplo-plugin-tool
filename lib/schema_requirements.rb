# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginTool

  class SchemaRequirements
    IGNORE_LINE = /\A\s*(\#.+)?\z/m # comment or blank line
    OBJECT_FORMAT = /\A(OPTIONAL )?(?<kind>\S+)\s+(?<code>[a-zA-Z0-9_:-]+)\s*(as\s+(?<name>[a-zA-Z0-9_]+))?\s*\z/m

    SCHEMA_LOCALS = {
      "type" => "T",
      "attribute" => "A",
      "aliased-attribute" => "AA",
      "qualifier" => "Q",
      "label" => "Label",
      "group" => "Group"
    }

    def initialize(filename)
      # Define the special attributes by default
      @schema_names = {"A" => {
        "Parent" => true,
        "Type" => true,
        "Title" => true
      }}
      return unless File.exist?(filename)
      File.open(filename) do |file|
        file.each do |line|
          if (line !~ IGNORE_LINE) && (match = OBJECT_FORMAT.match(line))
            kind = SCHEMA_LOCALS[match[:kind]] || 'UNUSED'
            @schema_names[kind] ||= {}
            name = match[:name]
            if name && !name.empty?
              @schema_names[kind][name] = true
            end
          end
        end
      end
      @schema_names.delete('UNUSED')
    end

    def locals
      @schema_names.keys.dup
    end

    FIND_USE_REGEXP = Regexp.new("\\b(#{SCHEMA_LOCALS.values.join('|')})\\.([a-zA-Z0-9]+)\\b")

    def report_usage(js)
      report = []
      js.split(/\r?\n/).each_with_index do |line, index|
        line.scan(FIND_USE_REGEXP) do
          kind = $1
          name = $2
          lookup = @schema_names[kind]
          unless lookup && lookup.has_key?(name)
            report << "line #{index+1}: Schema name #{kind}.#{name} isn't declared in requirements.schema\n\n"
          end
        end
      end
      report.empty? ? nil : report.join
    end
  end

end

