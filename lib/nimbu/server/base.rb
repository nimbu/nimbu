# -*- encoding : utf-8 -*-
require 'sinatra'
require "sinatra/reloader"
require "sinatra/multi_route"
require "vendor/nimbu/okjson"
require 'term/ansicolor'
require "base64"
require "sinatra/json"
require 'json'
require 'rack/streaming_proxy'

module Nimbu
  module Server
    class Base < Sinatra::Base
      helpers Sinatra::JSON
      include Term::ANSIColor
      register Sinatra::MultiRoute

      configure :development do
        register Sinatra::Reloader
      end

      set :method_override, true
      set :static, true                             # set up static file routing
      set :public_folder, Dir.pwd # set up the static dir (with images/js/css inside)

      set :views,  File.expand_path('../views', __FILE__) # set up the views dir
      set :haml, { :format => :html5 }                    # if you use haml

      # Your "actions" go here…
      #

      get '/media/*' do
        proxy = Rack::StreamingProxy::ProxyRequest.new(request,"http://#{nimbu.host}/media/#{params[:splat].first}")
        return [proxy.status, proxy.headers, proxy]
      end

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

        method = (
          if request.get? then "get"
          elsif request.post? then "post"
          elsif request.put? then "put"
          elsif request.delete? then "delete"
          end
        )
        puts green("#{method.upcase} #{request.fullpath}")

        # if request.post? || request.put? || request.delete?
        #   ##### POST / PUT / DELET #####
        #   path = request.path == "/" ? request.path : request.path.gsub(/\/$/,'')
        #   begin
        #     response = nimbu.post_request({:path => path, :extra => params, :method => method, :client_session => session, :ajax => request.xhr? })
        #     puts "RESPONSE: #{response}" if Nimbu.debug
        #     result = json_decode(response)
        #     parse_session(result)
        #   rescue Exception => e
        #     if e.respond_to?(:http_body)
        #       return e.http_body
        #     else
        #       raise e
        #     end
        #   end

        #   session[:flash] = result["flash"] if result["flash"]
        #   if request.xhr?
        #     if !result["json"].nil?
        #       puts "JSON: #{result["json"]["data"]}" if Nimbu.debug
        #       status result["json"]["status"].to_i
        #       return json(result["json"]["data"], :encoder => :to_json, :content_type => :js)
        #     end
        #   else
        #     redirect result["redirect_to"] and return if result["redirect_to"]
        #   end
        # else
        #   # First get the template name and necessary subtemplates
        #   ##### GET #####
        #   path = request.path == "/" ? request.path : request.path.gsub(/\/$/,'')
        #   begin
        #     result = json_decode(nimbu.get_template({:path => path, :extra => params, :method => "get", :extra => params, :client_session => session, :ajax => request.xhr? }))
        #     puts result if Nimbu.debug
        #     parse_session(result)
        #   rescue Exception => e
        #     return e.http_body
        #   end

        #   redirect result["redirect_to"] and return if result["redirect_to"]
        # end
        ### GET THE TEMPLATES ###
        path = request.path == "/" ? request.path : request.path.gsub(/\/$/,'')
        if !request.xhr?
          begin
            params = ({} || params).merge({:simulator => {
                            :host => request.host,
                            :port => request.port,
                            :path => path,
                            :method => method,
                            :session => session,
                            :headers => request.env.to_json,
                          }})
            result = nimbu.simulator(:subdomain => Nimbu::Auth.site).recipe(params)
            puts result if Nimbu.debug
          rescue Exception => e
            if e.respond_to?(:http_body)
              return e.http_body
            else
              raise e
            end
          end

          if result["template"].nil?
            raise Sinatra::NotFound
          end

          unless result["template"] == "<<<< REDIRECT >>>>"
            template = result["template"].gsub(/buddha$/,'liquid')
            # Then render everything
            puts green(" => using template '#{template}'")
            # Read the template file
            template_file = File.join(Dir.pwd,'templates',template)
            template_file_haml = File.join(Dir.pwd,'templates',"#{template}.haml")

            if File.exists?(template_file)
              template_code = IO.read(template_file).force_encoding('UTF-8')
            elsif File.exists?(template_file_haml)
              template_code = IO.read(template_file_haml).force_encoding('UTF-8')
              template = "#{template}.haml"
            else
              puts red("Layout file '#{template_file}' is missing...")
              return render_missing(File.join('templates',template),'template')
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
            layout_file_haml = File.join(Dir.pwd,'layouts',"#{layout}.haml")

            if File.exists?(layout_file)
              layout_code = IO.read(layout_file).force_encoding('UTF-8')
            elsif File.exists?(layout_file_haml)
              layout = "#{layout}.haml"
              layout_code = IO.read(layout_file_haml).force_encoding('UTF-8')
            else
              puts red("Layout file '#{layout_file}' is missing...")
              return render_missing(File.join('layouts',layout),'layout')
            end

            puts green("    using layout '#{layout}'")

            begin
              snippets = parse_snippets(template_code)
              snippets = parse_snippets(layout_code,snippets)
            rescue Exception => e
              # If there is a snippet missing, we raise an error
              puts red("Snippet file '#{e.message}' is missing...")
              return render_missing(e.message,'snippet')
            end

            if snippets.any?
              puts green("    using snippets '#{snippets.keys.join('\', \'')}'")
            end
          end
        else
          template_file = ""
        end

        # Send the templates to the browser
        begin
          params = ({} || params).merge({:simulator => {
                          :path => path,
                          :code => {
                            :template_name => template,
                            :template => template_code,
                            :layout_name => layout,
                            :layout => layout_code,
                            :snippets => snippets,
                          },
                          :request => {
                            :host => request.host,
                            :port => request.port,
                            :method => method,
                            :session => session,
                            :headers => request.env.to_json
                          }
                        }})
          results = nimbu.simulator(:subdomain => Nimbu::Auth.site).render(params)
          puts results["status"] if Nimbu.debug
          puts results["headers"] if Nimbu.debug
          puts Base64.decode64(results["body"]).gsub(/\n/,'') if Nimbu.debug

          status results["status"]
          headers results["headers"] unless results["headers"] == ""
          body Base64.decode64(results["body"])
        rescue Exception => error
          puts "Error!"
          puts "Error! #{error.http_body}"
          html = error.http_body
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

      def parse_snippets(code, snippets = {})
        # Parse template file for snippets
        search = Regexp.new("\{\% include (.*) \%\}")
        matches = code.scan(search)
        if !matches.empty?
          matches.each do |snippet|
            # There seems to be a special layout?
            snippet_name = snippet[0].gsub(/,$/, '').gsub(/^'/, '').gsub(/'$/, '').gsub(/^"/, '').gsub(/"$/, '')
            if !(snippet_name =~ /\.liquid$/)
              snippet_name = "#{snippet_name}.liquid"
            end
            # Read the snippet file
            snippet_file = File.join(Dir.pwd,'snippets',snippet_name)
            snippet_file_haml = File.join(Dir.pwd,'snippets',"#{snippet_name}.haml")

            if File.exists?(snippet_file)
              snippet_code = IO.read(snippet_file).force_encoding('UTF-8')
              snippets[snippet_name.to_sym] = snippet_code
              self.parse_snippets(snippet_code, snippets)
            elsif File.exists?(snippet_file_haml)
              snippet_code = IO.read(snippet_file_haml).force_encoding('UTF-8')
              snippets["#{snippet_name}.haml".to_sym] = snippet_code
              self.parse_snippets(snippet_code, snippets)
            else
              raise "#{snippet_file}"
            end
          end
        end
        return snippets
      end

    end
  end
end
