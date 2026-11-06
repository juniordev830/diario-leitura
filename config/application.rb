require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)
module DiarioLeitura
 class Application < Rails::Application
  config.load_defaults 7.2
  config.api_only = true
  config.secret_key_base = ENV.fetch("SECRET_KEY_BASE", "local-only-test-key") unless Rails.env.production?
 end
end
