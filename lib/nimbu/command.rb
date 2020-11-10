require 'nimbu/helpers'
require 'nimbu/version'
require 'term/ansicolor'
require 'optparse'

class String
  include Term::ANSIColor
end

module Nimbu
  module Command
    class CommandFailed < RuntimeError; end

    extend Nimbu::Helpers

    def self.load
      Dir[File.join(File.dirname(__FILE__), 'command', '*.rb')].sort.each do |file|
        require file
      end
    end

    def self.commands
      @@commands ||= {}
    end

    def self.command_aliases
      @@command_aliases ||= {}
    end

    def self.files
      @@files ||= Hash.new { |hash, key| hash[key] = File.readlines(key).map { |line| line.strip } }
    end

    def self.namespaces
      @@namespaces ||= {}
    end

    def self.register_command(command)
      commands[command[:command]] = command
    end

    def self.register_namespace(namespace)
      namespaces[namespace[:name]] = namespace
    end

    def self.current_command
      @current_command
    end

    def self.current_command=(new_current_command)
      @current_command = new_current_command
    end

    def self.current_args
      @current_args
    end

    def self.current_options
      @current_options ||= {}
    end

    def self.global_options
      @global_options ||= []
    end

    def self.global_option(name, *args, &blk)
      global_options << { name: name.to_s, args: args.sort.reverse, proc: blk }
    end

    def self.warnings
      @warnings ||= []
    end

    def self.display_warnings
      warn(warnings.map { |warning| " !    #{warning}" }.join("\n")) unless warnings.empty?
    end

    global_option :help, '--help', '-h'
    global_option :debug, '--debug'

    def self.prepare_run(cmd, args = [])
      command = parse(cmd)

      if args.include?('-h') || args.include?('--help')
        args.unshift(cmd) unless cmd =~ /^-.*/
        cmd = 'help'
        command = parse(cmd)
      end

      if ['--version', '-v'].include?(cmd)
        cmd = 'version'
        command = parse(cmd)
      end

      @current_command = cmd
      @anonymized_args = []
      @normalized_args = []

      opts = {}
      invalid_options = []

      parser = OptionParser.new do |parser|
        parser.base.long.delete('version')
        (global_options + (command && command[:options] || [])).each do |option|
          parser.on(*option[:args]) do |value|
            option[:proc].call(value) if option[:proc]
            opts[option[:name].gsub('-', '_').to_sym] = value
            ARGV.join(' ') =~ /(#{option[:args].map { |arg| arg.split(' ', 2).first }.join('|')})/
            @anonymized_args << "#{Regexp.last_match(1)} _"
            @normalized_args << "#{option[:args].last.split(' ', 2).first} _"
          end
        end
      end

      parser.version = Nimbu::VERSION

      begin
        parser.order!(args) do |nonopt|
          invalid_options << nonopt
          @anonymized_args << '!'
          @normalized_args << '!'
        end
      rescue OptionParser::InvalidOption => e
        invalid_options << e.args.first
        @anonymized_args << '!'
        @normalized_args << '!'
        retry
      end

      args.concat(invalid_options)

      @current_args = args
      @current_options = opts
      @invalid_arguments = invalid_options

      Nimbu.debug = true if opts[:debug]

      @anonymous_command = [ARGV.first, *@anonymized_args].join(' ')
      begin
        usage_directory = "#{home_directory}/.nimbu/usage"
        FileUtils.mkdir_p(usage_directory)
        usage_file = usage_directory << "/#{Nimbu::VERSION}"
        usage = if File.exist?(usage_file)
                  json_decode(File.read(usage_file).force_encoding('UTF-8'))
                else
                  {}
                end
        usage[@anonymous_command] ||= 0
        usage[@anonymous_command] += 1
        File.write(usage_file, json_encode(usage) + "\n")
      rescue StandardError
        # usage writing is not important, allow failures
      end

      if command
        command_instance = command[:klass].new(args.dup, opts.dup)

        if !@normalized_args.include?('--app _') && (implied_app = begin
          command_instance.app
        rescue StandardError
          nil
        end)
          @normalized_args << '--app _'
        end
        @normalized_command = [ARGV.first, @normalized_args.sort_by { |arg| arg.gsub('-', '') }].join(' ')

        [command_instance, command[:method]]
      else
        error([
          "`#{cmd}` is not a Nimbu command.",
          suggestion(cmd, commands.keys + command_aliases.keys),
          'See `Nimbu help` for a list of available commands.'
        ].compact.join("\n"))
      end
    end

    def self.run(cmd, arguments = [])
      begin
        object, method = prepare_run(cmd, arguments.dup)
        object.send(method)
      rescue Interrupt, StandardError, SystemExit => e
        # load likely error classes, as they may not be loaded yet due to defered loads
        raise(e)
      end
    # rescue Nimbu::API::Errors::Unauthorized, RestClient::Unauthorized
    #   puts "Authentication failure"
    #   unless ENV['Nimbu_API_KEY']
    #     run "login"
    #     retry
    #   end
    # rescue Nimbu::API::Errors::VerificationRequired, RestClient::PaymentRequired => e
    #   retry if Nimbu::Helpers.confirm_billing
    # rescue Nimbu::API::Errors::NotFound => e
    #   error extract_error(e.response.body) {
    #     e.response.body =~ /^([\w\s]+ not found).?$/ ? $1 : "Resource not found"
    #   }
    # rescue RestClient::ResourceNotFound => e
    #   error extract_error(e.http_body) {
    #     e.http_body =~ /^([\w\s]+ not found).?$/ ? $1 : "Resource not found"
    #   }
    # rescue Nimbu::API::Errors::Locked => e
    #   app = e.response.headers[:x_confirmation_required]
    #   if confirm_command(app, extract_error(e.response.body))
    #     arguments << '--confirm' << app
    #     retry
    #   end
    # rescue RestClient::Locked => e
    #   app = e.response.headers[:x_confirmation_required]
    #   if confirm_command(app, extract_error(e.http_body))
    #     arguments << '--confirm' << app
    #     retry
    #   end
    # rescue Nimbu::API::Errors::Timeout, RestClient::RequestTimeout
    #   error "API request timed out. Please try again, or contact support@Nimbu.com if this issue persists."
    # rescue Nimbu::API::Errors::ErrorWithResponse => e
    #   error extract_error(e.response.body)
    # rescue RestClient::RequestFailed => e
    #   error extract_error(e.http_body)
    rescue CommandFailed => e
      error e.message
    rescue OptionParser::ParseError
      commands[cmd] ? run('help', [cmd]) : run('help')
    rescue Excon::Errors::SocketError => e
      if e.message == 'getaddrinfo: nodename nor servname provided, or not known (SocketError)'
        error('Unable to connect to Nimbu API, please check internet connectivity and try again.')
      else
        raise(e)
      end
    ensure
      display_warnings
    end

    def self.parse(cmd)
      commands[cmd] || commands[command_aliases[cmd]]
    end

    def self.extract_error(body, _options = {})
      default_error = block_given? ? yield : "Internal server error.\nRun 'nimbu status' to check for known platform issues."
      parse_error_xml(body) || parse_error_json(body) || parse_error_plain(body) || default_error
    end

    def self.parse_error_xml(body)
      xml_errors = REXML::Document.new(body).elements.to_a('//errors/error')
      msg = xml_errors.map { |a| a.text }.join(' / ')
      return msg unless msg.empty?
    rescue Exception
    end

    def self.parse_error_json(body)
      json = begin
        json_decode(body.to_s)
      rescue StandardError
        false
      end
      json ? json['error'] : nil
    end

    def self.parse_error_plain(body)
      return unless body.respond_to?(:headers) && body.headers[:content_type].to_s.include?('text/plain')

      body.to_s
    end
  end
end
