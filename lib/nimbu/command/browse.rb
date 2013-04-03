require "nimbu/command/base"

# open the current site in your browser (simulator, admin)
#
class Nimbu::Command::Browse < Nimbu::Command::Base
  # browse
  #
  # open the current site in your browser
  #
  def index
    cmd = browse_command(args) do
      dest = args.shift
      dest = nil if dest == '--'

      if dest
        #site = nimbu browser dest
      else
        # $ nimbu browse
        site = Nimbu::Auth.site
      end

      abort "Usage: nimbu browse <SITE>" unless site
      "https://#{site}.#{Nimbu::Auth.admin_host}"
    end
    exec(cmd)
  end

  # browse:simulator
  #
  # open the simulator for your current site
  #
  def simulator
    cmd = browse_command(args) do
      "http://localhost:4567"
    end
    exec(cmd)
  end

  # browse:admin
  #
  # open the admin area for your current site
  #
  def admin
    cmd = browse_command(args) do
      "https://#{Nimbu::Auth.site}.#{Nimbu::Auth.admin_host}/admin"
    end
    exec(cmd)
  end

  protected

  def browse_command(args)
    url_only = args.delete('-u')
    url = yield

    exec_args = []
    exec_args.push(url_only ? 'echo' : browser_launcher)
    exec_args.push url
    exec_args.join(" ")
  end

end

