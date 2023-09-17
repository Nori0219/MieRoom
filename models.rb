require 'bundler/setup'
Bundler.require

ActiveRecord::Base.establish_connection

class Room < ActiveRecord::Base
    has_many :users
    has_many :entry_records
    has_many :users, :through => :entry_records
    
end

class EntryRecord < ActiveRecord::Base
    belongs_to :user
    belongs_to :room
    
    # ユーザーが滞在中かどうかを判定するメソッド
  def in_progress?
    exit_time.nil? # 退室時間が設定されていなければ滞在中とみなす
  end
end

class User < ActiveRecord::Base
    has_secure_password
    validates :name,
        presence: true
    validates :password,
        presence: true,
        length: {in: 4..10}
    has_many :rooms
    has_many :entry_records
end