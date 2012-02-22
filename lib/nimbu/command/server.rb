require "nimbu/command/base"
#require "nimbu/server/base"

# running a local server to speed up designing Nimbu themes
#
class Nimbu::Command::Server < Nimbu::Command::Base
  # server
  #
  # list available commands or display help for a specific command
  #
  def index
    puts "Starting the server..."
    Dir.pwd
    puts $:
    Nimbu::Server::Base.run!
  end
end