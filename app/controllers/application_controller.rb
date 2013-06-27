class ApplicationController < ActionController::Base
  protect_from_forgery

  def connect
  	Dropbox::API::Client.new(:token  => Sitely::ACCESS_TOKEN, :secret => Sitely::SECRET)
  end
end
