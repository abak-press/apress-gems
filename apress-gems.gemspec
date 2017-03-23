# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'apress/gems/version'

Gem::Specification.new do |spec|
  spec.name          = 'apress-gems'
  spec.version       = Apress::Gems::VERSION
  spec.authors       = ['merkushin']
  spec.email         = ['merkushin.m.s@gmail.com']
  spec.summary       = 'CLI tool для выпуска гема на railsc.ru'
  spec.homepage      = 'https://github.com/abak-press/apress-gems/fork'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.metadata['allowed_push_host'] = 'https://gems.railsc.ru'

  spec.add_runtime_dependency 'apress-changelogger'
  spec.add_runtime_dependency 'multipart-post'
  spec.add_runtime_dependency 'bundler'

  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'fakefs'
end
