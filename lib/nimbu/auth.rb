require "yaml"
require "nimbu"
require "nimbu/client"
require "nimbu/helpers"

class Nimbu::Auth
  class << self

    include Nimbu::Helpers
    attr_accessor :credentials
    attr_accessor :configuration

    def client
      @client ||= begin
        client = Nimbu::Client.new(user, password, host)
        client.on_warning { |msg| self.display("\n#{msg}\n\n") }
        client
      end
    end

    def login
      delete_credentials
      get_credentials
    end

    def logout
      delete_credentials
    end

    # just a stub; will raise if not authenticated
    def check
      client.list
    end

    def default_host
      "getnimbu.com"
    end

    def host
      @host ||= ENV['NIMBU_HOST'] || get_nimbu_host
    end

    def theme
      @theme ||= ENV['NIMBU_THEME'] || get_nimbu_theme
    end

    def get_nimbu_host
      get_configuration[:hostname]
    end

    def get_nimbu_theme
      get_configuration[:theme]
    end

    def get_configuration    # :nodoc:
      @configuration ||= (read_configuration || ask_for_and_save_configuration)
    end

    def ask_for_and_save_configuration
      @configuration = ask_for_configuration
      write_configuration
      @configuration
    end

    def configuration_file
      "#{Dir.pwd}/nimbu.yml"
    end

    def delete_configuration
      FileUtils.rm_f(configuration_file)
      @host = nil
    end

   def ask_for_configuration
      puts "What is the hostname for this Nimbu site?"
      print "Hostname: "
      hostname = ask

      puts "What is the theme you are developing in this directory?"
      print "Theme (i.e. default): "
      theme = ask

      {:hostname => hostname, :theme => theme}
    end

    def read_configuration
      File.exists?(configuration_file) and YAML::load(File.open( configuration_file ))
    end

    def write_configuration
      FileUtils.mkdir_p(File.dirname(configuration_file))
      File.open(configuration_file, 'w') {|credentials| credentials.puts(YAML.dump(self.configuration))}
      FileUtils.chmod(0700, File.dirname(configuration_file))
      FileUtils.chmod(0600, configuration_file)
    end

    def reauthorize
      @credentials = ask_for_and_save_credentials
    end

    def user    # :nodoc:
      get_credentials[0]
    end

    def password    # :nodoc:
      get_credentials[1]
    end

    def api_key
      Nimbu::Client.auth(user, password)["api_key"]
    end

    def credentials_file
      if host == default_host
        "#{home_directory}/.nimbu/credentials"
      else
        "#{home_directory}/.nimbu/credentials.#{CGI.escape(host)}"
      end
    end

    def get_credentials    # :nodoc:
      @credentials ||= (read_credentials || ask_for_and_save_credentials)
    end

    def delete_credentials
      FileUtils.rm_f(credentials_file)
      @client, @credentials = nil, nil
    end

    def read_credentials
      if ENV['NIMBU_API_KEY']
        ['', ENV['NIMBU_API_KEY']]
      else
        File.exists?(credentials_file) and File.read(credentials_file).split("\n")
      end
    end

    def write_credentials
      FileUtils.mkdir_p(File.dirname(credentials_file))
      File.open(credentials_file, 'w') {|credentials| credentials.puts(self.credentials)}
      FileUtils.chmod(0700, File.dirname(credentials_file))
      FileUtils.chmod(0600, credentials_file)
    end

    def echo_off
      with_tty do
        system "stty -echo"
      end
    end

    def echo_on
      with_tty do
        system "stty echo"
      end
    end

    def ask_for_credentials
      puts "Enter your Nimbu credentials."

      print "Email: "
      user = ask

      print "Password: "
      password = running_on_windows? ? ask_for_password_on_windows : ask_for_password
      api_key = Nimbu::Client.auth(user, password)['api_key']

      [user, api_key]
    end

    def ask_for_password_on_windows
      require "Win32API"
      char = nil
      password = ''

      while char = Win32API.new("crtdll", "_getch", [ ], "L").Call do
        break if char == 10 || char == 13 # received carriage return or newline
        if char == 127 || char == 8 # backspace and delete
          password.slice!(-1, 1)
        else
          # windows might throw a -1 at us so make sure to handle RangeError
          (password << char.chr) rescue RangeError
        end
      end
      puts
      return password
    end

    def ask_for_password
      echo_off
      trap("INT") do
        echo_on
        exit
      end
      password = ask
      puts
      echo_on
      return password
    end

    def ask_for_and_save_credentials
      begin
        @credentials = ask_for_credentials
        write_credentials
        check
      rescue ::RestClient::Unauthorized, ::RestClient::ResourceNotFound => e
        delete_credentials
        display "Authentication failed."
        retry if retry_login?
        exit 1
      rescue Exception => e
        delete_credentials
        raise e
      end
      @credentials
    end

    def check_for_associated_ssh_key
      return unless client.keys.empty?
      associate_or_generate_ssh_key
    end

    def associate_or_generate_ssh_key
      public_keys = Dir.glob("#{home_directory}/.ssh/*.pub").sort

      case public_keys.length
      when 0 then
        display "Could not find an existing public key."
        display "Would you like to generate one? [Yn] ", false
        unless ask.strip.downcase == "n"
          display "Generating new SSH public key."
          generate_ssh_key("id_rsa")
          associate_key("#{home_directory}/.ssh/id_rsa.pub")
        end
      when 1 then
        display "Found existing public key: #{public_keys.first}"
        associate_key(public_keys.first)
      else
        display "Found the following SSH public keys:"
        public_keys.each_with_index do |key, index|
          display "#{index+1}) #{File.basename(key)}"
        end
        display "Which would you like to use with your Nimbu account? ", false
        chosen = public_keys[ask.to_i-1] rescue error("Invalid choice")
        associate_key(chosen)
      end
    end

    def generate_ssh_key(keyfile)
      ssh_dir = File.join(home_directory, ".ssh")
      unless File.exists?(ssh_dir)
        FileUtils.mkdir_p ssh_dir
        File.chmod(0700, ssh_dir)
      end
      `ssh-keygen -t rsa -N "" -f \"#{home_directory}/.ssh/#{keyfile}\" 2>&1`
    end

    def associate_key(key)
      display "Uploading SSH public key #{key}"
      client.add_key(File.read(key))
    end

    def retry_login?
      @login_attempts ||= 0
      @login_attempts += 1
      @login_attempts < 3
    end
  end
end
