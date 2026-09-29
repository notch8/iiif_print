# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IiifPrint::PersistenceLayer::ValkyrieAdapter do
  describe '.destroy_children_split_from' do
    subject { described_class.destroy_children_split_from(file_set: file_set, work: work, model: nil, user: nil) }

    let(:file_set) { double('FileSet', id: Valkyrie::ID.new('fs1')) }
    let(:child) { double('Child', id: Valkyrie::ID.new('child1'), split_from_pdf_id: file_set.id) }
    let(:work) { double('Work', member_ids: [file_set.id, child.id]) }

    # Valkyrie's Postgres query service returns lazy enumerators
    before do
      allow(Hyrax.custom_queries).to receive(:find_child_works).with(resource: work).and_return(child_works.lazy)
    end

    context 'when the work has no child works' do
      let(:child_works) { [] }

      it 'returns without touching the work' do
        expect(work).not_to receive(:member_ids=)
        expect(subject).to be_nil
      end
    end

    context 'when a child work was split from the file set' do
      let(:child_works) { [child] }

      before do
        allow(work).to receive(:member_ids=)
        allow(Hyrax.persister).to receive(:save)
        allow(Hyrax.persister).to receive(:delete)
        allow(Hyrax.index_adapter).to receive(:save)
        allow(Hyrax.index_adapter).to receive(:delete)
        allow(Hyrax.publisher).to receive(:publish)
      end

      it 'removes the child from the members and deletes it' do
        expect(subject).to be true
        expect(work).to have_received(:member_ids=).with([file_set.id])
        expect(Hyrax.persister).to have_received(:delete).with(resource: child)
      end
    end
  end
end
