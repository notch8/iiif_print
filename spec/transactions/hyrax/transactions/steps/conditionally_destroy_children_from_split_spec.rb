# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrax::Transactions::Steps::ConditionallyDestroyChildrenFromSplit do
  describe '#call' do
    let(:file_set) { double(Hyrax::FileSet, persisted?: persisted) }
    subject { described_class.new.call(file_set) }

    describe 'with an unsaved resource' do
      let(:persisted) { false }
      it { is_expected.to be_failure }
    end

    describe 'with a saved resource' do
      let(:persisted) { true }
      before { expect(IiifPrint.persistence_adapter).to receive(:parent_for).and_return(parent) }

      context 'without a parent' do
        let(:parent) { nil }
        it { is_expected.to be_success }

        it 'returns the file_set resource' do
          expect(subject.value!).to eq(file_set)
        end
      end

      context 'with a parent' do
        let(:parent) { double(Valkyrie::Resource) }
        it do
          expect(IiifPrint::SplitPdfs::DestroyPdfChildWorksService).to receive(:conditionally_destroy_spawned_children_of)
            .with(file_set: file_set, work: parent, user: nil)
          is_expected.to be_success
        end

        it 'returns the file_set resource' do
          expect(IiifPrint::SplitPdfs::DestroyPdfChildWorksService).to receive(:conditionally_destroy_spawned_children_of)
            .with(file_set: file_set, work: parent, user: nil)
          expect(subject.value!).to eq(file_set)
        end
      end
    end
  end
end
