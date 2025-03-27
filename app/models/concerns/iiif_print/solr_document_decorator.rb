# frozen_string_literal: true

module IiifPrint
  module SolrDocumentDecorator
    def digest_sha1
      digest[/urn:sha1:([\w]+)/, 1]
    end

    def method_missing(method_name, *args, &block)
      super unless iiif_print_solr_field_names.include? method_name.to_s
      self[IiifPrint.solr_name(method_name.to_s)]
    end

    def respond_to_missing?(method_name, include_private = false)
      iiif_print_solr_field_names.include?(method_name.to_s) || super
    end

    # consists of member_ids_ssim + its descendents' member_ids (recursively)
    def file_set_ids
      self['descendent_member_ids_ssim'] || self['member_ids_ssim']
    end

    def any_highlighting?
      response&.[]('highlighting')&.[](id)&.present?
    end

    def any_highlighting_in_all_text_fields?
      [CatalogController.blacklight_config.iiif_search[:full_text_field]].any? do |field|
        highlights = response&.dig('highlighting', id, field)
        highlights&.any? { |text| text.include?("<span class='highlight'>") }
      end
    end

    def solr_document
      self
    end
  end
end

SolrDocument.prepend(IiifPrint::SolrDocumentDecorator)
SolrDocument.attribute :is_child, Hyrax::SolrDocument::Metadata::Solr::String, 'is_child_bsi'
SolrDocument.attribute :split_from_pdf_id, Hyrax::SolrDocument::Metadata::Solr::String, 'split_from_pdf_id_ssi'
SolrDocument.attribute :digest, Hyrax::SolrDocument::Metadata::Solr::String, 'digest_ssim'

# @note These properties came from the newspaper_works gem.  They are configurable.
SolrDocument.class_attribute :iiif_print_solr_field_names, default: %w[alternative_title genre
                                                                       issn lccn oclcnum held_by text_direction
                                                                       page_number section author photographer
                                                                       volume issue_number geographic_coverage
                                                                       extent publication_date height width
                                                                       edition_number edition_name frequency preceded_by
                                                                       succeeded_by]
