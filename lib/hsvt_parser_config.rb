
class TemplateParserConfiguration < Java::OrgHaploTemplateHtml::ParserConfiguration
    def functionArgumentsAreURL(functionName)
        "backLink" == functionName;
    end
end
