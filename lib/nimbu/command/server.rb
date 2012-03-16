require "nimbu/command/base"
require "nimbu/server/base"
require 'term/ansicolor'
require 'compass'
require 'compass/exec'
require 'thin'

# running a local server to speed up designing Nimbu themes
#
class Nimbu::Command::Server < Nimbu::Command::Base
  include Term::ANSIColor
  # server
  #
  # list available commands or display help for a specific command
  #
  def index
    # Check if config file is present?
    if !Nimbu::Auth.read_configuration || !Nimbu::Auth.read_credentials
      print red(bold("ERROR")), ": this directory does not seem to contain any Nimbu theme or your credentials are not set. \n ==> Run \"", bold { "nimbu init"}, "\" to initialize this directory."
    else
      no_haml = args.include?("--no-haml")
      no_compass = args.include?("--no-compass")

      if !(File.exists?(File.join(Dir.pwd,'haml')) && File.directory?(File.join(Dir.pwd,'haml')))
          no_haml = true
          puts red("\n !! WARNING: no ./haml directory detected => starting without HAML support !!")
      end

      puts white("\nStarting up Nimbu Server" + (no_compass ? "" : " + Compass Watcher") + (no_haml ? "" : " + HAML Compiler") + "...")
      puts green(
            "             _   ___            __         \n" +
            "            / | / (_)____ ___  / /_  __  __\n" +
            "           /  |/ / // __ `__ \\/ __ \\/ / / /\n" +
            "          / /|  / // / / / / / /_/ / /_/ / \n" +
            "         /_/ |_/_//_/ /_/ /_/_.___/\\__,_/  \n")

      rd1, wr1 = IO::pipe
      rd2, wr2 = IO::pipe
      rd3, wr3 = IO::pipe

      server_pid = Process.fork do
        $stdout.reopen(wr1)
        rd1.close
        puts "Starting..."
        options = {
          :Port               => 4567,
          :DocumentRoot       => Dir.pwd
        }
        Rack::Handler::Thin.run Nimbu::Server::Base, options  do |server|
          [:INT, :TERM].each { |sig| trap(sig) { server.respond_to?(:stop!) ? server.stop! : server.stop } }
        end
      end

      haml_pid = Process.fork do
        $stdout.reopen(wr2)
        rd2.close
        puts "Starting..."
        HamlWatcher.watch
      end unless no_haml

      compass_pid = Process.fork do
        $stdout.reopen(wr3)
        rd3.close
        puts "Starting..."
        Compass::Exec::SubCommandUI.new(["watch","."]).run!
      end unless no_compass


      watch_server_pid = Process.fork do
        trap('INT') { exit }
        wr1.close
        rd1.each do |line|  
          print cyan("SERVER:  ") + white(line) + ""
        end
      end
      watch_haml_pid = Process.fork do
        trap('INT') { exit }
        wr2.close
        rd2.each do |line|  
          print magenta("HAML:    ") + white(line) + ""
        end
      end unless no_haml

      watch_compass_pid = Process.fork do
        trap('INT') { exit }
        wr3.close
        rd3.each do |line|  
          print yellow("COMPASS: ") + white(line) + ""
        end
      end unless no_compass

      [:INT, :TERM].each do |sig| 
        trap(sig) do
          puts green("\n\n== Nimbu has ended its work " + bold("(crowd applauds!)\n"))
        end
      end

      Process.waitall      
    end
  end
end

require 'rubygems'
require 'fssm'
require 'haml'

class HamlWatcher
  class << self
    include Term::ANSIColor
    
    def watch
      refresh
      puts ">>> Haml is polling for changes. Press Ctrl-C to Stop."
      FSSM.monitor('haml', '**/*.haml') do
        update do |base, relative|
          puts ">>> Change detected to: #{relative}"
          HamlWatcher.compile(relative)
        end
        create do |base, relative|
          puts ">>> File created: #{relative}"
          HamlWatcher.compile(relative)
        end
        delete do |base, relative|
          puts ">>> File deleted: #{relative}"
          HamlWatcher.remove(relative)
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