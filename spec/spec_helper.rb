require 'rubygems'
require 'bundler'
require 'rails/all'

Bundler.require :default, :development

# Load factories
require 'factory_girl'
require 'ffaker'
Dir[Rails.root.join("spec/factories/*.rb")].each{ |f| require File.expand_path(f) }

Combustion.initialize!

require 'rspec/rails'

require 'rspec/autorun'
require 'fuubar'

RSpec.configure do |config|
  config.use_transactional_fixtures = true
end
