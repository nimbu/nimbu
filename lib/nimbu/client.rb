require 'rexml/document'
require 'rest_client'
require 'uri'
require 'time'
require 'nimbu/auth'
require 'nimbu/helpers'
require 'nimbu/version'

# A Ruby class to call the Nimbu REST API.  You might use this if you want to
# manage your Nimbu apps from within a Ruby program, such as Capistrano.
#
# Example:
#
#   require 'nimbu'
#   nimbu = Nimbu::Client.new('me@example.com', 'mypass')
#   nimbu.create('myapp')
#
class Nimbu::Client

  include Nimbu::Helpers
  extend Nimbu::Helpers

  def self.version
    Nimbu::VERSION
  end

  def self.gem_version_string
    "nimbu-gem/#{version}"
  end

  attr_accessor :host, :user, :password

  def self.auth(user, password, host=Nimbu::Auth.host)
    client = new(user, password, host)
    json_decode client.post('/login', { :user => {:email => user, :password => password }}, :accept => 'json').to_s
  end

  def initialize(user, password, host=Nimbu::Auth.host)
    @user = user
    @password = password
    @host = host
  end

  # Show a list of sites
  def list
    doc = xml(get('/sites').to_s)
    doc.elements.to_a("//sites/site").map do |a|
      name = a.elements.to_a("name").first
      owner = a.elements.to_a("domain").first
      [name.text, owner.text]
    end
  end

  # Show info such as mode, custom domain, and collaborators on an app.
  def info(name_or_domain)
    raise ArgumentError.new("name_or_domain is required for info") unless name_or_domain
    name_or_domain = name_or_domain.gsub(/^(http:\/\/)?(www\.)?/, '')
    doc = xml(get("/apps/#{name_or_domain}").to_s)
    attrs = hash_from_xml_doc(doc)[:app]
    attrs.merge!(:collaborators => list_collaborators(attrs[:name]))
    attrs.merge!(:addons        => installed_addons(attrs[:name]))
  end

  def on_warning(&blk)
    @warning_callback = blk
  end

  def get_template(params)
    post("/engine/template",params)
  end

  def get_request(params)
    post("/engine/render",params)
  end

  def post_request(params)
    post("/engine/process",params)
  end

  def list_themes
    get("/themes")
  end

  def show_theme_contents(theme)
    get("/themes/#{theme}/list")
  end

  def fetch_theme_layout(theme,id)
    get("/themes/#{theme}/layouts/#{id}")
  end

  def fetch_theme_template(theme,id)
    get("/themes/#{theme}/templates/#{id}")
  end

  def fetch_theme_assets(theme,id)
    get("/themes/#{theme}/assets/#{id}")
  end

  def upload_layout(theme,name,content)
    post("/themes/#{theme}/layouts", {:name => name, :content => content})
  end

  def upload_template(theme,name,content)
    post("/themes/#{theme}/templates", {:name => name, :content => content})
  end

  def upload_snippet(theme,name,content)
    post("/themes/#{theme}/snippets", {:name => name, :content => content})
  end

  def upload_asset(theme,name,file)
    post("/themes/#{theme}/assets", {:name => name, :file => file})
  end

  ##################

  def resource(uri, options={})
    if http_proxy
      RestClient.proxy = http_proxy
    end
    resource = RestClient::Resource.new(realize_full_uri(uri), options)
    resource
  end

  def get(uri, extra_headers={})    # :nodoc:
    process(:get, uri, extra_headers)
  end

  def post(uri, payload="", extra_headers={})    # :nodoc:
    process(:post, uri, extra_headers, payload)
  end

  def put(uri, payload, extra_headers={})    # :nodoc:
    process(:put, uri, extra_headers, payload)
  end

  def delete(uri, extra_headers={})    # :nodoc:
    process(:delete, uri, extra_headers)
  end

  def process(method, uri, extra_headers={}, payload=nil)
    headers  = nimbu_headers.merge(extra_headers)
    args     = [method, payload, headers].compact

    resource_options = default_resource_options_for_uri(uri)

    begin
      response = resource(uri, resource_options).send(*args)
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError
      host = URI.parse(realize_full_uri(uri)).host
      error "Unable to connect to #{host}"
    rescue RestClient::SSLCertificateNotVerified => ex
      host = URI.parse(realize_full_uri(uri)).host
      error "WARNING: Unable to verify SSL certificate for #{host}\nTo disable SSL verification, run with HEROKU_SSL_VERIFY=disable"
    end

    extract_warning(response)
    response
  end

  def extract_warning(response)
    return unless response
    if response.headers[:x_nimbu_warning] && @warning_callback
      warning = response.headers[:x_nimbu_warning]
      @displayed_warnings ||= {}
      unless @displayed_warnings[warning]
        @warning_callback.call(warning)
        @displayed_warnings[warning] = true
      end
    end
  end

  def nimbu_headers   # :nodoc:
    {
      'X-Nimbu-API-Version'  => '1',
      'X-Nimbu-Token'       => password,
      'User-Agent'           => self.class.gem_version_string,
      'X-Ruby-Version'       => RUBY_VERSION,
      'X-Ruby-Platform'      => RUBY_PLATFORM
    }
  end

  def xml(raw)   # :nodoc:
    REXML::Document.new(raw)
  end

  def escape(value)  # :nodoc:
    escaped = URI.escape(value.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    escaped.gsub('.', '%2E') # not covered by the previous URI.escape
  end

  module JSON
    def self.parse(json)
      json_decode(json)
    end
  end

  private

  def configure_addon(action, app_name, addon, config = {})
    response = update_addon action,
                            addon_path(app_name, addon),
                            config

    json_decode(response.to_s) unless response.to_s.empty?
  end

  def addon_path(app_name, addon)
    "/apps/#{app_name}/addons/#{escape(addon)}"
  end

  def update_addon(action, path, config)
    params  = { :config => config }
    app     = params[:config].delete(:confirm)
    headers = { :accept => 'application/json' }
    params.merge!(:confirm => app) if app

    case action
    when :install
      post path, params, headers
    when :upgrade
      put path, params, headers
    when :uninstall
      confirm = app ? "confirm=#{app}" : ''
      delete "#{path}?#{confirm}", headers
    end
  end

  def realize_full_uri(given)
    full_host = (host =~ /^http/) ? host : "http://#{host}"
    host = URI.parse(full_host)
    uri = URI.parse(given)
    uri.host ||= host.host
    uri.scheme ||= host.scheme || "http"
    uri.path = "/api/v1" + ((uri.path[0..0] == "/") ? uri.path : "/#{uri.path}")
    uri.port = host.port if full_host =~ /\:\d+/
    uri.to_s
  end

  def default_resource_options_for_uri(uri)
    if ENV["HEROKU_SSL_VERIFY"] == "disable"
      {}
    elsif realize_full_uri(uri) =~ %r|^https://api.getnimbu.com|
      { :verify_ssl => OpenSSL::SSL::VERIFY_PEER, :ssl_ca_file => local_ca_file }
    else
      {}
    end
  end

  def local_ca_file
    File.expand_path("../../../data/cacert.pem", __FILE__)
  end

  def hash_from_xml_doc(elements)
    elements.inject({}) do |hash, e|
      next(hash) unless e.respond_to?(:children)
      hash.update(e.name.gsub("-","_").to_sym => case e.children.length
        when 0 then nil
        when 1 then e.text
        else hash_from_xml_doc(e.children)
      end)
    end
  end

  def http_proxy
    proxy = ENV['HTTP_PROXY'] || ENV['http_proxy']
    if proxy && !proxy.empty?
      unless /^[^:]+:\/\// =~ proxy
        proxy = "http://" + proxy
      end
      proxy
    else
      nil
    end
  end

  def https_proxy
    proxy = ENV['HTTPS_PROXY'] || ENV['https_proxy']
    if proxy && !proxy.empty?
      unless /^[^:]+:\/\// =~ proxy
        proxy = "https://" + proxy
      end
      proxy
    else
      nil
    end
  end
end
