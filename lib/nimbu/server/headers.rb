module Nimbu
  module Server
    class Headers
      def initialize(app)
        @app = app
      end
    
      def call(env)
        # Add user agent as X-Nimbu-Simulator header
        env['HTTP_X_NIMBU_SIMULATOR'] = Nimbu::Auth.user_agent

        @app.call(env)
      end
    end
  end
end
  