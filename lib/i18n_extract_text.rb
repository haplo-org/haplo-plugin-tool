
module PluginTool

  def self.i18n_extract_text(plugins)
    text = {}

    # Get text from templates. This is exact, because each template is parsed.
    parser_config = TemplateParserConfiguration.new
    plugins.each do |plugin|
      Dir.glob("#{plugin.plugin_dir}/template/**/*.hsvt").sort.each do |template|
        template = Java::OrgHaploTemplateHtml::Parser.new(File.read(template), "extract", parser_config).parse()
        template.extractTranslatedStrings().each do |string|
          text[string] = string
        end
      end
    end

    # Get text from JS files, which isn't exact, because it just relies on convention and hopes for the best.
    plugins.each do |plugin|
      Dir.glob("#{plugin.plugin_dir}/js/**/*.js").sort.each do |js_file|
        js = File.read(js_file)
        [/\bi\['([^']+)'\]/, /\bi\["([^"]+)"\]/].each do |regexp|
          js.scan(regexp) do
            text[$1] = $1
          end
        end
      end
    end

    # Last, add in any of the default locale's text, so where text is looked up by symbol, the translation is included.
    plugins.each do |plugin|
      ['global','local'].each do |scope|
        maybe_strings = "#{plugin.plugin_dir}/i18n/#{scope}/#{plugin.default_locale_id}.template.json"
        if File.exist?(maybe_strings)
          strings = JSON.parse(File.read(maybe_strings))
          strings.each do |k,v|
            text[k] = v
          end
        end
      end
    end

    puts JSON.pretty_generate(text)
  end

end
