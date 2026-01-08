# frozen_string_literal: true
# Log a concern deposit error to activity streams
# This class is also being ported to Hyrax itself. It can be removed from here once Hyrax has it
class ContentDepositErrorEventJob < ContentEventJob
  attr_accessor :reason, :repo_object, :depositor

  def perform(repo_object, depositor, reason: '')
    self.reason = reason
    self.repo_object = repo_object
    self.depositor = depositor
    super(repo_object, depositor)
  end

  def action
    "User #{link_to_profile depositor} deposit of #{link_to repo_object.title.first, polymorphic_path(repo_object)} has failed for #{reason}"
  end
end
