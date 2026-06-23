module IiifPrint::IiifPrintHelperBehavior
  ##
  # print the ocr snippets. if more than one, separate with <br/>
  #
  # @param options [Hash] options hash provided by Blacklight
  # @return [String] snippets HTML to be rendered
  # rubocop:disable Rails/OutputSafety
  def render_ocr_snippets(options = {})
    snippets = options[:value]
    return if snippets.all?(&:blank?)

    snippets_content = [content_tag('div',
                                    "... #{snippets.first} ...".html_safe,
                                    class: 'ocr_snippet first_snippet')]
    if snippets.length > 1
      snippets_content << render(partial: 'catalog/snippets_more',
                                 locals: { snippets: snippets.drop(1),
                                           options: options })
    end
    snippets_content.join("\n").html_safe
  end
  # rubocop:enable Rails/OutputSafety
end
