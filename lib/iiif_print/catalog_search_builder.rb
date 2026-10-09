require 'hyrax/catalog_search_builder'

module IiifPrint
  # This class extends the base Hyrax::CatalogSearchBuilder by:
  #
  # - supporting highlighting of snippets in results
  # - excluding models from search result; with complex works you might want to skip some of those
  #   works.
  class CatalogSearchBuilder < Hyrax::CatalogSearchBuilder
    # TODO: Do we need the following as a module?  It hides the behavior
    include IiifPrint::HighlightSearchParams
    # TODO: Do we need the following as a module?  It hides the behavior
    include IiifPrint::ExcludeModels
    include IiifPrint::AllinsonFlexFields

    # NOTE: If you are using advanced_search, the :exclude_models and :highlight_search_params must
    # be added after the advanced_search methods (which are not part of this gem).  In other tests,
    # we found that having the advanced search processing after the two aforementioned processors
    # resulted in improper evaluation of keyword querying.
    self.default_processor_chain += [:exclude_models,
                                     :highlight_search_params,
                                     :show_parents_only,
                                     :include_allinson_flex_fields]

    # rubocop:enable Naming/PredicateName
    def show_parents_only(solr_parameters)
      return if blacklight_params["include_child_works"] == 'true'

      # Only child works are left out; a work indexed with is_child_bsi false is not a child.
      solr_parameters[:fq] += ['-is_child_bsi:true']
    end
  end
end
