# frozen_string_literal: true

require 'sinatra'

module MockAuth
  class Web < Sinatra::Base
    set :public_folder, 'lib/mock_auth/public'

    get '/' do
      erb :'index.html'
    end
  end
end
