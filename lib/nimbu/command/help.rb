require "nimbu/command/base"

# list commands and display help
#
class Nimbu::Command::Help < Nimbu::Command::Base

  PRIMARY_NAMESPACES = %w( auth server themes sites init browse )

  # help [COMMAND]
  #
  # list available commands or display help for a specific command
  #
  def index
    if command = args.shift
      help_for_command(command)
    else
      help_for_root
    end
  end

  alias_command "-h", "help"
  alias_command "--help", "help"

  def self.usage_for_command(command)
    command = new.send(:commands)[command]
    "Usage: nimbu #{command[:banner]}" if command
  end

private

  def commands_for_namespace(name)
    Nimbu::Command.commands.values.select do |command|
      command[:namespace] == name && command[:command] != name
    end
  end

  def namespaces
    namespaces = Nimbu::Command.namespaces
    namespaces.delete("app")
    namespaces
  end

  def commands
    commands = Nimbu::Command.commands
    Nimbu::Command.command_aliases.each do |new, old|
      commands[new] = commands[old].dup
      commands[new][:command] = new
      commands[new][:namespace] = nil
      commands[new][:alias_for] = old
    end
    commands
  end

  def legacy_help_for_namespace(namespace)
    instance = Nimbu::Command::Help.groups.map do |group|
      [ group.title, group.select { |c| c.first =~ /^#{namespace}/ }.length ]
    end.sort_by { |l| l.last }.last
    return nil unless instance
    return nil if instance.last.zero?
    instance.first
  end

  def legacy_help_for_command(command)
    Nimbu::Command::Help.groups.each do |group|
      group.each do |cmd, description|
        return description if cmd.split(" ").first == command
      end
    end
    nil
  end

  def primary_namespaces
    PRIMARY_NAMESPACES.map { |name| namespaces[name] }.compact
  end

  def additional_namespaces
    (namespaces.values - primary_namespaces)
  end

  def summary_for_namespaces(namespaces)
    size = longest(namespaces.map { |n| n[:name] })
    namespaces.sort_by {|namespace| namespace[:name]}.each do |namespace|
      name = namespace[:name]
      namespace[:description] ||= legacy_help_for_namespace(name)
      puts "  %-#{size}s  # %s" % [ name, namespace[:description] ]
    end
  end

  def help_for_root
    puts "Usage: nimbu COMMAND [command-specific-options]"
    puts
    puts "Primary help topics, type \"nimbu help TOPIC\" for more details:"
    puts
    summary_for_namespaces(primary_namespaces)
    puts
    puts "Additional topics:"
    puts
    summary_for_namespaces(additional_namespaces)
    puts
  end

  def help_for_namespace(name)
    namespace_commands = commands_for_namespace(name)

    unless namespace_commands.empty?
      size = longest(namespace_commands.map { |c| c[:banner] })
      namespace_commands.sort_by { |c| c[:banner].to_s }.each do |command|
        next if command[:help] =~ /DEPRECATED/
        command[:summary] ||= legacy_help_for_command(command[:command])
        puts "  %-#{size}s  # %s" % [ command[:banner], command[:summary] ]
      end
    end
  end

  def help_for_command(name)
    command = commands[name]

    if command
      puts "Usage: nimbu #{command[:banner]}"

      if command[:help].strip.length > 0
        puts command[:help].split("\n")[1..-1].join("\n")
      else
        puts
        puts " " + legacy_help_for_command(name).to_s
      end
      puts
    end

    if commands_for_namespace(name).size > 0
      puts "Additional commands, type \"nimbu help COMMAND\" for more details:"
      puts
      help_for_namespace(name)
      puts
    elsif command.nil?
      error "#{name} is not a nimbu command. See 'nimbu help'."
    end
  end
end
