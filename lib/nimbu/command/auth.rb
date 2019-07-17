# -*- encoding : utf-8 -*-
require "nimbu/command/base"

# authentication (login, logout)
#
class Nimbu::Command::Auth < Nimbu::Command::Base

  # auth
  #
  # Authenticate, display token and current user
  def index
    Nimbu::Command::Help.new.send(:help_for_command, current_command)
  end

  # auth:login
  #
  # log in with your nimbu credentials
  #
  #Example:
  #
  # $ nimbu auth:login
  #
  # Please enter your Nimbu credentials:
  #
  # Login: email@example.com (or your Nimbu username)
  # Password (typing will be hidden)
  #
  # Authentication successful.
  #
  def login
    Nimbu::Auth.login
    display " => Authentication successful."
  end

  alias_command "login", "auth:login"

  # auth:logout
  #
  # clear local authentication credentials
  #
  def logout
    Nimbu::Auth.logout
    display "=> Local credentials cleared."
  end

  alias_command "logout", "auth:logout"

  # auth:whoami
  #
  # check the identity linked to your token
  #
  def whoami
    results = Nimbu::Auth.whoami
    display " => Logged in as: #{results[:name]} (#{results[:email]})"
  end
  alias_command "whoami", "auth:whoami"


  # auth:token
  #
  # display your api token
  #
  def token
    display "=> Your personal API token is: #{Nimbu::Auth.token}"
  end

end
