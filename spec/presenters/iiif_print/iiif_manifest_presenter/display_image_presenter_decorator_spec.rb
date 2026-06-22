require 'spec_helper'

RSpec.describe IiifPrint::IiifManifestPresenter::DisplayImagePresenterDecorator do
  # Simulates a Hyrax version that does NOT define ability/hostname/work? on
  # DisplayImagePresenter. Lets us exercise the NoMethodError rescue path without
  # actually downgrading Hyrax.
  let(:legacy_class) do
    Class.new { prepend IiifPrint::IiifManifestPresenter::DisplayImagePresenterDecorator }
  end
  let(:legacy_presenter) { legacy_class.new }

  # Simulates a Hyrax version that DOES define ability/hostname/work? on DisplayImagePresenter.
  # We can't rely on the bundled Hyrax for this since older versions don't define them.
  let(:current_class) do
    Class.new do
      def ability; Hyrax::IiifManifestPresenter::NullAbility.new; end
      def hostname; 'hyrax-hostname'; end
      def work?; false; end
    end.tap { |k| k.prepend(IiifPrint::IiifManifestPresenter::DisplayImagePresenterDecorator) }
  end
  let(:current_presenter) { current_class.new }

  shared_examples 'a deprecated fallback method' do |method, expected_value|
    context 'when the base class does not define the method (old Hyrax)' do
      it 'returns the fallback value' do
        expect(legacy_presenter.public_send(method)).to eq expected_value
      end

      it 'emits a deprecation warning' do
        expect(Deprecation).to receive(:warn)
        legacy_presenter.public_send(method)
      end
    end

    context 'when the base class defines the method (current Hyrax)' do
      it 'delegates to super without emitting a deprecation warning' do
        expect(Deprecation).not_to receive(:warn)
        current_presenter.public_send(method)
      end
    end
  end

  describe '#ability' do
    context 'when the base class does not define the method (old Hyrax)' do
      it 'returns a NullAbility instance' do
        expect(legacy_presenter.ability).to be_a(Hyrax::IiifManifestPresenter::NullAbility)
      end

      it 'emits a deprecation warning' do
        expect(Deprecation).to receive(:warn)
        legacy_presenter.ability
      end
    end

    context 'when the base class defines the method (current Hyrax)' do
      it 'delegates to super without emitting a deprecation warning' do
        expect(Deprecation).not_to receive(:warn)
        current_presenter.ability
      end
    end
  end

  describe '#hostname' do
    include_examples 'a deprecated fallback method', :hostname, 'localhost'
  end

  describe '#work?' do
    include_examples 'a deprecated fallback method', :work?, false
  end

  describe '#base_url' do
    it 'provides a read/write accessor absent from Hyrax' do
      current_presenter.base_url = 'https://example.com'
      expect(current_presenter.base_url).to eq 'https://example.com'
    end
  end
end
