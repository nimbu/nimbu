# -*- encoding : utf-8 -*-
require "nimbu"
require "nimbu/command"
require "nimbu/helpers"

class Nimbu::CLI

  extend Nimbu::Helpers

  def self.start(*args)
    begin
      if $stdin.isatty
        $stdin.sync = true
      end
      if $stdout.isatty
        $stdout.sync = true
      end
      command = args.shift.strip rescue "help"
      Nimbu::Command.load
      Nimbu::Command.run(command, args)
    rescue Interrupt
      `stty icanon echo`
      error("Command cancelled.")
    rescue => error
      styled_error(error)
      exit(1)
    end
  end

end
