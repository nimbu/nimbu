# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "nimbu/version"

Gem::Specification.new do |s|
  s.name        = "nimbu"
  s.version     = Nimbu::VERSION
  s.authors     = ["Zenjoy BVBA"]
  s.email       = ["support@nimbu.io"]
  s.homepage    = "https://www.nimbu.io"
  s.summary     = "Client library and CLI to design websites on the Nimbu platform."
  s.description = "Client library and command-line tool to design and manage websites on the Nimbu platform."

  s.files = %x{ git ls-files }.split("\n").select { |d| d =~ %r{^(README|bin/|data/|ext/|lib/|spec/|test/)} }
  s.executables = "nimbu"
  s.default_executable = "nimbu"

  # specify any dependencies here; for example:
  s.add_dependency "term-ansicolor", "~> 1.0.5"
  s.add_dependency "nimbu-api"
  s.add_dependency "rubyzip"
  s.add_dependency "sinatra"
  s.add_dependency "sinatra-contrib"
  s.add_dependency "listen"
  s.add_dependency "thin"
  s.add_dependency "rack-streaming-proxy"
  s.add_dependency "compass"
  s.add_dependency "haml"
  s.add_dependency "rack", "~> 1.5.2"

  s.add_development_dependency "bundler", "~> 1.3"
  s.add_development_dependency "rake"
  s.add_development_dependency "awesome_print"
  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-remote'
  s.add_development_dependency 'pry-stack_explorer'
  s.add_development_dependency 'pry-debugger'
end
