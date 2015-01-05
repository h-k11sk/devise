require 'rubygems'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'active_support/all'

class Event < ActiveRecord::Base

  attr_accessor :period, :frequency, :commit_button

  validates :title,  :presence => true
  validate :validate_timings

  belongs_to :event_series

  REPEATS = {
    :no_repeat => "Does not repeat",
    :days      => "Daily",
    :weeks     => "Weekly",
    :months    => "Monthly",
    :years     => "Yearly"
  }




  def self.get_google_events(user)
    puts "#{user.email}"
    client = Event.init_google_client(user)
    service = client.discovered_api('calendar', 'v3')


# 時間を格納
#time_min = Time.utc(2014, 12, 1, 0).iso8601
time_min = (Time.now - 6.month).utc.iso8601
#time_max = Time.utc(2015, 12, 31, 0).iso8601
#time_max = Time.now.next_month.utc.iso8601
time_max = (Time.now + 6.month).utc.iso8601


    p service
    params = {
     'calendarId' => "#{user.email}",
     'timeMin' => time_min,
     'timeMax' => time_max,
     'singleEvents' => 'True'
      #grant_type: user.token
    }



    result = client.execute(
  #    api_method: service.calendar_list.list,
  api_method: service.events.list,
  parameters: params)    
    #p result
    puts 
   # p result.data
   puts 
    #p result.data.items
   
   events = []
   result.data.items.each do |item|
        events << item
  end

   events.each do |event|
     printf("%s,%s\n",event.start.date,event.summary)
   end
   puts 




return result.data.items
end


def self.init_google_client(user)
  client = Google::APIClient.new(application_name: "Refebook")
   # client.authorization.client_id = "25672067812-2nk5mfseprvc6nivfgjoougi3ku2ckuj.apps.googleusercontent.com"
   # client.authorization.client_secret = "a1qjttYMo22CgTdEuAPFVtPL"
   client.authorization.access_token = user.token
   # client.authorization.scope =  "https://www.googleapis.com/auth/calendar"
    #client.authorization.redirect_uri = "http://localhost:3000/users/auth/google_oauth2/callback"
   # client.authorization.grant_type =  user.token
   #client.authorization.fetch_access_token!
   puts user.token
   puts 
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
