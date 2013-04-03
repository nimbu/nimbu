# -*- encoding : utf-8 -*-
require "fileutils"
require "nimbu/auth"
require "nimbu/command"

class Nimbu::Command::Base
  include Nimbu::Helpers

  def self.namespace
    self.to_s.split("::").last.downcase
  end

  attr_reader :args
  attr_reader :options

  def initialize(args=[], options={})
    @args = args
    @options = options
  end

  def nimbu
    Nimbu::Auth.client
  end

protected

  def self.inherited(klass)
    unless klass == Nimbu::Command::Base
      help = extract_help_from_caller(caller.first)

      Nimbu::Command.register_namespace(
        :name => klass.namespace,
        :description => help.first
      )
    end
  end

  def self.method_added(method)
    return if self == Nimbu::Command::Base
    return if private_method_defined?(method)
    return if protected_method_defined?(method)

    help = extract_help_from_caller(caller.first)
    resolved_method = (method.to_s == "index") ? nil : method.to_s
    command = [ self.namespace, resolved_method ].compact.join(":")
    banner = extract_banner(help) || command

    Nimbu::Command.register_command(
      :klass       => self,
      :method      => method,
      :namespace   => self.namespace,
      :command     => command,
      :banner      => banner.strip,
      :help        => help.join("\n"),
      :summary     => extract_summary(help),
      :description => extract_description(help),
      :options     => extract_options(help)
    )
  end

  def self.alias_command(new, old)
    raise "no such command: #{old}" unless Nimbu::Command.commands[old]
    Nimbu::Command.command_aliases[new] = old
  end

  def extract_app
    output_with_bang "Command::Base#extract_app has been deprecated. Please use Command::Base#app instead.  #{caller.first}"
    app
  end

  def self.extract_help_from_caller(line)
    # pull out of the caller the information for the file path and line number
    if line =~ /^(.+?):(\d+)/
      return extract_help($1, $2)
    end
    raise "unable to extract help from caller: #{line}"
  end

  def self.extract_help(file, line_number)
    buffer = []
    lines = Nimbu::Command.files[file]

    (line_number.to_i-2).downto(0) do |i|
      line = lines[i]
      case line[0..0]
        when ""
        when "#"
          buffer.unshift(line[1..-1])
        else
          break
      end
    end

    buffer
  end

  def self.extract_banner(help)
    help.first
  end

  def self.extract_summary(help)
    extract_description(help).split("\n")[2].to_s.split("\n").first
  end

  def self.extract_description(help)
    help.reject do |line|
      line =~ /^\s+-(.+)#(.+)/
    end.join("\n")
  end

  def self.extract_options(help)
    help.select do |line|
      line =~ /^\s+-(.+)#(.+)/
    end.inject([]) do |options, line|
      args = line.split('#', 2).first
      args = args.split(/,\s*/).map {|arg| arg.strip}.sort.reverse
      name = args.last.split(' ', 2).first[2..-1]
      options << { :name => name, :args => args }
    end
  end

  def extract_option(name, default=true)
    key = name.gsub("--", "").to_sym
    return unless options[key]
    value = options[key] || default
    block_given? ? yield(value) : value
  end

  def confirm_mismatch?
    options[:confirm] && (options[:confirm] != options[:app])
  end

  def current_command
    Nimbu::Command.current_command
  end

  def extract_app_in_dir(dir)
    return unless remotes = git_remotes(dir)

    if remote = options[:remote]
      remotes[remote]
    elsif remote = extract_app_from_git_config
      remotes[remote]
    else
      apps = remotes.values.uniq
      return apps.first if apps.size == 1
    end
  end

  def extract_app_from_git_config
    remote = git("config nimbu.remote")
    remote == "" ? nil : remote
  end

  def git_remotes(base_dir=Dir.pwd)
    remotes = {}
    original_dir = Dir.pwd
    Dir.chdir(base_dir)

    git("remote -v").split("\n").each do |remote|
      name, url, method = remote.split(/\s/)
      if url =~ /^git@#{nimbu.host}:([\w\d-]+)\.git$/
        remotes[name] = $1
      end
    end

    Dir.chdir(original_dir)
    remotes
  end

  def escape(value)
    nimbu.escape(value)
  end
end

module Nimbu::Command
  unless const_defined?(:BaseWithApp)
    BaseWithApp = Base
  end
end
