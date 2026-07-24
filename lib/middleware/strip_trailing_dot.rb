module Middleware
  class StripTrailingDot
    def initialize(app)
      @app = app
    end

    def call(env)
      path = env['PATH_INFO']
      if path
        env['PATH_INFO'] = path.gsub(/\.\//, '/').sub(/\.$/, '')
      end
      @app.call(env)
    end
  end
end
