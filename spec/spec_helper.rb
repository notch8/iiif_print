require 'json'

# testing environent:
ENV['RAILS_ENV'] ||= 'test'

require 'coveralls'
Coveralls.wear!

require 'shoulda/matchers'
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
  end
end

# engine_cart:
require 'bundler/setup'
require 'engine_cart'
EngineCart.load_application!

require 'rspec/rails'
require 'support/iiif_print_models'
require 'support/controller_level_helpers'
require 'rspec/active_model/mocks'

ActiveJob::Base.queue_adapter = :test

RSpec.configure do |config|
  # enable FactoryBot:
  require 'factory_bot'
  config.include FactoryBot::Syntax::Methods
  # auto-detect and load all factories in spec/factories:
  FactoryBot.find_definitions

  config.infer_spec_type_from_file_location!

  # Transactional
  config.use_transactional_fixtures = false
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.before { RequestStore.clear! }

  # ensure Hyrax has active sipity workflow for default admin set:
  config.before(:suite) do
    require 'active_fedora/cleaner'
    require 'database_cleaner'

    # By default, Hyrax uses a database minter class.  That's the preferred pathway (because you are
    # tracking minting state in the database).  However, for testing purposes we don't need to / nor
    # want to install the minter migrations.  Hence we're favoring this approach.
    minter_class = ::Noid::Rails::Minter::File
    ::Noid::Rails.config.minter_class = minter_class
    Hyrax.config.noid_minter_class = minter_class

    IiifPrint.clean_for_tests!
    DatabaseCleaner.clean_with(:truncation)

    begin
      # TODO: switch the below methods to use the appropriate services
      # rather than the deprecated methods currently being used.
      # ensure permission template actually exists in RDBMS:
      id = 'admin_set/default'
      no_template = Hyrax::PermissionTemplate.find_by(source_id: id).nil?
      Hyrax::PermissionTemplate.create!(source_id: id) if no_template
      # ensure workflows exist, presumes permission template does first:
      Hyrax::Workflow::WorkflowImporter.load_workflows
      # Default admin set needs to exist in Fedora, with relation to its
      #   PermissionTemplate object:
      begin
        admin_set = AdminSet.find(AdminSet.find_or_create_default_admin_set_id)
        admin_set.save!
      rescue ActiveRecord::RecordNotUnique
        admin_set = AdminSet.find(AdminSet::DEFAULT_ID)
      end
      permission_template = admin_set.permission_template
      workflow = permission_template.available_workflows.where(
        name: 'default'
      ).first
      Sipity::Workflow.activate!(
        permission_template: permission_template,
        workflow_id: workflow.id
      )
    rescue Faraday::ConnectionFailed
      STDERR.puts "Attempting to run test suite without Fedora and/or Solr..."
    end
  end

  # :perform_enqueued config setting below copied from Hyrax spec_helper.rb
  config.before(:example, :perform_enqueued) do |example|
    ActiveJob::Base.queue_adapter.filter = example.metadata[:perform_enqueued].try(:to_a)
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
    ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = true
  end
  config.after(:example, :perform_enqueued) do
    ActiveJob::Base.queue_adapter.filter = nil
    ActiveJob::Base.queue_adapter.enqueued_jobs = []
    ActiveJob::Base.queue_adapter.performed_jobs = []
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = false
    ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = false
  end
  config.after(:suite) do # or :each or :all
    FileUtils.rm_rf(Dir[Rails.root.join('tmp', 'derivatives', '*')])
  end

  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # This option will default to `:apply_to_host_groups` in RSpec 4 (and will
  # have no way to turn it off -- the option exists only for backwards
  # compatibility in RSpec 3). It causes shared context metadata to be
  # inherited by the metadata hash of host groups and examples, rather than
  # triggering implicit auto-inclusion in groups with matching metadata.
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # The settings below are suggested to provide a good initial experience
  # with RSpec, but feel free to customize to your heart's content.

  # This allows you to limit a spec run to individual examples or groups
  # you care about by tagging them with `:focus` metadata. When nothing
  # is tagged with `:focus`, all examples get run. RSpec also provides
  # aliases for `it`, `describe`, and `context` that include `:focus`
  # metadata: `fit`, `fdescribe` and `fcontext`, respectively.
  # config.filter_run_when_matching :focus

  # Allows RSpec to persist some state between runs in order to support
  # the `--only-failures` and `--next-failure` CLI options. We recommend
  # you configure your source control system to ignore this file.
  # config.example_status_persistence_file_path = "spec/examples.txt"

  # Limits the available syntax to the non-monkey patched syntax that is
  # recommended. For more details, see:
  #   - http://rspec.info/blog/2012/06/rspecs-new-expectation-syntax/
  #   - http://www.teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/
  #   - http://rspec.info/blog/2014/05/notable-changes-in-rspec-3/#zero-monkey-patching-mode
  # config.disable_monkey_patching!

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  # if config.files_to_run.one?
  # Use the documentation formatter for detailed output,
  # unless a formatter has already been configured
  # (e.g. via a command-line flag).
  #  config.default_formatter = "doc"
  # end

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  config.profile_examples = 10

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed
end
