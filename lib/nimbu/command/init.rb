# -*- encoding : utf-8 -*-
require "nimbu/command/base"
require 'term/ansicolor'

# working directory initialization
#
class Nimbu::Command::Init < Nimbu::Command::Base
  include Term::ANSIColor

  # index
  #
  # initialize your working directory to code a selected theme
  #
  def index
    if Nimbu::Auth.read_configuration && Nimbu::Auth.read_credentials
      print green(bold("CONGRATULATIONS!")), ": this directory is already configured as a Nimbu theme."
    else
      credentials = Nimbu::Auth.get_credentials

      display "Initializing the Nimbu configuration file."
      config = Nimbu::Auth.get_configuration

      display "Initializing directories:"
      display " - layouts"
      FileUtils.mkdir_p(File.join(Dir.pwd,'layouts'))
      display " - templates"
      FileUtils.mkdir_p(File.join(Dir.pwd,'templates'))
      display " - stylesheets"
      FileUtils.mkdir_p(File.join(Dir.pwd,'stylesheets'))
      display " - javascripts"
      FileUtils.mkdir_p(File.join(Dir.pwd,'javascripts'))
      display " - images"
      FileUtils.mkdir_p(File.join(Dir.pwd,'images'))
      print green(bold("Done. Happy coding!\n"))
    end
  end
end

