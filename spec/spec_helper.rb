require 'simplecov'
SimpleCov.start
require 'bundler/setup'
Bundler.setup

require 'apress/gems'
require 'fakefs/spec_helpers'
require 'pry'

RSpec.configure do |config|
  config.include FakeFS::SpecHelpers
end
