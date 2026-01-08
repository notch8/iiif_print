require 'spec_helper'

RSpec.describe ContentDepositErrorEventJob, type: :job do
  let(:user) { create(:user) }
  let(:work) { create(:newspaper_issue, title: ['Test Work']) }
  let(:error_reason) { 'OCR processing failed due to invalid file format' }

  describe '#perform' do
    it 'sets the reason and assigns attributes' do
      job = described_class.new

      # Mock the super method to avoid Redis dependencies
      allow_any_instance_of(ContentEventJob).to receive(:perform).and_return(true)

      job.perform(work, user, reason: error_reason)

      expect(job.reason).to eq(error_reason)
      expect(job.repo_object).to eq(work)
      expect(job.depositor).to eq(user)
    end

    it 'works with empty reason' do
      job = described_class.new

      # Mock the super method to avoid Redis dependencies
      allow_any_instance_of(ContentEventJob).to receive(:perform).and_return(true)

      job.perform(work, user)

      expect(job.reason).to eq('')
      expect(job.repo_object).to eq(work)
      expect(job.depositor).to eq(user)
    end
  end

  describe '#action' do
    before do
      # Mock the routing helpers to avoid missing route errors
      allow_any_instance_of(ContentDepositErrorEventJob).to receive(:polymorphic_path) do |instance, object|
        "/concern/newspaper_issues/#{object.id}"
      end
      allow_any_instance_of(ContentDepositErrorEventJob).to receive(:link_to_profile) do |instance, user|
        user.display_name || user.email
      end
      allow_any_instance_of(ContentDepositErrorEventJob).to receive(:link_to) do |instance, title, path|
        "#{title} (#{path})"
      end
    end

    it 'generates appropriate error message' do
      job = described_class.new
      job.repo_object = work
      job.depositor = user
      job.reason = error_reason

      expected_message = "User #{user.display_name || user.email} deposit of #{work.title.first} (/concern/newspaper_issues/#{work.id}) has failed for #{error_reason}"

      expect(job.action).to eq(expected_message)
    end

    it 'handles work with multiple titles' do
      work_with_titles = create(:newspaper_issue, title: ['First Title', 'Second Title'])
      job = described_class.new
      job.repo_object = work_with_titles
      job.depositor = user
      job.reason = error_reason

      message = job.action
      # Check that one of the titles appears in the message (title.first returns the first available title)
      expect(message).to include(work_with_titles.title.first)
      expect(message).to include(error_reason)
    end
  end

  describe 'job enqueueing' do
    it 'can be enqueued with perform_later' do
      expect do
        described_class.perform_later(work, user, reason: error_reason)
      end.to have_enqueued_job(described_class).with(work, user, reason: error_reason)
    end
  end
end
