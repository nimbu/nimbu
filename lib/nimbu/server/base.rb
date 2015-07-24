# -*- encoding : utf-8 -*-
require 'sinatra'
require "sinatra/reloader"
require "sinatra/multi_route"
require "sinatra/cookies"
require "vendor/nimbu/okjson"
require 'term/ansicolor'
require "base64"
require "sinatra/json"
require 'json'
require 'rack/streaming_proxy'

module Nimbu
  module Server
    class Base < Sinatra::Base
      include Term::ANSIColor

      helpers Sinatra::JSON
      helpers Sinatra::Cookies
      register Sinatra::MultiRoute

      set :method_override, true
      set :static, true                             # set up static file routing
      set :public_folder, Dir.pwd # set up the static dir (with images/js/css inside)

      set :views,  File.expand_path('../views', __FILE__) # set up the views dir
      set :haml, { format: :html5 }                    # if you use haml

      use Rack::StreamingProxy::Proxy do |request|
        if request.path.start_with?('/favicon.ico')
          "http://#{Nimbu::Auth.site}.#{Nimbu::Auth.admin_host}/favicon.ico"
        end
      end

      Rack::StreamingProxy::Proxy.logger = Logger.new("/dev/null")

      # Your "actions" go here…
      #

      get '/__sinatra__/*' do
        return ""
      end

      route :get, :post, :put, :delete, :patch, '*' do
        # clear the session after a restart of the browser

        method = detect_http_method(request)
        @templates = {}

        if !Nimbu.cli_options[:nocookies] && cookies["nimbu_simulator_id"] != Nimbu::Auth.simulator_id
          puts yellow("Refreshing session for simulation...")
          cookies.each {|k,v| cookies.delete(k)}
          response.set_cookie "nimbu_simulator_id", { :value => Nimbu::Auth.simulator_id, :http_only => false, :path => "/" }
          redirect to(request.path) and return
        end

        puts green("#{method.upcase} #{request.fullpath}")

        ### GET THE RECIPE FOR RENDERING THIS PAGE ###
        path = extract_path(request)
        templates = pack_templates!

        params = {
          simulator: {
            version: "v2",
            path:    path,
            code:    templates,
            request: {
              host:    request.host,
              port:    request.port,
              params:  request.params || {},
              method:  method,
              session: session,
              headers: request.env.to_json
            }
          }
        }

        # Send the templates to the browser
        begin
          results = nimbu.simulator(subdomain: Nimbu::Auth.site).render(params)
          puts results["status"] if Nimbu.debug
          puts results["headers"] if Nimbu.debug
          puts Base64.decode64(results["body"]).gsub(/\n/,'') if Nimbu.debug

          status results["status"]
          headers results["headers"] unless results["headers"] == ""
          body Base64.decode64(results["body"])
        rescue Exception => error
          puts "Error! #{error.http_body}"
          error.http_body
        end
      end

      error 404 do
        render_404(request.path)
      end

      protected

      def detect_http_method(request)
        if request.get?       then "get"
        elsif request.post?   then "post"
        elsif request.patch?  then "patch"
        elsif request.put?    then "put"
        elsif request.delete? then "delete"
        end
      end

      def extract_path(request)
        if request.path == "/"
          request.path
        else
          request.path.gsub(/\/$/,'')
        end
      end

      def render_missing_template(template)
        @messag = ""
        @messag += "<h1>A template file is missing!</h1>"
        @messag += "<p>Template location: <strong>#{template}</strong></p>"
        return render_error(@messag)
      end

      def render_missing(file, type)
        @messag = ""
        @messag += "<h1>A #{type} file is missing!</h1>"
        @messag += "<p>Expected #{type} location: <strong>#{file}</strong></p>"
        return render_error(@messag)
      end

      def render_404(path)
        @messag = ""
        @messag += "<h1>This page does not exist!</h1>"
        @messag += "<p>Current path: <strong>#{path}</strong></p>"
        return render_error(@messag)
      end

      def render_error(content)
        @messag = ""
        #@messag += "<html><head><title>ERROR IN CODE</title>"
        #CSS for error styling.
        @messag += "<style type = \"text/css\">"
        @messag +="body { background-color: #fff; margin: 40px; font-family: Lucida Grande, Verdana, Sans-serif; font-size: 12px; color: #000;}"
        @messag +="#content { border: #999 1px solid; background-color: #fff; padding: 20px 20px 12px 20px;}"
        @messag +="h1 { font-weight: normal; font-size: 14px; color: #990000; margin: 0 0 4px 0; }"
        @messag += "</style>"
        @messag += "<div id=\"content\">"
        @messag += content
        @messag += "</div>"
        return @messag
      end

      def json_encode(object)
        Nimbu::OkJson.encode(object)
      rescue Nimbu::OkJson::ParserError
        nil
      end

      def json_decode(json)
        Nimbu::OkJson.decode(json)
      rescue Nimbu::OkJson::ParserError
        nil
      end

      def nimbu
        Nimbu::Auth.client
      end

      def debug(message)
        puts message if Nimbu.debug
      end

      def pack_templates!
        ["layouts","templates","snippets"].each do |type|
          load_files(type)
        end
        Base64.encode64(Zlib::Deflate.deflate(@templates.to_json, Zlib::DEFAULT_COMPRESSION))
      end

      def load_files(type)
        glob = Dir["#{Dir.pwd}/#{type}/**/*.liquid","#{Dir.pwd}/#{type}/**/*.liquid.haml"]
        directory = "#{Dir.pwd}/#{type}/"
        glob.each do |file|
          name = file.gsub(/#{directory}/i,"")
          code = IO.read(file).force_encoding('UTF-8')
          @templates[type] ||= {}
          @templates[type][name.to_s] = code
        end
      end

    end
  end
end
