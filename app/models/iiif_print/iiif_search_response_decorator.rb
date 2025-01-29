module IiifPrint
  module IiifSearchResponseDecorator
    # Enable the user to search for child metadata in the parent's UV
    # @see https://github.com/notch8/louisville-hyku/commit/67467e5cf9fdb755f54419f17d3c24c87032d0af
    def annotation_list
      json_results = super

      # Check and process invalid hit
      if json_results&.[]('resources')
        remove_invalid_hit(json_results)
        add_metadata_match(json_results)
      end

      json_results
    end

    def remove_invalid_hit(json_results)
      resources = json_results['resources']
      invalid_hit = resources.detect { |resource| resource["on"].include?(IiifPrint::BlacklightIiifSearch::AnnotationDecorator::INVALID_MATCH_TEXT) }
      return unless invalid_hit

      # Delete invalid hit from resources, remove first hit (which is from the invalid hit), decrement total within
      resources.delete(invalid_hit)
      json_results['hits'].shift
      json_results['within']['total'] -= 1
    end

    def add_metadata_match(json_results)
      json_results['resources'].each do |result_hit|
        next if result_hit['resource'].present?

        # Add resource details if not present
        result_hit['resource'] = {
          "@type": "cnt:ContentAsText",
          "chars": "Metadata match, see sidebar for details"
        }
      end
    end
  end
end
::BlacklightIiifSearch::IiifSearchResponse.prepend(IiifPrint::IiifSearchResponseDecorator)
