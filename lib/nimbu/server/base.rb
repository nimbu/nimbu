require 'sinatra'
require 'haml' # if you use haml views
require "vendor/nimbu/okjson"

module Nimbu
  module Server
    class Base < Sinatra::Base
      set :static, true                             # set up static file routing
      set :public_folder, Dir.pwd # set up the static dir (with images/js/css inside)
      
      set :views,  File.expand_path('../views', __FILE__) # set up the views dir
      set :haml, { :format => :html5 }                    # if you use haml
      
      # Your "actions" go here…
      #

      get '/__sinatra__/*' do
        return ""
      end

      get '*' do
        puts "Getting template for #{request.path}"
        path = request.path == "/" ? request.path : request.path.gsub(/\/$/,'')
        template = json_decode(nimbu.get_template({:path => path}))["template"]
        if template.nil?
          raise Sinatra::NotFound
        end
        template = template.gsub(/buddha$/,'liquid')
        puts "Uploading assets for template '#{template}'"
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
          layout = 'default'
        end

        # Read the layout file
        layout_file = File.join(Dir.pwd,'layouts',layout)
        if File.exists?(layout_file)
          layout_code = IO.read(layout_file)
        else
          return "Layout file '#{layout_file}' is missing..."
        end

        # Send the templates to the browser
        results = json_decode(nimbu.get_page({:path => path, :template => template_code, :layout => layout_code}))

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