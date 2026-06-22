# Adds base_url read accessor to DisplayImagePresenter.
# Hyrax defines attr_writer :hostname but not attr_accessor :base_url.
module IiifPrint
  module IiifManifestPresenter
    module DisplayImagePresenterDecorator
      attr_accessor :base_url
    end
  end
end
Hyrax::IiifManifestPresenter::DisplayImagePresenter.prepend(IiifPrint::IiifManifestPresenter::DisplayImagePresenterDecorator)
