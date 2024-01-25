# -*- encoding : utf-8 -*-
require "nimbu/command/base"

# running a local server to speed up designing Nimbu themes
#
class Nimbu::Command::Server < Nimbu::Command::Base
  include Term::ANSIColor
  # server
  #
  # starts a local development server, using the data from the Nimbu cloud in real time.
  #
  # -p PORT, --port PORT     # set the port on which to start the http server
  # --host HOST              # set the host on which to start the http server
  # -h,  --haml              # start local HAML watcher
  # -c,  --compass           # start local Compass watcher
  # -d,  --debug             # enable debugging output
  # --webpack RES            # comma separated list of webpack resources (relative to /javascripts)
  # --webpackurl URL         # proxy requests for webpack resources to the given URL prefix (default: http://localhost:8080)
  # --nocookies              # disable session refresh cookie check
  # --dir DIR                # root of your project (default: current directory)
  #
  def index
    require 'rubygems'
    require "nimbu/server/base"
    require 'term/ansicolor'
    require 'thin'
    require 'filewatcher'
    require 'pathname'
    require 'lolcat'
    require 'socket'

    Nimbu.cli_options[:dir] = options[:dir] if options[:dir]

    # Check if config file is present?
    if !Nimbu::Auth.read_configuration
      print red(bold("ERROR")), ": this directory does not seem to contain any Nimbu theme configuration. \n ==> Run \"", bold { "nimbu init"}, "\" to initialize this directory."
    elsif Nimbu::Auth.token.nil?
      print red(bold("ERROR")), ": it seems you are not authenticated. \n ==> Run \"", bold { "nimbu login"}, "\" to initialize a session."
    else
      @with_haml    = options[:haml]
      @with_compass = options[:compass] || options[:c]
      @no_cookies   = options[:nocookies]
      @webpack_resources = options[:webpack]
      @webpack_url  = options[:webpackurl]

      if @no_cookies
        Nimbu.cli_options[:nocookies] = true
      end

      if @webpack_resources
        Nimbu.cli_options[:webpack_resources] = @webpack_resources.split(",").map(&:strip)
        if @webpack_url
          Nimbu.cli_options[:webpack_url] = @webpack_url
        else
          Nimbu.cli_options[:webpack_url] = "http://localhost:8080"
        end
      end

      if @with_compass
        require 'compass'
        require 'compass/exec'
      end

      if @with_haml
        require 'haml'
      end

      services = []
      services << "HAML" if @with_haml
      services << "Compass" if @with_compass
      title = "Starting up local Nimbu Toolbelt Server (v#{Nimbu::VERSION}, using Ruby #{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}):"
      title << "\n - with local #{services.join(' and ')} watcher" if @with_compass || @with_haml
      title << "\n - skipping cookies check" if @no_cookies
      title << "\n - proxying webpack resources to #{Nimbu.cli_options[:webpack_url]}" if @webpack_resources
      title << " ..."
      puts white("\n#{title}")
      puts nimbu_header
      puts green("\nConnnected to '#{Nimbu::Auth.site}.#{Nimbu::Auth.admin_host}', using '#{Nimbu::Auth.theme}' theme#{Nimbu.debug ? ' (in debug mode)'.red : nil}.\n")

      if Nimbu::Helpers.running_on_windows?
        run_on_windows!
      else
        run_on_unix!
      end
    end
  end

  def haml
    require 'haml'
    puts "Starting..."
    haml_listener = HamlWatcher.watch
    sleep
  end

  def compass
    require 'compass'
    require 'compass/exec'
    Compass::Exec::SubCommandUI.new(["watch","."]).run!
  end

  protected

  def ipv6_supported?
    begin
      socket = Socket.new(Socket::AF_INET6, Socket::SOCK_STREAM)
      socket.close
      true
    rescue Errno::EAFNOSUPPORT
      false
    end
  end

  def project_root
    Nimbu.cli_options[:dir] || Dir.pwd
  end

  def default_host
    if ipv6_supported?
      "::"
    else
      "127.0.0.1"
    end
  end

  def run_on_windows!
    server_thread = Thread.new do
    Thread.current[:stdout] = StringIO.new
      puts "Starting server..."
      server_options = {
        :Port               => options[:port] || 4567,
        :DocumentRoot       => project_root,
        :Host               => default_host
      }
      server_options.merge!({:Host => options[:host]}) if options[:host]
      Rack::Handler::Thin.run Nimbu::Server::Base, server_options  do |server|
        [:INT, :TERM].each do |sig| 
          trap(sig) do 
            server.respond_to?(:stop!) ? server.stop! : server.stop
            exit(0)
          end
        end
      end
    end

    haml_thread = Thread.new do
      Process.setproctitle("#{$0} => nimbu-toolbelt haml")
      puts "Starting watcher..."
      HamlWatcher.watch
    end if @with_haml

    compass_pid = if @with_compass
      Process.setproctitle("#{$0} => nimbu-toolbelt compass")
      puts "Starting..."
      cmd = "bundle exec nimbu server:compass"
      Process.spawn(cmd, out: $stdout, err: [:child, :out])
    end

    server_thread.join
    haml_thread.join if @with_haml

    [:HUP, :INT, :TERM].each do |sig|
      trap(sig) do
        should_wait = false

        if compass_pid && running?(compass_pid)
          should_wait = true
          Process.kill('INT', compass_pid)
        end

        Process.waitall if should_wait
        exit(0)
      end
    end

    Process.waitall
  end

  def run_on_unix!
    STDOUT.sync = true
    server_read, server_write = IO::pipe
    haml_read, haml_write = IO::pipe
    compass_read, compass_write = IO::pipe
    compiler_read, compiler_write = IO::pipe

    server_pid = Process.fork do
      $stdout.reopen(server_write)
      server_read.close
      puts "Starting server..."
      server_options = {
        :Port               => options[:port] || 4567,
        :DocumentRoot       => options[:dir] || Dir.pwd,
        :Host               => default_host,
      }
      server_options.merge!({:Host => options[:host]}) if options[:host]
      Rack::Handler::Thin.run Nimbu::Server::Base, **server_options  do |server|
        Process.setproctitle("#{$0} => nimbu-toolbelt server")

        [:INT, :TERM].each do |sig| 
          trap(sig) do 
            server.respond_to?(:stop!) ? server.stop! : server.stop
            exit(0)
          end
        end
      end
    end

    haml_pid = Process.fork do
      $stdout.reopen(haml_write)
      haml_read.close
      puts "Starting..."
      haml_listener = HamlWatcher.watch
      Process.setproctitle("#{$0} => nimbu-toolbelt haml")
      [:HUP, :INT, :TERM].each do |sig|
        Signal.trap(sig) do
          puts green("== Stopping HAML watcher\n")
          Thread.new { haml_listener.stop }
        end
      end
      Process.waitall
    end if @with_haml

    compass_pid = Process.fork do
      Process.setproctitle("#{$0} => nimbu-toolbelt compass")
      $stdout.reopen(compass_write)
      compass_read.close
      puts "Starting..."
      Compass::Exec::SubCommandUI.new(["watch","."]).run!
    end if @with_compass

    watch_server_pid = Process.fork do
      Process.setproctitle("#{$0} => nimbu-toolbelt server-watcher")

      [:HUP, :INT, :TERM].each { |sig| trap(sig) { exit } }
      
      server_write.close
      server_read.each do |line|
        print cyan("SERVER:  ") + white(line) + ""
      end
    end

    watch_haml_pid = Process.fork do
      Process.setproctitle("#{$0} => nimbu-toolbelt haml-watcher")
      [:HUP, :INT, :TERM].each { |sig| trap(sig) { exit } }

      haml_write.close
      haml_read.each do |line|
        print magenta("HAML:    ") + white(line) + ""
      end
    end if @with_haml

    watch_compass_pid = Process.fork do
      Process.setproctitle("#{$0} => nimbu-toolbelt haml-compass")
      [:HUP, :INT, :TERM].each { |sig| trap(sig) { exit } }

      compass_write.close
      compass_read.each do |line|
        print yellow("COMPASS: ") + white(line) + ""
      end
    end if @with_compass

    [:HUP, :INT, :TERM].each do |sig|
      trap(sig) do
        should_wait = false
        @child_pids_running.each do |pid|
          if running?(server_pid)
            should_wait = true
            Process.kill('INT', pid)
          end
        end

        Process.waitall if should_wait
        exit(0)
      end
    end

    @child_pids_running = [
      server_pid,
      haml_pid,
      compass_pid,
      watch_server_pid,
      watch_haml_pid,
      watch_compass_pid
    ].compact!

    Process.waitall
  end

  def nimbu_ascii_art
    %{
 _   _ _           _          _____           _ _          _ _
| \\ | (_)_ __ ___ | |__  _   |_   _|__   ___ | | |__   ___| | |_
|  \\| | | '_ ` _ \\| '_ \\| | | || |/ _ \\ / _ \\| | '_ \\ / _ \\ | __|
| |\\  | | | | | | | |_) | |_| || | (_) | (_) | | |_) |  __/ | |_
|_| \\_|_|_| |_| |_|_.__/ \\__,_||_|\\___/ \\___/|_|_.__/ \\___|_|\\__|}         
  end

  def nimbu_header
    length = nimbu_ascii_art.split("\n").last.length
    print white("\n" + "=" * length)
    buf = StringIO.new(nimbu_ascii_art)
    opts = {
      :animate => false,
      :duration => 12,
      :os => rand * 8192,
      :speed => 20,
      :spread => 8.0,
      :freq => 0.3
    }
    Lol.cat buf, opts
    print white("\n\n" + "=" * length)
  end

  def running?(pid)
    begin
      Process.getpgid( pid )
      true
    rescue Errno::ESRCH
      false
    end
  end
end

class HamlWatcher
  class << self
    include Term::ANSIColor

    def watch
      refresh
      current_dir = File.join(Nimbu.cli_options[:dir] || Dir.pwd, 'haml/')
      puts ">>> Haml is polling for changes. Press Ctrl-C to Stop."
      Filewatcher.new('haml/**/*.haml', every: true).watch do |filename, event|
        begin
          relative = filename.to_s.gsub(current_dir, '')

          case event.to_s
          when 'updated'
            puts ">>> Change detected to: #{relative}"
            HamlWatcher.compile(relative)
          when 'deleted'
            puts ">>> File deleted: #{relative}"
            HamlWatcher.remove(relative)
          when 'created'
            puts ">>> File created: #{relative}"
            HamlWatcher.compile(relative)
          end
        rescue => e
          puts "#{e.inspect}"
        end
      end
    end

    def output_file(filename)
      # './haml' retains the base directory structure
      filename.gsub(/\.html\.haml$/,'.html').gsub(/\.liquid\.haml$/,'.liquid')
    end

    def remove(file)
      output = output_file(file)
      File.delete output
      puts "\033[0;31m   remove\033[0m #{output}"
    end

    def compile(file)
      begin
        output_file_name = output_file(file)
        origin = File.open(File.join('haml', file)).read
        result = Haml::Engine.new(origin, {escape_attrs: false}).render
        raise "Nothing rendered!" if result.empty?
        # Write rendered HTML to file
        color, action = File.exist?(output_file_name) ? [33, 'overwrite'] : [32, '   create']
        puts "\033[0;#{color}m#{action}\033[0m #{output_file_name}"
        FileUtils.mkdir_p(File.dirname(output_file_name))
        File.open(output_file_name,'w') {|f| f.write(result)}
      rescue Exception => e
        print red("#{plainError e, file}\n")
        output_file_name = output_file(file)
        result = goHere(e, file)
        File.open(output_file_name,'w') {|f| f.write(result)} if File::exists?(output_file_name)
      end
    end

    # Check that all haml templates have been rendered.
    def refresh
      Dir.glob('haml/**/*.haml').each do |file|
        file.gsub!(/^haml\//, '')
        compile(file) unless File.exist?(output_file(file))
      end
    end

    def goHere(message, nameoffile)
      @messag = ""
      #@messag += "<html><head><title>ERROR IN CODE</title>"
      #CSS for error styling.
      @messag += "<style type = \"text/css\">"
      @messag +="body { background-color: #fff; margin: 40px; font-family: Lucida Grande, Verdana, Sans-serif; font-size: 12px; color: #000;}"
      @messag +="#content { border: #999 1px solid; background-color: #fff; padding: 20px 20px 12px 20px;}"
      @messag +="h1 { font-weight: normal; font-size: 14px; color: #990000; margin: 0 0 4px 0; }"
      @messag += "</style>"
      @messag += "<div id=\"content\">"
      @messag += "<h1>You have an Error in your HAML code </h1>"
      @messag += "<p>#{message} </p>"
      @messag += "<p>On Line : #{get_line message}.</p>"
      @messag += "<p>In file location: <strong>#{nameoffile}</strong></p>"
      @messag += "</div>"
      return @messag
    end

    def get_line(exception)
      # SyntaxErrors have weird line reporting
      # when there's trailing whitespace,
      # which there is for Haml documents.
      return (exception.message.scan(/:(\d+)/).first || ["??"]).first if exception.is_a?(::SyntaxError)
      (exception.backtrace[0].scan(/:(\d+)/).first || ["??"]).first
    end

    def plainError(message, nameoffile)
      @plainMessage = ""
      @plainMessage += "Error: #{message} \n"
      @plainMessage += "Line number #{get_line message} "
      @plainMessage += "File error detected: #{nameoffile}"
      return @plainMessage
    end

    def sassErrorLine message
      return message
    end
  end
end
