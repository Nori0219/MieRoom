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
require 'line/bot'

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
    # if  request.path != '/signin' && request.path != '/signup' && request.path != '/callback' && current_user.nil?
    #   redirect '/signin'
    #   puts "ログインしていないユーザーがアクセス redirect:/signin"
    # end
end

# ====== LINEBot ======
def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_id = ENV["LINE_CHANNEL_ID"]
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

post '/callback' do
  @message_context = {}
  body = request.body.read
  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end
  events = client.parse_events_from(body)
  events.each do |event|
    if event.is_a?(Line::Bot::Event::Message)
      if event.type === Line::Bot::Event::MessageType::Text
        user_message = event.message['text']
  
        if user_message == '部屋状況を確認する'
          rooms = Room.all
          # ルーム名を取得して改行で区切る
          # ルーム名を取得して一覧形式のテキストを作成
          room_list_text = "現在の部屋状況はこちらです！\n【ルーム一覧】"
          
          # 日本時間の今日の朝7時を取得(UTCとの誤差は+9.hours)
          @tokyo_now = Time.now.in_time_zone('Asia/Tokyo')
          @yesterday_morning_7am = @tokyo_now.beginning_of_day - 1.day + 7.hours
          @tommorow_morning_7am = @tokyo_now.beginning_of_day + 1.day + 7.hours
          # today_morning_7am = @tokyo_now.beginning_of_day + 7.hours
          start_of_day = @tokyo_now.beginning_of_day + 7.hours
          @tody_date=start_of_day.strftime('%m/%d %H:%M')
          puts "レコード表示開始時刻：#{start_of_day}"
          
          rooms.each do |room|
            # 日本時間の昨日から今日の朝7時以降の入室記録を取得
            if @tokyo_now < start_of_day
              # 日付が7:00未満の場合、前日から今日の範囲
              @todays_entry_records = room.entry_records.where('created_at >= ? AND created_at < ?',  @yesterday_morning_7am, start_of_day )
            else
              # 7:00以降の場合、今日から翌日の範囲
              @todays_entry_records = room.entry_records.where('created_at >= ? AND created_at < ?',  start_of_day , @tommorow_morning_7am)
            end
            # 現在在室中のレコードのみを取得
            @current_entry_records = @todays_entry_records.where(exit_time: nil)
            room_list_text += "\n#{room.name}：#{@current_entry_records.count}人"
          end
          
          roominfo_message = {
            type: 'text',
            text: room_list_text
          }
          pr_message = {
            type: 'text',
            text: 
            "【📣本日の利用者状況】\nユーザー登録するとメニューから誰が利用したか確認できます！"
          }
          messages = [roominfo_message, pr_message]
          
          client.reply_message(event['replyToken'], messages)
        else
            # ユーザーがルーム名を送信した場合
            room_name = user_message
            # ルーム名を元にルームを検索
            room = Room.find_by(name: room_name)
            
            if room
                
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
                @todays_entry_records = room.entry_records.where('created_at >= ? AND created_at < ?',  @yesterday_morning_7am, start_of_day )
              else
                # 7:00以降の場合、今日から翌日の範囲
                @todays_entry_records = room.entry_records.where('created_at >= ? AND created_at < ?',  start_of_day , @tommorow_morning_7am)
              end
              # 現在在室中のレコードのみを取得
              @current_entry_records = @todays_entry_records.where(exit_time: nil)
                roominfo_message = {
                  type: 'text',
                  text: 
                  "【#{room.name}】\n現在の在室人数は#{@current_entry_records.count}人です！"
                }
                pr_message = {
                  type: 'text',
                  text: 
                  "【📣本日の利用者状況】\nユーザー登録するとメニューから誰が利用したか確認できます！"
                }
                
                messages = [roominfo_message, pr_message]
                client.reply_message(event['replyToken'], messages)
            end
        end
      end
    end
  end
  "OK"
end


get '/' do
  @rooms = Room.all
  erb :index
end

# ====== LINEログイン ユーザー情報を登録 ======
post '/line_login' do
  # LINEプロフィール情報を受け取り
  request_body = JSON.parse(request.body.read)
  
   # JSONデータから必要な情報を抽出
  line_name = request_body['line_name']
  line_uid = request_body['line_id']
  line_icon_url = request_body['line_icon_url']
  
  puts"LINEInfo: #{line_name},#{line_uid},#{line_icon_url}"
  # 既存のユーザーをLINE IDで検索
  user = User.find_by(line_uid: line_uid)
  
  if user.nil?
    # LINE IDに対応するユーザーが存在しない場合、新規登録
    user = User.create(
      name: line_name,
      line_uid: line_uid,
      image: line_icon_url
    )
    puts "LINE IDが見つかりませんでした。新規ユーザー登録しました"
  end
  
  if user.persisted?
    session[:user] = user.id
    puts "サインアップ完了LINEログイン完了"
    redirect '/'
  else
    puts "サインアップできませんでした"
  end
end

# get '/signin' do
#   erb :sign_in
# end

# get '/signup' do
#   erb :sign_up
# end

# get '/signout' do
#   session[:user] = nil
#   redirect '/'
# end

# post '/signin' do
#   user = User.find_by(name: params[:name])
#     if user && user.authenticate(params[:password])
#         session[:user] = user.id
#         redirect '/'
#     else
#       puts "サインインできませんできた"
#       redirect '/signin'
#     end
# end

# post '/signup' do
#   if params[:upload_photo]
#     image = params[:upload_photo]
#     tempfile = image[:tempfile]
#     upload = Cloudinary::Uploader.upload(tempfile.path)
#     img_url = upload['url']
#   else
#     img_url = url('/images/hito.png')
#   end
  
#   user = User.create(
#         name: params[:name],
#         password: params[:password],
#         password_confirmation: params[:password_confirmation],
#         image: img_url
#     )
#     if user.persisted?
#       session[:user] = user.id
#       puts "サインアップ完了"
#       redirect '/'
#     else
#       puts "サインアップできませんでした"
#       redirect '/signup'
#     end
    
# end

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
    img_url = url('/images/room.png')
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
  
  if current_user
     # ユーザーが最後に入室した記録を取得
    @latest_entry = @room.entry_records.where(user_id: current_user.id, exit_time: nil).order(created_at: :desc).first
  end

  erb :room
end


# https://mieroom-production.up.railway.app/room/1/entry?user_id=1
# https://mieroom-production.up.railway.app/room/1/exit?user_id=1
# https://2f99-54-168-49-46.ngrok-free.app//room/:id/entry
post '/room/entry' do
  room_id = params[:room_id]
  room = Room.find_by(id: room_id)
  
  if room.nil?
    # ルームが存在しない場合のエラーハンドリング
    puts "指定されたルームが存在しません"
    return 404
  end
  
  if current_user
    line_uid = current_user.line_uid
  else
    #ログインせずpostメソッドを叩いた時,getメソッドでは出来た
    line_uid = params[:line_uid]
    puts "外部からentry処理を実行"
  end
  
  latest_entry_record = room.entry_records.where(line_uid: line_uid, exit_time: nil).order(created_at: :desc).first

  if latest_entry_record
     puts'すでに入室しています'
  else
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
  end
  redirect "/room/#{room_id}"
end


post '/room/exit' do
  room_id = params[:room_id]
  room = Room.find_by(id: room_id)
  
  if room.nil?
    # ルームが存在しない場合のエラーハンドリング
    puts "指定されたルームが存在しません"
    redirect '/rooms'
  end
  
  if current_user
    line_uid = current_user.line_uid
  else
    line_uid = params[:line_uid]
    puts "外部からentry処理を実行"
  end
  # 最後に入室した記録を取得
  @latest_entry_record = room.entry_records.where(line_uid: line_uid, exit_time: nil).order(created_at: :desc).first

  if @latest_entry_record
    # 退室時間を記録
    @latest_entry_record.update(exit_time: Time.now)
     puts'退室しました'
  else
     puts '入室していないか、既に退室済みです'
  end

  redirect "/room/#{room_id}" 
end

