# frozen_string_literal: true

# OVERRIDE: Blacklight IIIF Search v1.0.0
# IiifSearchDecorator module extends the functionality of the BlacklightIiifSearch::IiifSearch class
# by overriding the solr_params method to modify the search query to include the parent's metadata.
module IiifPrint
  module IiifSearchDecorator
    ##
    # Overrides the solr_params method from BlacklightIiifSearch::IiifSearch to modify the search query.
    # The method adds an additional filter to the query to include either the object_relation_field OR the
    # parent document's id and removes the :f parameter from the query.
    # :object_relation_field refers to the CatalogController's configuration which is typically set to
    # 'is_page_of_ssim' in the host application which only searches child works by default.
    #
    #   config.iiif_search = {
    #     full_text_field: 'all_text_tsimv',
    #     object_relation_field: 'is_page_of_ssim',
    #     supported_params: %w[q page],
    #     autocomplete_handler: 'iiif_suggest',
    #     suggester_name: 'iiifSuggester'
    #   }
    #
    # @return [Hash] A hash containing the modified Solr search parameters
    #
    def solr_params
      return { q: 'nil:nil' } unless q

      {
        q: "#{q} AND has_model_ssim:FileSet AND (#{iiif_config[:object_relation_field]}:\"#{parent_document.id}\" OR id:\"#{parent_document.id}\")",
        rows: rows,
        page: page
      }
    end
  end
end
::BlacklightIiifSearch::IiifSearch.prepend(IiifPrint::IiifSearchDecorator)
