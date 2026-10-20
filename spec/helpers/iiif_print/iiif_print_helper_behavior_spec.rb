require 'spec_helper'

RSpec.describe IiifPrint::IiifPrintHelperBehavior, type: :helper do
  let(:document) { build(:newspaper_page_solr_document) }

  describe '#render_ocr_snippets' do
    let(:snippets) { ['first <em>suffrage</em> hit', 'second <em>suffrage</em> hit'] }
    let(:options) { { value: snippets, document: document } }

    it 'returns nil without snippets' do
      expect(helper.render_ocr_snippets(value: [])).to be_nil
    end

    it 'renders a single snippet without the more toggle' do
      output = helper.render_ocr_snippets(value: snippets.first(1), document: document)
      expect(output).to include('first_snippet')
      expect(output).not_to include('ocr_snippets_expand')
    end

    it 'renders additional snippets behind the more toggle' do
      output = helper.render_ocr_snippets(options)
      expect(output).to include('second <em>suffrage</em> hit')
      expect(output).to include('ocr_snippets_expand')
    end

    context 'when the view renders JSON, as for catalog.json' do
      before { helper.lookup_context.formats = [:json] }

      it 'still renders additional snippets as HTML' do
        output = helper.render_ocr_snippets(options)
        expect(output).to include('second <em>suffrage</em> hit')
        expect(output).to include('ocr_snippets_expand')
      end
    end
  end
end
