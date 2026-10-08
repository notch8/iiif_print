# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IiifPrint::Engine do
  describe 'preparing the application again, as a code reload does' do
    def iiif_print_listeners
      Hyrax.publisher.__bus__.listeners['file.characterized'].count do |listener, _filter|
        listener.is_a?(Method) && listener.receiver.class.name == 'IiifPrint::Listener'
      end
    end

    it 'leaves a single IiifPrint::Listener subscribed' do
      2.times { Rails.application.reloader.prepare! }

      expect(iiif_print_listeners).to eq 1
    end

    it 'lists the pluggable derivative service once' do
      2.times { Rails.application.reloader.prepare! }

      expect(Hyrax::DerivativeService.services.count(IiifPrint::PluggableDerivativeService)).to eq 1
    end
  end
end
