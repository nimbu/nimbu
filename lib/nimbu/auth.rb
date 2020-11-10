require 'yaml'
require 'nimbu'
require 'nimbu/helpers'
require 'term/ansicolor'
require 'netrc'

class Nimbu::Auth
  class << self
    include Nimbu::Helpers
    attr_accessor :credentials, :configuration

    def simulator_id
      return @simulator_id if defined? @simulator_id

      ranges = [('a'..'z'), ('A'..'Z'), (0..9)].map { |i| i.to_a }.flatten
      @simulator_id ||= (1..40).map { ranges[rand(ranges.length)] }.join
    end

    def client
      @client ||= begin
        Nimbu::Client.new(oauth_token: token, endpoint: host, user_agent: user_agent, auto_pagination: true)
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

    def whoami
      client.users.me
    end

    # just a stub; will raise if not authenticated
    def check
      client.sites.list
    end

    def host
      ENV['NIMBU_HOST'] || 'https://api.nimbu.io'
    end

    def default_host
      'https://api.nimbu.io'
    end

    def admin_host
      @admin_host ||= host.gsub(%r{https?://api\.}, '')
    end

    def api_host
      @api_host ||= host.gsub(%r{https?://}, '')
    end

    def site
      @site ||= ENV['NIMBU_SITE'] || get_nimbu_site
    end

    def theme
      @theme ||= ENV['NIMBU_THEME'] || get_nimbu_theme
    end

    def get_nimbu_site
      get_configuration['site']
    end

    def get_nimbu_theme
      get_configuration['theme'] || 'default-theme'
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

      if sites.respond_to?(:any?) && sites.any?
        print_separator
        display "\nLet's first setup the configuration for this directory..."
        display "\nYou have access to following sites:\n"
        sites.each_with_index do |site, i|
          display " #{i + 1}) #{site.name.white.bold} => http://#{site.domain}"
        end
        site_number = 0
        retry_site = false
        while site_number < 1 || site_number > sites.length
          if retry_site
            print "\nPlease enter the number of your site (between 1-#{sites.length}): "
          else
            print "\nOn which site would you like to work? "
          end
          site_number_string = ask
          site_number = begin
            site_number_string.to_i
          rescue StandardError
            0
          end
          retry_site = true
        end
        puts ''
        site = sites[site_number - 1]
        display "Site chosen => #{site.name.white.bold} (http://#{site.domain})"
        subdomain = site.subdomain
        @site = subdomain
      else
        display "You don't have access to any Nimbu sites you can edit yet..."
        exit(1)
      end

      themes = client.themes(subdomain: subdomain).list
      current_theme = if themes.length > 1
                        theme_number = 0
                        retry_theme = false
                        while theme_number < 1 || theme_number > themes.length
                          if retry_theme
                            print "\nPlease enter the number of your theme (between 1-#{themes.length}): "
                          else
                            print "\nOn which theme would you like to work in this directory? "
                          end
                          theme_number_string = ask
                          theme_number = begin
                            theme_number_string.to_i
                          rescue StandardError
                            0
                          end
                          retry_theme = true
                        end
                        puts ''
                        display "Theme chosen => #{themes[theme_number - 1].name}"
                        themes[theme_number - 1]
                      else
                        themes.first
                      end
      @theme = current_theme.short
      print_separator

      { 'site' => subdomain, 'theme' => current_theme.short }
    end

    def read_configuration
      existing_config = YAML.load(File.open(configuration_file)) if File.exist?(configuration_file)
      existing_config if existing_config && !existing_config['site'].nil?
    end

    def write_configuration
      FileUtils.mkdir_p(File.dirname(configuration_file))
      File.open(configuration_file, 'w') { |credentials| credentials.puts(YAML.dump(configuration)) }
      FileUtils.chmod(0o700, File.dirname(configuration_file))
      FileUtils.chmod(0o600, configuration_file)
    end

    def reauthorize
      @credentials = ask_for_and_save_credentials
    end

    def token # :nodoc:
      ENV['NIMBU_API_KEY'] || get_credentials
    end

    def get_credentials # :nodoc:
      @credentials ||= (read_credentials || ask_for_and_save_credentials)
      @credentials[:token]
    end

    def delete_credentials
      n = Netrc.read
      n.delete(api_host)
      n.save
      @client = nil
      @credentials = nil
    end

    def read_credentials
      n = Netrc.read
      user, token = n[api_host]
      { user: user, token: token } if user && token
    end

    def write_credentials
      n = Netrc.read
      n[api_host] = @credentials[:user], @credentials[:token]
      n.save
    end

    def echo_off
      with_tty do
        system 'stty -echo'
      end
    end

    def echo_on
      with_tty do
        system 'stty echo'
      end
    end

    def ask_for_credentials(user = nil, password = nil, two_factor_code = nil)
      unless user
        print 'Login: '
        user = ask
      end

      unless password
        print 'Password: '
        password = running_on_windows? ? ask_for_password_on_windows : ask_for_password
      end

      begin
        request_headers = {}
        request_headers['X-Nimbu-Two-Factor'] = two_factor_code.to_s.strip unless two_factor_code.nil?

        basic_client = Nimbu::Client.new(
          basic_auth: "#{user}:#{password}",
          endpoint: host,
          user_agent: user_agent,
          headers: request_headers
        )
        { user: user, token: basic_client.authenticate.token }
      rescue Exception => e
        if e.respond_to?(:http_status_code) && e.http_status_code == 401
          if e.message =~ /two factor authentication/
            print '2FA Token: '
            two_factor_code = ask
            ask_for_credentials(user, password, two_factor_code)
          else
            display " => could not login... please check your username and/or password!\n\n"
            nil
          end
        else
          display " => hmmmm... an error occurred: #{e}. \n\n\nIf this continues to occur, please report \nthe error at https://github.com/nimbu/nimbu/issues.\n\n"
          nil
        end
      end
    end

    def ask_for_password_on_windows
      require 'Win32API'
      char = nil
      password = ''

      while char = Win32API.new('msvcrt', '_getch', [], 'L').Call
        break if [10, 13].include?(char) # received carriage return or newline

        if [10, 13, 10, 13, 127, 8].include?(char) # backspace and delete
          password.slice!(-1, 1)
        else
          # windows might throw a -1 at us so make sure to handle RangeError
          begin
            (password << char.chr)
          rescue StandardError
            RangeError
          end
        end
      end
      puts
      password
    end

    def ask_for_password
      echo_off
      trap('INT') do
        echo_on
        exit
      end
      password = ask
      puts
      echo_on
      password
    end

    def ask_for_and_save_credentials
      display "Please authenticate with #{admin_host}:"
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
      60.times { print '#' }
      print "\n"
    end

    def invalid_access!
      puts invalid_access_message.bold.red
    end

    def invalid_access_message
      "Error! You do not have access to #{Nimbu::Auth.site}.#{Nimbu::Auth.admin_host}! " +
        'Please check your site id or request access to your site owner.'
    end
  end
end
