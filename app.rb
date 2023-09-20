require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require 'sinatra/activerecord'
require './models.rb'

require 'dotenv/load'

require 'cloudinary'
require 'cloudinary/uploader'
require 'cloudinary/utils'
require 'date'

enable :sessions

helpers do
  
  def current_user
      User.find_by(id: session[:user])
  end
    
    # タイムゾーン変換と指定フォーマットで時刻を表示
  def format_entry_time(entry_record)
    entry_record.entry_time.in_time_zone('Asia/Tokyo').strftime('%H:%M')
  end
  
  def format_exit_time(entry_record)
    entry_record.exit_time.in_time_zone('Asia/Tokyo').strftime('%H:%M')
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
    if  request.path != '/signin' && request.path != '/signup' && current_user.nil?
      redirect '/signin'
      puts "ログインしていないユーザーがアクセス redirect:/signin"
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

get '/signout' do
  session[:user] = nil
  redirect '/'
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

get '/user/record' do
  @user_rooms = current_user.rooms
  erb :user_record
end

get '/table' do
  erb :table
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



get '/room/:id' do
  @room = Room.find(params[:id])
  
  # 日本時間の今日の朝7時を取得(UTCとの誤差は+9.hours)
  @tokyo_now = Time.now.in_time_zone('Asia/Tokyo')
  @yesterday_morning_7am = @tokyo_now.beginning_of_day - 1.day + 7.hours
  @tommorow_morning_7am = @tokyo_now.beginning_of_day + 1.day + 7.hours
  # today_morning_7am = @tokyo_now.beginning_of_day + 7.hours
  start_of_day = @tokyo_now.beginning_of_day + 7.hours
  @tody_date=start_of_day.strftime('%m/%d %H:%M')
  puts "レコード表示開始時刻：#{start_of_day}"

  # 日本時間の昨日から今日の朝7時以降の入室記録を取得
  if @tokyo_now < start_of_day
    # 日付が7:00未満の場合、前日から今日の範囲
    @todays_entry_records = @room.entry_records.where('created_at >= ? AND created_at < ?',  @yesterday_morning_7am, start_of_day )
  else
    # 7:00以降の場合、今日から翌日の範囲
    @todays_entry_records = @room.entry_records.where('created_at >= ? AND created_at < ?',  start_of_day , @tommorow_morning_7am)
  end
  # 現在在室中のレコードのみを取得
  @current_entry_records = @todays_entry_records.where(exit_time: nil)
   # ユーザーが最後に入室した記録を取得
  @latest_entry = @room.entry_records.where(user_id: current_user.id, exit_time: nil).order(created_at: :desc).first
  erb :room
end

# /room/1/entry?user_id=2
post '/room/:id/entry' do
  room_id = params[:id]
  if current_user
    user_id = current_user.id
  else
    #ログインせずpostメソッドを叩いた時,getメソッドでは出来た
    user_id = params[:user_id]
    puts "外部からentry処理を実行"
  end

  entry_record = EntryRecord.new(
    user_id: user_id, 
    room_id: room_id,
    entry_time: Time.now # 現在の日時を入室時間として記録
  )

  if entry_record.save
    puts "入室しました。"
  else
    puts "入室に失敗しました"
  end

  redirect "/room/#{room_id}" 
end


post '/room/:id/exit' do
  room_id = params[:id]
  user_id = current_user.id
  room = Room.find_by(id: room_id)
  unless room
     puts '指定されたルームが存在しません。'
    redirect '/rooms' # ルーム一覧にリダイレクト
  end
  # 最後に入室した記録を取得
  @latest_entry_record = room.entry_records.where(user_id: user_id, exit_time: nil).order(created_at: :desc).first

  if @latest_entry_record
    # 退室時間を記録
    @latest_entry_record.update(exit_time: Time.now)
     puts'退室しました'
  else
     puts '入室していないか、既に退室済みです'
  end

  redirect "/room/#{room_id}" 
end