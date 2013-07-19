# -*- encoding : utf-8 -*-
require "nimbu/command/base"
require "nimbu/version"

# display version
#
class Nimbu::Command::Version < Nimbu::Command::Base

  # version
  #
  # show nimbu client version
  #
  #Example:
  #
  # $ nimbu version
  # nimbu-toolbelt/1.2.3 (x86_64-darwin11.2.0) ruby/1.9.3
  #
  def index
    display(Nimbu::Auth.user_agent)
  end

end