require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require './models.rb'

enable :sessions

get '/' do
  erb :index
end
