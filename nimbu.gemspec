# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'nimbu/version'

Gem::Specification.new do |s|
  s.name        = 'nimbu'
  s.version     = Nimbu::VERSION
  s.authors     = ['Zenjoy BVBA']
  s.email       = ['support@nimbu.io']
  s.homepage    = 'https://www.nimbu.io'
  s.summary     = 'Client library and CLI to design websites on the Nimbu platform.'
  s.description = 'Client library and command-line tool to design and manage websites on the Nimbu platform.'

  s.files = `git ls-files`.split("\n").select { |d| d =~ %r{^(README|bin/|data/|ext/|lib/|spec/|test/)} }
  s.executables = 'nimbu'

  # specify any dependencies here; for example:
  s.add_dependency 'term-ansicolor', '~> 1.0.5'
  s.add_dependency 'nimbu-api', '~> 0.4.4'
  s.add_dependency 'rubyzip'
  s.add_dependency 'sinatra', '~> 2.2.3'
  s.add_dependency 'sinatra-contrib'
  s.add_dependency 'rb-fsevent', '~> 0.9'
  s.add_dependency 'thin'
  s.add_dependency 'rack-streaming-proxy'
  s.add_dependency 'rack', '>= 2.1.4'
  s.add_dependency 'json'
  s.add_dependency 'diffy'
  s.add_dependency 'wdm'
  s.add_dependency 'netrc'
  s.add_dependency 'filewatcher'
  s.add_dependency 'lolcat'

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'awesome_print'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-remote'
  s.add_development_dependency 'pry-stack_explorer'
end
