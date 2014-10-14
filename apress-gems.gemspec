# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'apress/gems/version'

Gem::Specification.new do |spec|
  spec.name          = 'apress-gems'
  spec.version       = Apress::Gems::VERSION
  spec.authors       = ['merkushin']
  spec.email         = ['merkushin.m.s@gmail.com']
  spec.summary       = 'Набор rake задач дял выпуска гема на railsc.ru'
  spec.description   = 'Обязательно подключаемый гем для всех гемов apress-*'
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '>= 1.6'
  spec.add_development_dependency 'rake'
  spec.add_runtime_dependency 'changelogger', '= 0.0.2' # rails3.1 thor 0.14.16
  spec.add_runtime_dependency 'multipart-post'
end
