require "nimbu"
require "nimbu/command"

class Nimbu::CLI

  def self.start(*args)
    command = args.shift.strip rescue "help"
    Nimbu::Command.load
    Nimbu::Command.run(command, args)
  end

end
