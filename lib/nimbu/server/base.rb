require 'sinatra'
require "sinatra/reloader"
require "vendor/nimbu/okjson"
require 'term/ansicolor'

module Nimbu
  module Server
    class Base < Sinatra::Base
      include Term::ANSIColor
      enable :sessions

      configure :development do
        register Sinatra::Reloader
      end

      set :static, true                             # set up static file routing
      set :public_folder, Dir.pwd # set up the static dir (with images/js/css inside)
      
      set :views,  File.expand_path('../views', __FILE__) # set up the views dir
      set :haml, { :format => :html5 }                    # if you use haml
      
      # Your "actions" go here…
      #

      get '/__sinatra__/*' do
        return ""
      end

      get '/favicon.ico' do
        return ""
      end

      post '*' do
        path = request.path == "/" ? request.path : request.path.gsub(/\/$/,'')
        result = json_decode(nimbu.post_request({:path => path, :extra => params, :session => session}))

        session[:logged_in] = true if result["logged_in"]
        session[:flash] = result["flash"] if result["flash"]
        redirect result["redirect_to"] if result["redirect_to"]
      end

      get '*' do
        puts green("Getting template for #{request.fullpath}")
        path = request.path == "/" ? request.path : request.path.gsub(/\/$/,'')
        result = json_decode(nimbu.get_template({:path => path, :extra => params}))

        session[:logged_in] = result["logged_in"] if result.has_key?("logged_in")
        redirect result["redirect_to"] if result["redirect_to"]
        
        if result["template"].nil?
          raise Sinatra::NotFound
        end
        template = result["template"].gsub(/buddha$/,'liquid')
        puts green("Uploading assets for template '#{template}'")
        # Read the template file
        template_file = File.join(Dir.pwd,'templates',template)
        if File.exists?(template_file)
          template_code = IO.read(template_file)
        else
          return "Template file '#{template_file}' is missing..."
        end

        # Parse template file for a special layout
        search = Regexp.new("\{\% layout \'(.*)\' \%\}")
        if search =~ template_code
          # There seems to be a special layout?
          layout = $1
        else
          layout = 'default.liquid'
        end

        # Read the layout file
        layout_file = File.join(Dir.pwd,'layouts',layout)
        if File.exists?(layout_file)
          layout_code = IO.read(layout_file)
        else
          puts red("Layout file '#{layout_file}' is missing...") 
          return "Layout file '#{layout_file}' is missing..."
        end

        puts red("logged_in") if session[:logged_in]

        # Send the templates to the browser
        results = json_decode(nimbu.get_request({:path => path, :template => template_code, :layout => layout_code, :extra => params, :logged_in => session[:logged_in]}))

        return "#{results["result"]}"
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

      error 404 do
        'This page does not exist.'
      end
    end
  end
end