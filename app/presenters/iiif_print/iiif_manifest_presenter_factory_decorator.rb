module IiifPrint
  module IiifManifestPresenterFactoryDecorator
    # This will override Hyrax::IiifManifestPresenter::Factory#build and introducing
    # the expected behavior:
    # - child work images show as canvases in the parent work manifest
    # - child work images show in the uv on the parent show page
    # - still create the manifest if the parent work has images attached but the child works do not
    def build
      ids.map do |id|
        solr_doc = load_docs.find { |doc| doc.id == id }
        next unless solr_doc

        if solr_doc.file_set?
          presenter_class.for(solr_doc)
        elsif Hyrax.config.curation_concerns.include?(solr_doc.hydra_model)
          # look up file set ids and loop through those
          file_set_docs = load_file_set_docs(load_file_set_ids(solr_doc))
          file_set_docs.map { |doc| presenter_class.for(doc) } if file_set_docs.length
        end
      end.flatten.compact
    end

    private

    def load_file_set_ids(solr_doc)
      solr_doc.try(:descendent_member_ids_ssim) ||
        solr_doc.try(:[], 'descendent_member_ids_ssim') ||
        solr_doc.try(:member_ids_ssim) ||
        solr_doc.try(:[], 'member_ids_ssim')
    end

    # still create the manifest if the parent work has images attached but the child works do not
    def load_file_set_docs(file_set_ids)
      return [] if file_set_ids.nil?

      query("{!terms f=id}#{file_set_ids.join(',')}", rows: 1000)
        .map { |res| ::SolrDocument.new(res) }
    end
  end
end
Hyrax::IiifManifestPresenter::Factory.prepend(IiifPrint::IiifManifestPresenterFactoryDecorator)
