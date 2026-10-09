# frozen_string_literal: true

# Overrides Hyrax to add show_parents_only to processor chain
module IiifPrint
  class HomepageSearchBuilder < Hyrax::HomepageSearchBuilder
    self.default_processor_chain += [:show_parents_only]

    def show_parents_only(solr_parameters)
      query = if blacklight_params["include_child_works"] == 'true'
                IiifPrint.solr_construct_query(is_child_bsi: 'true')
              else
                # Only child works are left out; a work indexed with is_child_bsi false is not a child.
                '-is_child_bsi:true'
              end
      solr_parameters[:fq] += [query]
    end
  end
end
