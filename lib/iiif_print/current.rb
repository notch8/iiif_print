# frozen_string_literal: true

module IiifPrint
  ##
  # Per-request state.  Rails resets it around every request and job, where RequestStore was only cleared by its
  # Rack middleware and so lived as long as a job's thread.
  class Current < ActiveSupport::CurrentAttributes
    attribute :anonymous_ability, :presenters, :view_definitions
  end
end
