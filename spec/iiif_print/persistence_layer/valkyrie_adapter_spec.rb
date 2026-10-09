# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IiifPrint::PersistenceLayer::ValkyrieAdapter do
  describe '.solr_construct_query' do
    it 'still builds the query, with a deprecation warning' do
      allow(Deprecation).to receive(:warn)
      expect(described_class.solr_construct_query(is_child_bsi: 'true'))
        .to eq Hyrax::SolrQueryBuilderService.construct_query(is_child_bsi: 'true')
      expect(Deprecation).to have_received(:warn).with(described_class, /IiifPrint 4\.0/)
    end
  end

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
      let(:destroy) { double('work_resource.destroy') }
      let(:system_user) { double('User') }

      before do
        allow(work).to receive(:member_ids=)
        allow(Hyrax.persister).to receive(:save)
        allow(Hyrax.persister).to receive(:delete)
        allow(Hyrax.index_adapter).to receive(:save)
        allow(Hyrax.index_adapter).to receive(:delete)
        allow(Hyrax.publisher).to receive(:publish)
        allow(Hyrax::Transactions::Container).to receive(:[]).and_call_original
        allow(Hyrax::Transactions::Container).to receive(:[]).with('work_resource.destroy').and_return(destroy)
        allow(destroy).to receive(:with_step_args).and_return(destroy)
        allow(destroy).to receive(:call).and_return(Dry::Monads::Success(child))
        allow(::User).to receive(:system_user).and_return(system_user)
      end

      it 'removes the child from the members' do
        expect(subject).to be true
        expect(work).to have_received(:member_ids=).with([file_set.id])
      end

      it "destroys the child as a work, so its own file sets go with it" do
        subject
        expect(destroy).to have_received(:call).with(child)
        expect(Hyrax.persister).not_to have_received(:delete)
      end

      it 'attributes the deletion to the system user when no user is given' do
        subject
        expect(destroy).to have_received(:with_step_args)
          .with('work_resource.delete_all_file_sets' => { user: system_user }, 'work_resource.delete' => { user: system_user })
      end

      context 'with a user' do
        subject { described_class.destroy_children_split_from(file_set: file_set, work: work, model: nil, user: user) }

        let(:user) { double('User') }

        it 'attributes the deletion to that user' do
          subject
          expect(destroy).to have_received(:with_step_args)
            .with('work_resource.delete_all_file_sets' => { user: user }, 'work_resource.delete' => { user: user })
        end
      end
    end
  end
end
