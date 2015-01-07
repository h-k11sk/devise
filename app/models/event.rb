require 'rubygems'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'active_support/all'

class Event < ActiveRecord::Base

  attr_accessor :period, :frequency, :commit_button

  
  belongs_to :event_series
  belongs_to :user 
  
  validates :title,  presence: true
  #validates :user_id, presence: true 
  validate :validate_timings


  REPEATS = {
    :no_repeat => "Does not repeat",
    :days      => "Daily",
    :weeks     => "Weekly",
    :months    => "Monthly",
    :years     => "Yearly"
  }


  def self.from_users_followed_by(user, start_time, end_time)
    followed_user_ids = "SELECT followed_id FROM relationships
                         WHERE follower_id = :user_id"
    where(" 
          ((starttime >= :start_time and endtime <= :end_time) or
          (starttime >= :start_time and endtime > :end_time and starttime <= :end_time) or
          (starttime <= :start_time and endtime >= :start_time and endtime <= :end_time) or
          (starttime <= :start_time and endtime > :end_time)) and ((user_id IN (#{followed_user_ids})) OR (user_id = :user_id))",
          start_time: start_time, end_time: end_time, user_id: user.id)
  end





  def self.get_google_events(user)
    client = Event.init_google_client(user)
    service = client.discovered_api('calendar', 'v3')

    # 時間を格納
    #time_min = Time.utc(2014, 12, 1, 0).iso8601
    time_min = (Time.now - 6.month).utc.iso8601
    time_max = (Time.now + 6.month).utc.iso8601

    params = {
     'calendarId' => "#{user.email}",
     'timeMin' => time_min,
     'timeMax' => time_max,
     'singleEvents' => 'True'
    }

    result = client.execute(
        api_method: service.events.list,
        parameters: params)    

   # p result.data
   # p result.data.items

    return result.data.items
  end



  def self.init_google_client(user)
    client = Google::APIClient.new(application_name: "Refebook")
    client.authorization.client_id = ENV["Google_APP_ID"] 
    client.authorization.client_secret = ENV["Google_APP_SECRET"]
    #client.authorization.scope =  'https://www.googleapis.com/auth/calendar'
    client.authorization.access_token = user.token
    client.authorization.refresh_token = user.refresh_token
    client.authorization.grant_type = 'refresh_token'
    client.authorization.fetch_access_token!

  #  if client.authorization.expired?
  #    client.authorization.grant_type = 'refresh_token'
  #    client.authorization.fetch_access_token!
  #  end
    return client
  end



  def validate_timings
    if (starttime >= endtime) and !all_day
      errors[:base] << "Start Time must be less than End Time"
    end
  end


  def update_events(events, event)
    events.each do |e|
      begin 
        old_start_time, old_end_time = e.starttime, e.endtime
        e.attributes = event
        if event_series.period.downcase == 'monthly' or event_series.period.downcase == 'yearly'
          new_start_time = make_date_time(e.starttime, old_start_time) 
          new_end_time   = make_date_time(e.starttime, old_end_time, e.endtime)
        else
          new_start_time = make_date_time(e.starttime, old_end_time)
          new_end_time   = make_date_time(e.endtime, old_end_time)
        end
      rescue
        new_start_time = new_end_time = nil
      end
      if new_start_time and new_end_time
        e.starttime, e.endtime = new_start_time, new_end_time
        e.save
      end
    end

    event_series.attributes = event
    event_series.save
  end

  private

  def make_date_time(original_time, difference_time, event_time = nil)
    DateTime.parse("#{original_time.hour}:#{original_time.min}:#{original_time.sec}, #{event_time.try(:day) || difference_time.day}-#{difference_time.month}-#{difference_time.year}")
  end 
end
