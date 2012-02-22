require "nimbu/command/base"

# authentication (login, logout)
#
class Nimbu::Command::Init < Nimbu::Command::Base

  # index
  #
  # log in with your nimbu credentials
  #
  def index
    display "Initialize the Nimbu configuration file."
    config = Nimbu::Auth.get_configuration
    display "Configuration ready: #{config}"
    config = Nimbu::Auth.get_credentials
  end
end

