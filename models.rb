require 'bundler/setup'
Bundler.require

ActiveRecord::Base.establish_connection

class Room < ActiveRecord::Base
    has_many :users
    has_many :entryrecords
end

class EntryRecord < ActiveRecord::Base
    belongs_to :user
    belongs_to :room
end

class User < ActiveRecord::Base
    has_secure_password
    validates :name,
        presence: true
    validates :password,
        presence: true,
        length: {in: 4..10}
    has_many :rooms
    has_many :entryrecords
end