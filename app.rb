require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require 'sinatra/activerecord'
require './models.rb'

require 'dotenv/load'

require 'cloudinary'
require 'cloudinary/uploader'
require 'cloudinary/utils'

enable :sessions

helpers do
    def current_user
        User.find_by(id: session[:user])
    end
end

before do
    Dotenv.load
    Cloudinary.config do |config|
      config.cloud_name = ENV['CLOUD_NAME']
      config.api_key = ENV['CLOUDINARY_API_KEY']  
      config.api_secret = ENV['CLOUDINARY_API_SECRET']  
      config.secure = true
    end
end

get '/' do
  @rooms = Room.all
  erb :index
end



get '/signin' do
  erb :sign_in
end

get '/signup' do
  erb :sign_up
end

post '/signin' do
  user = User.find_by(name: params[:name])
    if user && user.authenticate(params[:password])
        session[:user] = user.id
        redirect '/'
    else
      puts "サインインできませんできた"
      redirect '/signin'
    end
end

post '/signup' do
  if params[:upload_photo]
     image = params[:upload_photo]
     tempfile = image[:tempfile]
     upload = Cloudinary::Uploader.upload(tempfile.path)
     img_url = upload['url']
  else
    img_url = url('/images/hito.png')
  end
  
  user = User.create(
        name: params[:name],
        password: params[:password],
        password_confirmation: params[:password_confirmation],
        image: img_url
    )
    if user.persisted?
      session[:user] = user.id
      puts "サインアップ完了"
      redirect '/'
    else
      puts "サインアップできませんでした"
      redirect '/signup'
    end
    
end

get '/user_record' do
  erb :user_record
end

get '/room/new' do
  erb :room_new
end

post '/room/new' do
  if params[:upload_photo]
     image = params[:upload_photo]
     tempfile = image[:tempfile]
     upload = Cloudinary::Uploader.upload(tempfile.path)
     img_url = upload['url']
     puts "Room_imageあり"
  else
    img_url = url('/images/hito.png')
    puts "Room_imageなし"
  end
  
  room = Room.create(
        name: params[:name],
        image: img_url
    )
    if room.persisted?
      puts "ルーム登録"
      redirect '/'
    else
      puts "ルーム登録できませんでした"
      redirect '/room/new'
    end
end
