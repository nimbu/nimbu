require "nimbu/command/base"

# interacting with your sites (list, create)
#
class Nimbu::Command::Sites < Nimbu::Command::Base
  # index
  #
  # list sites you can edit
  #
  def index
    sites = nimbu.sites.list
    if sites.respond_to?(:any?) && sites.any?
      display "\nYou have access to following sites:\n"
      sites.each do |site|
        display " - #{site.name.white.bold} => http://#{site.domain}"
      end
    else
      display "You don't have access to any Nimbu sites."
      display ""
      display "Visit http://nimbu.io, start your 30-day trial and discover our amazing platform!"
    end
  end

  # index
  #
  # list sites you can edit
  #
  def list
    return index
  end
end

