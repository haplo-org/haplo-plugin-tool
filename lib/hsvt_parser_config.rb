
class TemplateParserConfiguration < Java::OrgHaploTemplateHtml::ParserConfiguration
  def functionArgumentsAreURL(functionName)
    case functionName
    when "backLink", "std:ui:button-link", "std:ui:button-link:active"
      true
    else
      false
    end
  end
end
