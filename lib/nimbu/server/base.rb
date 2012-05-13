require 'sinatra'
require "sinatra/reloader"
require "sinatra/multi_route"
require "vendor/nimbu/okjson"
require 'term/ansicolor'

module Nimbu
  module Server
    class Base < Sinatra::Base
      include Term::ANSIColor
      register Sinatra::MultiRoute

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

      # post '*' do
      #   path = request.path == "/" ? request.path : request.path.gsub(/\/$/,'')
      #   result = json_decode(nimbu.post_request({:path => path, :extra => params, :session => session}))

      #   session[:logged_in] = true if result["logged_in"]
      #   session[:flash] = result["flash"] if result["flash"]
      #   redirect result["redirect_to"] and return if result["redirect_to"]
      # end

      route :get, :post, :put, :delete, '*' do
        verb = (
          if request.get? then "GET"
          elsif request.post? then "POST"
          elsif request.put? then "PUT"
          elsif request.delete? then "DELETE"  
          end
        )
        puts green("#{verb} #{request.fullpath}")
        if request.post? || request.put? || request.delete?
          path = request.path == "/" ? request.path : request.path.gsub(/\/$/,'')
          begin
            method = "post" if request.post?
            method = "put" if request.put?
            method = "delete" if request.delete?

            result = json_decode(nimbu.post_request({:path => path, :extra => params, :session => session, :method => method, :logged_in => session[:logged_in]})) 
          rescue Exception => e
            return e.http_body
          end

          session[:logged_in] = true if result["logged_in"]
          session[:flash] = result["flash"] if result["flash"]
          redirect result["redirect_to"] and return if result["redirect_to"]
        else
          # First get the template name and necessary subtemplates
          path = request.path == "/" ? request.path : request.path.gsub(/\/$/,'')
          begin
            result = json_decode(nimbu.get_template({:path => path, :extra => params, :method => "get", :extra => params, :logged_in => session[:logged_in]}))
          rescue Exception => e
            return e.http_body
          end

          session[:logged_in] = result["logged_in"] if result.has_key?("logged_in")
          redirect result["redirect_to"] and return if result["redirect_to"]
        end
        
        if result["template"].nil?
          raise Sinatra::NotFound
        end
        template = result["template"].gsub(/buddha$/,'liquid')
        # Then render everything
        puts green(" => using template '#{template}'")
        # Read the template file
        template_file = File.join(Dir.pwd,'templates',template)
        if File.exists?(template_file)
          template_code = IO.read(template_file)
        else
          return render_missing_template(File.join('templates',template))
        end

        if template_code=~ /You have an Error in your HAML code/
          return template_code
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

        # Send the templates to the browser
        begin
          response = nimbu.get_request({:path => path, :template => template_code, :layout => layout_code, :extra => params, :logged_in => session[:logged_in], :method => request.post? ? "post" : "get"})
          results = json_decode(response)
          return "#{results["result"]}"
        rescue RestClient::Exception => error
          return error.http_body
        end       
      end

      error 404 do
        render_404(request.path)
      end

      protected

      def render_missing_template(template)
        @messag = ""
        @messag += "<h1>A template file is missing!</h1>"
        @messag += "<p>Template location: <strong>#{template}</strong></p>"
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

    end
  end
end