require "nimbu/command/base"
require "nimbu/server/base"
require 'term/ansicolor'

# running a local server to speed up designing Nimbu themes
#
class Nimbu::Command::Server < Nimbu::Command::Base
  include Term::ANSIColor
  # server
  #
  # list available commands or display help for a specific command
  #
  def index
    # Check if config file is present?
    if !Nimbu::Auth.read_configuration
      print red(bold("WARNING")), ": this directory does not seem to contain any Nimbu theme. \n ==> Run \"", bold { "nimbu init ."}, "\" to initialize a new Nimbu project."
    else
      puts "Starting the server..."
      Nimbu::Server::Base.run!
    end
  end
end