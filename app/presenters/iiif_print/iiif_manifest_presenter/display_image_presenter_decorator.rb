module IiifPrint
  module IiifManifestPresenter
    module DisplayImagePresenterDecorator
      # Hyrax defines attr_writer :hostname but not the reader; we add the full accessor.
      attr_accessor :base_url

      # The three methods below are defined directly on DisplayImagePresenter in recent Hyrax.
      # We keep them here as fallbacks for older Hyrax versions via `super rescue NoMethodError`:
      #   - Recent Hyrax: super succeeds silently, no deprecation noise.
      #   - Older Hyrax:  super raises NoMethodError, deprecation fires, fallback value returned.
      # These fallbacks will be removed in the next major version of iiif_print.

      def ability
        super
      rescue NoMethodError
        Deprecation.warn(self.class,
          "IiifPrint is providing #ability as a fallback for older Hyrax versions. " \
          "This fallback will be removed in the next major iiif_print version — " \
          "please upgrade to a version of Hyrax that defines this method on DisplayImagePresenter.")
        @ability ||= Hyrax::IiifManifestPresenter::NullAbility.new
      end

      def hostname
        super
      rescue NoMethodError
        Deprecation.warn(self.class,
          "IiifPrint is providing #hostname as a fallback for older Hyrax versions. " \
          "This fallback will be removed in the next major iiif_print version — " \
          "please upgrade to a version of Hyrax that defines this method on DisplayImagePresenter.")
        @hostname || 'localhost'
      end

      def work?
        super
      rescue NoMethodError
        Deprecation.warn(self.class,
          "IiifPrint is providing #work? as a fallback for older Hyrax versions. " \
          "This fallback will be removed in the next major iiif_print version — " \
          "please upgrade to a version of Hyrax that defines this method on DisplayImagePresenter.")
        false
      end
    end
  end
end
Hyrax::IiifManifestPresenter::DisplayImagePresenter.prepend(IiifPrint::IiifManifestPresenter::DisplayImagePresenterDecorator)
