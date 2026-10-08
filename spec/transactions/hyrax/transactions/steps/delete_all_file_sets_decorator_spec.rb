# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrax::Transactions::Steps::DeleteAllFileSetsDecorator do
  subject(:result) { step.call(work, user: user) }

  let(:user) { double('User') }
  let(:work) { double('Work', persisted?: true) }
  let(:file_set) { double('FileSet') }
  let(:query_service) { double('QueryService', custom_queries: custom_queries) }
  let(:custom_queries) { double('CustomQueries', find_child_file_sets: [file_set]) }
  let(:transaction) do
    double('file_set.destroy', steps: ['file_set.iiif_print_conditionally_destroy_spawned_children',
                                       'file_set.remove_from_work', 'file_set.delete'])
  end
  let(:step) { step_class.new(query_service) }
  let(:step_class) do
    klass = Class.new do
      def initialize(query_service)
        @query_service = query_service
      end

      def call(*)
        raise 'the decorator should not defer to the original step'
      end
    end
    klass.prepend(described_class)
  end
  let(:work_destroy) { Class.new }

  before do
    stub_const('Hyrax::Transactions::WorkDestroy', work_destroy)
    allow(Hyrax::Transactions::Container).to receive(:[]).and_call_original
    allow(Hyrax::Transactions::Container).to receive(:[]).with('file_set.destroy').and_return(transaction)
    allow(transaction).to receive(:dup).and_return(transaction)
    allow(transaction).to receive(:steps=)
    allow(transaction).to receive(:with_step_args).and_return(transaction)
    allow(transaction).to receive(:call).and_return(Dry::Monads::Success(file_set))
  end

  context 'when the work destroy transaction repairs a work whose file sets were deleted' do
    let(:work_destroy) do
      Class.new do
        private

        def remove_missing_members(_resource); end
      end
    end

    it 'destroys each file set without removing it from the work being deleted' do
      expect(result).to be_success
      expect(transaction).to have_received(:steps=).with(['file_set.iiif_print_conditionally_destroy_spawned_children', 'file_set.delete'])
      expect(transaction).to have_received(:with_step_args).with(
        'file_set.delete' => { user: user },
        'file_set.iiif_print_conditionally_destroy_spawned_children' => { user: user }
      )
      expect(transaction).to have_received(:call).with(file_set)
    end
  end

  context 'when the work destroy transaction cannot repair the work' do
    it 'still removes each file set from the work first' do
      expect(result).to be_success
      expect(transaction).not_to have_received(:steps=)
      expect(transaction).to have_received(:with_step_args).with(
        'file_set.remove_from_work' => { user: user },
        'file_set.delete' => { user: user },
        'file_set.iiif_print_conditionally_destroy_spawned_children' => { user: user }
      )
    end
  end

  context 'without a user' do
    let(:user) { nil }

    it 'fails before destroying anything' do
      expect(result).to be_failure
      expect(transaction).not_to have_received(:call)
    end
  end

  context 'when a file set fails to destroy' do
    before { allow(transaction).to receive(:call).and_return(Dry::Monads::Failure(:boom)) }

    it 'fails with that file set' do
      expect(result.failure).to eq [:failed_to_delete_file_set, file_set]
    end
  end
end
