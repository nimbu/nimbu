require "nimbu/command/base"

# authentication (login, logout)
#
class Nimbu::Command::Auth < Nimbu::Command::Base

  # auth:login
  #
  # log in with your nimbu credentials
  #
  def login
    Nimbu::Auth.login
    display "Authentication successful."
  end

  alias_command "login", "auth:login"

  # auth:logout
  #
  # clear local authentication credentials
  #
  def logout
    Nimbu::Auth.logout
    display "Local credentials cleared."
  end

  alias_command "logout", "auth:logout"

  # auth:token
  #
  # display your api token
  #
  def token
    display Nimbu::Auth.api_key
  end

end

