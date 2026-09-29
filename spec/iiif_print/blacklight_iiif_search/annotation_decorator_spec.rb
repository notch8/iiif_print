require 'spec_helper'

RSpec.describe IiifPrint::BlacklightIiifSearch::AnnotationDecorator do
  let(:parent_id) { 'abc123' }
  let(:page_document) do
    doc = build(:newspaper_page_solr_document)
    doc['is_page_of_ssim'] = [parent_id]
    doc
  end
  let(:controller) { CatalogController.new }
  let(:coordinates) do
    JSON.parse("{\"coords\":{\"software\":[[2641,4102,512,44]]}}")
  end
  let(:parent_document) do
    SolrDocument.new('id' => parent_id,
                     'has_model_ssim' => ['NewspaperIssue'])
  end
  let(:user_query) { 'software' }
  let(:query) do
    BlacklightIiifSearch::IiifSearch.new({ q: user_query }, { object_relation_field: 'is_page_of_ssim' }, parent_document)
                                    .solr_params[:q]
  end
  let(:snippet) { nil }
  let(:iiif_search_annotation) do
    BlacklightIiifSearch::IiifSearchAnnotation.new(page_document, query,
                                                   0, snippet, controller,
                                                   parent_document)
  end
  let(:file_set) { build(:file_set_solr_document) }
  let(:test_request) { ActionDispatch::TestRequest.new({}) }

  before do
    allow(controller).to receive(:request).and_return(test_request)
    allow(controller).to receive(:polymorphic_url)
      .with(parent_document, host: test_request.base_url, locale: nil)
      .and_return("/#{page_document[:issue_id_ssi]}")
    allow(SolrDocument).to receive(:find).with(file_set.id).and_return(file_set)
  end

  describe '#annotation_id' do
    subject { iiif_search_annotation.annotation_id }
    it 'returns a properly formatted URL' do
      expect(subject).to include("#{page_document[:issue_id_ssi]}/manifest/canvas/#{page_document[:member_ids_ssim].first}/annotation/0")
    end
  end

  describe '#canvas_uri_for_annotation' do
    before { allow(iiif_search_annotation).to receive(:fetch_and_parse_coords).and_return(coordinates) }

    subject { iiif_search_annotation.canvas_uri_for_annotation }
    it 'returns a properly formatted URL' do
      expect(subject).to include("#{page_document[:issue_id_ssi]}/manifest/canvas/#{page_document[:member_ids_ssim].first}")
    end

    describe 'private methods' do
      # test #coordinates based on output of #canvas_uri_for_annotation, which calls it
      describe '#coordinates' do
        it 'gets the expected value from #coordinates' do
          expect(subject).to include("#xywh=2641,4102,512,44")
        end

        context 'when the page text contains the word "and"' do
          let(:coordinates) do
            JSON.parse("{\"coords\":{\"and\":[[1,1,1,1]],\"software\":[[2641,4102,512,44]]}}")
          end

          it 'matches only the search term, not the query operators' do
            expect(subject).to include("#xywh=2641,4102,512,44")
          end
        end
      end
    end
  end

  describe '#as_hash' do
    let(:snippet) { 'free <em>software</em> foundation' }

    before { allow(iiif_search_annotation).to receive(:fetch_and_parse_coords).and_return(coordinates) }

    subject { iiif_search_annotation.as_hash['resource']['chars'] }

    it 'labels the annotation with the search term alone' do
      expect(subject).to eq 'software'
    end

    context 'with a multi-word query' do
      let(:user_query) { 'fast ball' }

      it 'keeps every term and no filter clauses' do
        expect(subject).to eq 'fast ball'
      end
    end

    context 'with a line break in the query' do
      let(:user_query) { "fast\nball" }

      it 'keeps the terms on both lines' do
        expect(subject).to eq "fast\nball"
      end
    end

    context 'with an empty query' do
      let(:user_query) { '' }

      it 'returns an empty label' do
        expect(subject).to eq ''
      end
    end
  end
end
