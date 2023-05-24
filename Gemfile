source 'https://rubygems.org'

# Please see iiif_print.gemspec for dependency information.
gemspec

group :development, :test do
  gem 'derivative_rodeo', git: "https://github.com/scientist-softserv/derivative_rodeo.git", branch: "main"
  gem 'active-fedora', git: "https://github.com/scientist-softserv/active_fedora.git", branch: "13.3.x-loosening-faraday-requirements"
  gem 'valkyrie', git: "https://github.com/scientist-softserv/valkyrie.git", branch: "loosening-faraday-requirements"
  gem 'coveralls', require: false
end

# BEGIN ENGINE_CART BLOCK
# engine_cart: 2.5.0
# engine_cart stanza: 2.5.0
# the below comes from engine_cart, a gem used to test this Rails engine gem in the context of a Rails app.
file = File.expand_path('Gemfile', ENV['ENGINE_CART_DESTINATION'] || ENV['RAILS_ROOT'] || File.expand_path('.internal_test_app', File.dirname(__FILE__)))
if File.exist?(file)
  begin
    eval_gemfile file
  rescue Bundler::GemfileError => e
    Bundler.ui.warn '[EngineCart] Skipping Rails application dependencies:'
    Bundler.ui.warn e.message
  end
else
  Bundler.ui.warn "[EngineCart] Unable to find test application dependencies in #{file}, using placeholder dependencies"

  if ENV['RAILS_VERSION']
    if ENV['RAILS_VERSION'] == 'edge'
      gem 'rails', github: 'rails/rails'
      ENV['ENGINE_CART_RAILS_OPTIONS'] = '--edge --skip-turbolinks'
    else
      gem 'rails', ENV['RAILS_VERSION']
    end

    case ENV['RAILS_VERSION']
    when /^6.0/
      gem 'sass-rails', '>= 6'
      gem 'webpacker', '~> 4.0'
    when /^5.[12]/
      gem 'sass-rails', '~> 5.0'
      gem 'sprockets', '~> 3.7'
      gem 'thor', '~> 0.20'
    when /^4.2/
      gem 'coffee-rails', '~> 4.1.0'
      gem 'responders', '~> 2.0'
      gem 'sass-rails', '>= 5.0'
    when /^4.[01]/
      # rubocop:disable Bundler/DuplicatedGem
      gem 'sass-rails', '< 5.0'
      # rubocop:enable Bundler/DuplicatedGem
    end
  end
end
# END ENGINE_CART BLOCK
