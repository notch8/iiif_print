# frozen_string_literal: true

module IiifPrint
  module ChildWorkIndexerDecorator
    def to_solr
      super.tap do |index_document|
        index_solr_doc(index_document)
      end
    end

    def generate_solr_document
      super.tap do |solr_doc|
        index_solr_doc(solr_doc)
      end
    end

    private

    def index_solr_doc(solr_doc)
      object ||= @object || resource
      solr_doc['is_child_bsi'] ||= object.try(:is_child)
      solr_doc['split_from_pdf_id_ssi'] ||= object.try(:split_from_pdf_id)
      solr_doc['is_page_of_ssim'] = iiif_print_lineage_service.ancestor_ids_for(object)
      solr_doc['descendent_member_ids_ssim'] = iiif_print_lineage_service.descendent_member_ids_for(object)
    end
  end
end

if ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_VALKYRIE', false))
  # Newer versions of Hyrax favor `Hyrax::Indexers::PcdmObjectIndexer` and deprecate
  # `Hyrax::ValkyrieWorkIndexer`
  indexers = Hyrax.config.curation_concerns.map do |concern|
    "#{concern}ResourceIndexer".safe_constantize
  end
  indexers.each { |indexer| indexer.prepend(IiifPrint::ChildWorkIndexerDecorator) }

  # Versions 3.0+ of Hyrax have `Hyrax::ValkyrieWorkIndexer` so we want to decorate that as
  # well.  We want to use the elsif construct because later on Hyrax::ValkyrieWorkIndexer
  # inherits from Hyrax::Indexers::PcdmObjectIndexer and only implements:
  # `def initialize(*args); super; end`
  'Hyrax::ValkyrieWorkIndexer'.safe_constantize&.prepend(IiifPrint::ChildWorkIndexerDecorator)
else
  # The ActiveFedora::Base indexer for Works
  Hyrax::WorkIndexer.prepend(IiifPrint::ChildWorkIndexerDecorator)
end
