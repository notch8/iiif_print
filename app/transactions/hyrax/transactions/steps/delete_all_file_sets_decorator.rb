# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.1
#   - add file_set.iiif_print_conditionally_destroy_spawned_children with user args
#   - skip file_set.remove_from_work when WorkDestroy can repair the work itself (samvera/hyrax#7682)
#   - fail without a user, as Hyrax does from samvera/hyrax#7682

module Hyrax
  module Transactions
    module Steps
      module DeleteAllFileSetsDecorator
        include Dry::Monads[:result]

        ##
        # @param [Valkyrie::Resource] resource
        # @param [::User] the user resposible for the delete action
        #
        # @return [Dry::Monads::Result]
        def call(resource, user: nil)
          return Failure(:resource_not_persisted) unless resource.persisted?

          # OVERRIDE: iiif_print step args, and remove_from_work only when needed
          destroy = iiif_print_file_set_destroy(user: user)
          @query_service.custom_queries.find_child_file_sets(resource: resource).each do |file_set|
            # OVERRIDE: require a user
            return Failure[:failed_to_delete_file_set, file_set] unless user && destroy.call(file_set).success?
          rescue ::Ldp::Gone
            nil
          end

          Success(resource)
        end

        private

        def iiif_print_file_set_destroy(user:)
          transaction = Hyrax::Transactions::Container['file_set.destroy'].dup
          step_args = { 'file_set.delete' => { user: user },
                        'file_set.iiif_print_conditionally_destroy_spawned_children' => { user: user } }
          if work_destroy_repairs_members?
            # The work is about to be deleted; removing each file set from it would only re-save
            # and re-index it, and queue update events for an object that will be gone.
            transaction.steps -= ['file_set.remove_from_work']
          else
            step_args['file_set.remove_from_work'] = { user: user }
          end
          transaction.with_step_args(**step_args)
        end

        # Without this repair, a failed later step would leave the surviving work listing
        # file sets that no longer exist, so they must be removed from it as they go.
        def work_destroy_repairs_members?
          Hyrax::Transactions::WorkDestroy.private_method_defined?(:remove_missing_members)
        end
      end
    end
  end
end

"Hyrax::Transactions::Steps::DeleteAllFileSets".safe_constantize&.prepend(Hyrax::Transactions::Steps::DeleteAllFileSetsDecorator)
