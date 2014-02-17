# -*- encoding : utf-8 -*-
require "yaml"
require "nimbu"
require "nimbu/helpers"

class Nimbu::Auth
  class << self

    include Nimbu::Helpers
    attr_accessor :credentials
    attr_accessor :configuration

    def simulator_id
      return @simulator_id if defined? @simulator_id

      ranges = [('a'..'z'),('A'..'Z'),(0..9)].map{|i| i.to_a}.flatten
      @simulator_id ||= (1..40).map{ ranges[rand(ranges.length)]  }.join
    end

    def client
      @client ||= begin
        Nimbu::Client.new(:oauth_token => token, :endpoint => host, :user_agent => self.user_agent)
      end
    end

    def user_agent
      "nimbu-toolbelt/#{Nimbu::VERSION} (#{RUBY_PLATFORM}) ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}".freeze
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
      client.sites.list
    end

    def host
      ENV['NIMBU_HOST'] || "https://api.nimbu.io"
    end

    def default_host
      "https://api.nimbu.io"
    end

    def admin_host
      @admin_host ||= host.gsub(/https?\:\/\/api\./,'')
    end

    def site
      @site ||= ENV['NIMBU_SITE'] || get_nimbu_site
    end

    def theme
      @theme ||= ENV['NIMBU_THEME'] || get_nimbu_theme
    end

    def get_nimbu_site
      get_configuration["site"]
    end

    def get_nimbu_theme
      get_configuration["theme"] || "default-theme"
    end

    def get_configuration
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

      subdomain = nil
      sites = client.sites.list

      unless sites.respond_to?(:any?) && sites.any?
        display "You don't have access to any Nimbu sites you can edit yet..."
        display ""
        display "Please visit http://nimbu.io, start your 30-day trial and discover our amazing platform!"
        exit(1)
      else
        print_separator
        display "\nLet's first setup the configuration for this directory..."
        display "\nYou have access to following sites:\n"
        sites.each_with_index do |site,i|
          display " #{i+1}) #{site.name.white.bold} => http://#{site.domain}"
        end
        site_number = 0
        retry_site = false
        while site_number < 1 || site_number > sites.length
          unless retry_site
            print "\nOn which site would you like to work? "
          else
            print "\nPlease enter the number of your site (between 1-#{sites.length}): "
          end
          site_number_string = ask
          site_number = site_number_string.to_i rescue 0
          retry_site = true
        end
        puts ""
        site = sites[site_number-1]
        display "Site chosen => #{site.name.white.bold} (http://#{site.domain})"
        subdomain = site.subdomain
        @site = subdomain
      end

      themes = client.themes(:subdomain => subdomain).list
      current_theme = if themes.length > 1
        theme_number = 0
        retry_theme = false
        while theme_number < 1 || theme_number > themes.length
          unless retry_theme
            print "\nOn which theme would you like to work in this directory? "
          else
            print "\nPlease enter the number of your theme (between 1-#{themes.length}): "
          end
          theme_number_string = ask
          theme_number = theme_number_string.to_i rescue 0
          retry_theme = true
        end
        puts ""
        display "Theme chosen => #{themes[theme_number-1].name}"
        themes[theme_number-1]
      else
        themes.first
      end
      @theme = current_theme.short
      print_separator

      { "site" => subdomain, "theme" => current_theme.short }
    end

    def read_configuration
      existing_config = YAML::load(File.open( configuration_file )) if File.exists?(configuration_file)
      if existing_config && ! existing_config["site"].nil?
        existing_config
      else
        nil
      end
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

    def token    # :nodoc:
      get_credentials
    end

    def credentials_file
      if host == default_host
        "#{home_directory}/.nimbu/credentials"
      else
        "#{home_directory}/.nimbu/credentials.#{CGI.escape(host.gsub(/https?\:\/\//,''))}"
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
      credentials = File.read(credentials_file).force_encoding('UTF-8') if File.exists?(credentials_file)
      if credentials && credentials =~ /^(bearer|oauth2|token) ([\w]+)$/i
        $2
      else
        nil
      end
    end

    def write_credentials
      FileUtils.mkdir_p(File.dirname(credentials_file))
      File.open(credentials_file, 'w') {|credentials| credentials.print("token #{self.credentials}")}
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
      print "Login: "
      user = ask

      print "Password: "
      password = running_on_windows? ? ask_for_password_on_windows : ask_for_password

      begin
        basic_client = Nimbu::Client.new(
          :basic_auth => "#{user}:#{password}",
          :endpoint => host,
          :user_agent => self.user_agent
        )
        basic_client.authenticate.token
      rescue Exception => e
        if e.respond_to?(:http_status_code) && e.http_status_code == 401
          display " => could not login... please check your username and/or password!\n\n"
        else
          display " => hmmmm... an error occurred: #{e}. \n\n\nIf this continues to occur, please report \nthe error at https://github.com/nimbu/nimbu/issues.\n\n"
        end
        nil
      end
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
      display "Please authenticate with Nimbu.io:"
      begin
        @credentials = ask_for_credentials
        write_credentials
        check
      rescue Exception => e
        delete_credentials
        raise e
      end
      @credentials
    end

    def retry_login?
      @login_attempts ||= 0
      @login_attempts += 1
      @login_attempts < 3
    end

    def print_separator
      print "\n"
      60.times { print "#"}
      print "\n"
    end
  end
end
