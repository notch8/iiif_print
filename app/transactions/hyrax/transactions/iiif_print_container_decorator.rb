# frozen_string_literal: true

begin
  require 'dry/container'
rescue LoadError
  nil
end

# dry-transaction >= 0.15 dropped dry-container, so Dry::Container::Mixin is unavailable in those
# environments. Guard the entire decorator so iiif_print still boots in Hyrax 2.x / newer dry-rb.
return unless defined?(Dry::Container)

module Hyrax
  module Transactions
    ##
    # This decorator does the following:
    #
    # - Prepend the {ConditionallyDestroyChildrenFromSplit} transaction to the "file_set.destroy"
    #   step.  The prependment corresponds to the behavior for
    #   {IiifPrint::Actors::FileSetActorDecorator#destroy}
    #
    # For more information about adjusting transactions, see
    # [Transitioning workshop solution for adding transaction](https://github.com/samvera-labs/transitioning-to-valkyrie-workshop/commit/bcab2bb8f65078e88395c68f72be00e7ffad57ec)
    #
    # @see https://github.com/samvera/hyrax/blob/f875d61dc87229cf1f05eb2bb6d414b5ef314616/lib/hyrax/transactions/container.rb
    class IiifPrintContainerDecorator
      extend Dry::Container::Mixin

      namespace 'file_set' do |ops|
        ops.register 'iiif_print_conditionally_destroy_spawned_children' do
          Steps::ConditionallyDestroyChildrenFromSplit.new
        end
        ops.register 'destroy' do
          Hyrax::Transactions::FileSetDestroy.new(
            steps: (['file_set.iiif_print_conditionally_destroy_spawned_children'] +
              Hyrax::Transactions::FileSetDestroy::DEFAULT_STEPS)
          )
        end
      end
    end
  end
end

"Hyrax::Transactions::Container".safe_constantize&.merge(Hyrax::Transactions::IiifPrintContainerDecorator)
