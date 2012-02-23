require "nimbu/command/base"

# authentication (login, logout)
#
class Nimbu::Command::Init < Nimbu::Command::Base

  # index
  #
  # log in with your nimbu credentials
  #
  def index
    if Nimbu::Auth.read_configuration
      print green(bold("CONGRATULATIONS!")), ": this directory is already configured as a Nimbu theme."
    else
      display "Initialize the Nimbu configuration file."
      config = Nimbu::Auth.get_configuration

      display "Configuration ready: #{config}"
      config = Nimbu::Auth.get_credentials

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

