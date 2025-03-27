# frozen_string_literal: true

module IiifPrint
  module WorkShowPresenterDecorator
    delegate :member_ids, to: :solr_document
    alias file_set_ids member_ids

    # OVERRIDE Hyrax 2.9.6 to remove check for representative_presenter.image?
    # @return [Boolean] render a IIIF viewer
    def iiif_viewer?
      Hyrax.config.iiif_image_server? &&
        representative_id.present? &&
        representative_presenter.present? &&
        members_include_viewable_image?
    end

    alias universal_viewer? iiif_viewer?

    private

    # overriding Hyrax to include file sets for both work and child works (file set ids include both)
    # process each id, short-circuiting the loop once one true value is found. This speeds up the test
    # by not loading more member_presenters than needed.
    #
    # @todo Review if this is necessary for Hyrax 5.
    def members_include_viewable_image?
      all_member_ids = load_file_set_ids(solr_document)
      Array.wrap(all_member_ids).each do |id|
        return true if file_type_and_permissions_valid?(member_presenters_for([id]).first)
      end
      false
    end

    def load_file_set_ids(solr_doc)
      solr_doc.try(:descendent_member_ids_ssim) ||
        solr_doc.try(:[], 'descendent_member_ids_ssim') ||
        solr_doc.try(:member_ids_ssim) ||
        solr_doc.try(:[], 'member_ids_ssim')
    end

    # This method allows for overriding to add additional file types to mix in with IiifAv
    # TODO: add configuration setting for file types to loop through so an override is unneeded.
    def file_type_and_permissions_valid?(presenter)
      current_ability.can?(:read, presenter.id) &&
        (presenter.try(:image?) || presenter.try(:solr_document).try(:image?))
    end
  end
end
