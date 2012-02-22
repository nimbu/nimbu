require 'sinatra'
require 'haml' # if you use haml views

module Nimbu
  module Server
    class Base < Sinatra::Base

      set :static, true                             # set up static file routing
      set :public_folder, Dir.pwd # set up the static dir (with images/js/css inside)
      
      set :views,  File.expand_path('../views', __FILE__) # set up the views dir
      set :haml, { :format => :html5 }                    # if you use haml
      
      # Your "actions" go here…
      #
      get '/' do
        return "Hello World Again"
      end
      
    end
  end
end