# frozen_string_literal: true

module IiifPrint
  module FileSetIndexerDecorator
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
      # only UV viewable images should have is_page_of, it is only used for iiif search
      solr_doc['is_page_of_ssim'] = IiifPrint::LineageService.ancestor_ids_for(object) if image?(object)
      # index for full text search
      solr_doc['all_text_tsimv'] = solr_doc['all_text_timv'] = all_text(object)
      solr_doc['digest_ssim'] = find_checksum(object)
      solr_doc['shrine_file_identifier_ss'] = find_shrine_file_identifier(object)
    end

    def image?(object)
      mime_type = object.try(:mime_type) || object.original_file.try(:mime_type)
      mime_type&.match(/image/)
    end

    def find_checksum(object)
      file = object.original_file
      return unless file

      digest ||= if file.is_a?(Hyrax::FileMetadata)
                   Array.wrap(file.checksum).first
                 else # file is a Hydra::PCDM::File (ActiveFedora)
                   file.digest.first
                 end
      return unless digest

      digest.to_s
    end

    def find_shrine_file_identifier(object)
      file = object.try(:original_file)
      return unless file.is_a?(Hyrax::FileMetadata)
      identifier = file.file_identifier.to_s
      return unless identifier.start_with?('shrine://')
      identifier.delete_prefix('shrine://')
    end

    def all_text(object)
      file = object.original_file
      return unless file

      text = IiifPrint.extract_text_for(file_set: object)
      return text if text.blank?

      text.tr("\n", ' ').squeeze(' ')
    end
  end
end
if ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_VALKYRIE', false))
  # Newer versions of Hyrax favor `Hyrax::Indexers::FileSetIndexer` and deprecate
  # `Hyrax::ValkyrieFileSetIndexer`.
  'Hyrax::Indexers::FileSetIndexer'.safe_constantize&.prepend(IiifPrint::FileSetIndexerDecorator)

  # Versions 3.0+ of Hyrax have `Hyrax::ValkyrieFileSetIndexer` so we want to decorate that as
  # well.  We want to use the elsif construct because later on Hyrax::ValkyrieFileSetIndexer
  # inherits from Hyrax::Indexers::FileSetIndexer and only implements:
  # `def initialize(*args); super; end`
  'Hyrax::ValkyrieFileSetIndexer'.safe_constantize&.prepend(IiifPrint::FileSetIndexerDecorator)
else
  # The ActiveFedora::Base indexer for FileSets
  Hyrax::FileSetIndexer.prepend(IiifPrint::FileSetIndexerDecorator)
end
