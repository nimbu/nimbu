require "nimbu/command/base"
require "nimbu/server/base"
require 'term/ansicolor'
require 'thin'

# running a local server to speed up designing Nimbu themes
#
class Nimbu::Command::Server < Nimbu::Command::Base
  include Term::ANSIColor
  # server
  #
  # starts a local development server, using the data from the Nimbu cloud in real time.
  #
  # -p PORT, --port PORT      # set the port on which to start the http server
  # -h,  --haml           # start local HAML watcher
  # -c,  --compass        # start local Compass watcher
  # -d,  --debug          # enable debugging output
  #
  def index
    # Check if config file is present?
    if !Nimbu::Auth.read_configuration || !Nimbu::Auth.read_credentials
      print red(bold("ERROR")), ": this directory does not seem to contain any Nimbu theme or your credentials are not set. \n ==> Run \"", bold { "nimbu init"}, "\" to initialize this directory."
    else
      no_compilation = true #! options[:'no-compile']
      with_haml = options[:haml]
      with_compass = options[:compass]

      if with_compass
        require 'compass'
        require 'compass/exec'
      end

      if with_haml
        require 'haml'
      end

      services = []
      services << "HAML" if with_haml
      services << "Compass" if with_compass
      title = "Starting up Nimbu Server"
      title << "(with local #{services.join(' and ')} watcher)" if with_compass || with_haml
      title << "..."
      puts white("\n#{title}")
      puts green(nimbu_header)
      puts green("\nConnnected to '#{Nimbu::Auth.site}.#{Nimbu::Auth.admin_host}', using '#{Nimbu::Auth.theme}' theme#{Nimbu.debug ? ' (in debug mode)'.red : nil}.\n")

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
          :DocumentRoot       => Dir.pwd
        }
        Rack::Handler::Thin.run Nimbu::Server::Base, server_options  do |server|
          [:INT, :TERM].each { |sig| trap(sig) { server.respond_to?(:stop!) ? server.stop! : server.stop } }
        end
      end

      # assets_pid = Process.fork do
      #   $stdout.reopen(compiler_write)
      #   compiler_read.close
      #   puts "Starting watcher..."
      #   HamlWatcher.watch
      # end unless no_compilation

      haml_pid = Process.fork do
        $stdout.reopen(haml_write)
        haml_read.close
        puts "Starting..."
        haml_listener = HamlWatcher.watch
        [:INT, :TERM].each do |sig|
          Signal.trap(sig) do
            puts green("== Stopping HAML watcher\n")
            haml_listener.stop
            puts haml_listener
          end
        end
        Process.waitall
      end if with_haml

      compass_pid = Process.fork do
        $stdout.reopen(compass_write)
        compass_read.close
        puts "Starting..."
        Compass::Exec::SubCommandUI.new(["watch","."]).run!
      end if with_compass

      watch_server_pid = Process.fork do
        trap('INT') { exit }
        server_write.close
        server_read.each do |line|
          print cyan("SERVER:  ") + white(line) + ""
        end
      end

      # watch_assets_pid = Process.fork do
      #   trap('INT') { exit }
      #   compiler_write.close
      #   compiler_read.each do |line|
      #     print magenta("ASSETS:    ") + white(line) + ""
      #   end
      # end unless no_compilation

      watch_haml_pid = Process.fork do
        trap('INT') { exit }
        haml_write.close
        haml_read.each do |line|
          print magenta("HAML:    ") + white(line) + ""
        end
      end if with_haml

      watch_compass_pid = Process.fork do
        trap('INT') { exit }
        compass_write.close
        compass_read.each do |line|
          print yellow("COMPASS: ") + white(line) + ""
        end
      end if with_compass

      [:INT, :TERM].each do |sig|
        trap(sig) do
          puts yellow("\n== Waiting for all processes to finish...")
          Process.kill('INT', haml_pid) if haml_pid && running?(haml_pid)
          Process.waitall
          puts green("== Nimbu has ended its work " + bold("(crowd applauds!)\n"))
        end
      end

      Process.waitall
    end
  end

  protected

  def nimbu_header
    h = ""
    h << "\n             o8o                     .o8"
    h << "\n             `\"'                    \"888"
    h << "\nooo. .oo.   oooo  ooo. .oo.  .oo.    888oooo.  oooo  oooo"
    h << "\n`888P\"Y88b  `888  `888P\"Y88bP\"Y88b   d88' `88b `888  `888"
    h << "\n 888   888   888   888   888   888   888   888  888   888"
    h << "\n 888   888   888   888   888   888   888   888  888   888"
    h << "\no888o o888o o888o o888o o888o o888o  `Y8bod8P'  `V88V\"V8P'"
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

require 'rubygems'
require 'listen'
require 'haml'

class HamlWatcher
  class << self
    include Term::ANSIColor

    def watch
      refresh
      puts ">>> Haml is polling for changes. Press Ctrl-C to Stop."
      listener = Listen.to('haml')
      listener.relative_paths(true)
      listener.filter(/\.haml$/)
      modifier = lambda do |modified, added, removed|
        puts modified.inspect
        modified.each do |relative|
          puts ">>> Change detected to: #{relative}"
          HamlWatcher.compile(relative)
        end if modified

        added.each do |relative|
          puts ">>> File created: #{relative}"
          HamlWatcher.compile(relative)
        end if added

        removed.each do |relative|
          puts ">>> File deleted: #{relative}"
          HamlWatcher.remove(relative)
        end if removed
      end
      listener.change(&modifier)
      listener.start(false)
      listener
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
        result = Haml::Engine.new(origin).render
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