# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "nimbu/version"

Gem::Specification.new do |s|
  s.name        = "nimbu"
  s.version     = Nimbu::VERSION
  s.authors     = ["Zenjoy BVBA"]
  s.email       = ["support@getnimbu.com"]
  s.homepage    = "http://www.getnimbu.com"
  s.summary     = "Client library and CLI to design websites on the Nimbu platform."
  s.description = "Client library and command-line tool to design and manage websites on the Nimbu platform."

  s.files = %x{ git ls-files }.split("\n").select { |d| d =~ %r{^(README|bin/|data/|ext/|lib/|spec/|test/)} }
  s.executables = "nimbu"

  # specify any dependencies here; for example:
  s.add_dependency "term-ansicolor", "~> 1.0.5"
  s.add_dependency "rest-client",    "~> 1.6.1"
  s.add_dependency "launchy",        ">= 0.3.2"
  s.add_dependency "rubyzip"
end