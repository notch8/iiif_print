require 'active_fedora'
require 'hyrax'
require 'blacklight_iiif_search'

module IiifPrint
  # module constants:
  GEM_PATH = Gem::Specification.find_by_name("iiif_print").gem_dir

  # Engine Class
  class Engine < ::Rails::Engine
    isolate_namespace IiifPrint

    # rubocop:disable Metrics/BlockLength
    config.to_prepare do
      # We don't have a hard requirement of Bullkrax but in our experience, lingering on earlier
      # versions can introduce bugs of both Bulkrax and some of the assumptions that we've resolved.
      # Very early versions of Bulkrax do not have VERSION defined
      if defined?(Bulkrax) && !ENV.fetch("SKIP_IIIF_PRINT_BULKRAX_VERSION_REQUIREMENT", false)
        if !defined?(Bulkrax::VERSION) || (Bulkrax::VERSION.to_i < 5)
          raise "IiifPrint does not have a hard dependency on Bulkrax, " \
                "but if you have Bulkrax installed we recommend at least version 5.0.0.  " \
                "To ignore this recommendation please add SKIP_IIIF_PRINT_BULKRAX_VERSION_REQUIREMENT " \
                "to your ENV variables."
        end
      end

      # Inject PluggableDerivativeService ahead of Hyrax default.
      #   This wraps Hyrax default, but allows multiple valid services
      #   to be configured, instead of just the _first_ valid service.
      #
      #   To configure specific services, inject each service, in desired order
      #   to IiifPrint::PluggableDerivativeService.plugins array.

      Hyrax::DerivativeService.services.unshift(
        IiifPrint::PluggableDerivativeService
      )

      Hyrax::IiifManifestPresenter.prepend(IiifPrint::IiifManifestPresenterBehavior)
      Hyrax::IiifManifestPresenter::Factory.prepend(IiifPrint::IiifManifestPresenterFactoryBehavior)
      Hyrax::ManifestBuilderService.prepend(IiifPrint::ManifestBuilderServiceBehavior)
      Hyrax::Renderers::FacetedAttributeRenderer.prepend(Hyrax::Renderers::FacetedAttributeRendererDecorator)
      Hyrax::WorksControllerBehavior.prepend(IiifPrint::WorksControllerBehaviorDecorator)
      Hyrax::WorkShowPresenter.prepend(IiifPrint::WorkShowPresenterDecorator)

      IiifPrint::ChildIndexer.decorate_work_types!
      IiifPrint::FileSetIndexer.decorate(Hyrax::FileSetIndexer)

      ::BlacklightIiifSearch::IiifSearchResponse.prepend(IiifPrint::IiifSearchResponseDecorator)
      ::BlacklightIiifSearch::IiifSearchAnnotation.prepend(IiifPrint::BlacklightIiifSearch::AnnotationDecorator)
      Hyrax::Actors::FileSetActor.prepend(IiifPrint::Actors::FileSetActorDecorator)

      # Extending the presenter to the base url which includes the protocol.
      # We need the base url to render the facet links and normalize the interface.
      Hyrax::IiifManifestPresenter.send(:attr_accessor, :base_url)
      Hyrax::IiifManifestPresenter::DisplayImagePresenter.send(:attr_accessor, :base_url)
      # Extending this class because there is an #ability= but not #ability and this definition
      # mirrors the Hyrax::IiifManifestPresenter#ability.
      module Hyrax::IiifManifestPresenter::DisplayImagePresenterDecorator
        def ability
          @ability ||= NullAbility.new
        end
      end
      Hyrax::IiifManifestPresenter::DisplayImagePresenter.prepend(Hyrax::IiifManifestPresenter::DisplayImagePresenterDecorator)

      Hyrax.config do |config|
        config.callback.set(:after_create_fileset) do |file_set, user|
          IiifPrint.config.handle_after_create_fileset(file_set, user)
        end
      end
    end

    config.after_initialize do
      IiifPrint::Solr::Document.decorate(SolrDocument)
    end
    # rubocop:enable Metrics/BlockLength
  end
end
