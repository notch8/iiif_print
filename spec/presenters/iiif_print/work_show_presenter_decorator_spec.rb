# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IiifPrint::WorkShowPresenterDecorator do
  before { allow(Deprecation).to receive(:warn) }

  it 'warns that it is deprecated when prepended' do
    Class.new.prepend(described_class)
    expect(Deprecation).to have_received(:warn).with(described_class, /IiifPrint 4\.0/)
  end

  it 'warns that it is deprecated when included' do
    Class.new.include(described_class)
    expect(Deprecation).to have_received(:warn).with(described_class, /IiifPrint 4\.0/)
  end
end
