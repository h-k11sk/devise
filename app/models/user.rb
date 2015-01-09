class User < ActiveRecord::Base
  has_many :microposts, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :event_series, dependent: :destroy 

  has_many :relationships, foreign_key: "follower_id", dependent: :destroy
  has_many :followed_users, through: :relationships, source: :followed
  has_many :reverse_relationships, foreign_key: "followed_id", class_name: "Relationship", dependent: :destroy
  has_many :followers, through: :reverse_relationships, source: :follower


  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,:omniauthable

  validates :username, presence: true, uniqueness: true
  validates :email, presence: true




  def self.find_for_facebook_oauth(auth, signed_in_resource=nil)
    user = User.where(:provider => auth.provider, :uid => auth.uid).first
    unless user
      user = User.create(username:     auth.extra.raw_info.name,
                         provider: auth.provider,
                         uid:      auth.uid,
                         email:    auth.info.email
                        )
    end
    user
  end

  def self.find_for_twitter_oauth(auth, signed_in_resource=nil)
    user = User.where(:provider => auth.provider, :uid => auth.uid).first
    unless user
      user = User.create(username:     auth.info.nickname,
                         provider: auth.provider,
                         uid:      auth.uid,
                         email:    User.create_unique_email
                        )
    end
    user
  end


  def self.find_for_google_oauth2(auth, signed_in_resource=nil)
    user = User.where(email: auth.info.email).first
    unless user
      user = User.create(username:     auth.info.name,
                         provider: auth.provider,
                         uid:      auth.uid,
                         email:    auth.info.email,
                         token:    auth.credentials.token,
                         refresh_token: auth.credentials.refresh_token,
                         expires_in: auth.credentials.expires_in)
                        # password: Devise.friendly_token[0, 20])
    end
    user
  end


  def self.create_unique_string
    SecureRandom.uuid
  end

  def self.create_unique_email
    User.create_unique_string + "@example.com"
  end



  # providerがある場合（Twitter経由で認証した）は、
  # passwordは要求しないようにする。
  def password_required?
    super && provider.blank?
  end

   # プロフィールを変更するときによばれる
  def update_with_password(params, *options)
    # パスワードが空の場合
    if encrypted_password.blank?
      # パスワードがなくても更新できる
      update_attributes(params, *options)
    else
      super
    end
  end

  def feed
    Micropost.from_users_followed_by(self)
  end


  def event_feed(start_time, end_time)
    Event.from_users_followed_by(self, start_time, end_time)
  end

  # "refebookにあって、Google Calendar上にない情報を削除する"
  def delete_gcal_excess(g_events)
    self.events.each do |my_event|
      my_event.destroy if my_event.exist_only_refebook?(g_events)
    end
  end

  # "refebokで作成したイベントを、Google calendarと同期"
  def create_event_in_gcal(r_event)

  end







  def following?(other_user)
    relationships.find_by(followed_id: other_user.id)
  end

  def follow!(other_user)
    relationships.create!(followed_id: other_user.id)
  end

  def unfollow!(other_user)
    relationships.find_by(followed_id: other_user.id).destroy
  end
end
