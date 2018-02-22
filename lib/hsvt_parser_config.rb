
class TemplateParserConfiguration < Java::OrgHaploTemplateHtml::ParserConfiguration
    def functionArgumentsAreURL(functionName)
        ("backLink" == functionName) || ("std:ui:button-link" == functionName);
    end
end
