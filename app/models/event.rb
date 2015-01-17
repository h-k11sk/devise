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
    :no_repeat => "なし",
    :days      => "毎日",
    :weeks     => "毎週",
    :months    => "毎月",
    :years     => "毎年"
  }


  # "フォローしているユーザーの情報を獲得する"
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


  # "Google Calendar上にしかない情報を取得する"
  def gcal_unique?(user)
    unique_event = user.events.where("
          (title == :title) and
          (starttime == :start_time) and
          (endtime == :end_time)",
            title: self.title.to_s, start_time: self.starttime, end_time: self.endtime)
          return unique_event.empty? ? true : false
  end


  #"refebook上にしか無い情報を削除する"
  def exist_only_refebook?(g_events)
    i = 0
    g_events.each do |g_event|
      if self.title == g_event.title and self.starttime == g_event.starttime and self.endtime == g_event.endtime
        #      puts "両方にあるよ！"
        i = i + 1
      end
    end
    puts "Refebookにしかないよ！" if i == 0
    return i == 0 ? true : false
  end



  #READ: "google calendar apiを叩く"
  def self.get_google_events(user)
    client = Event.init_google_client(user)
    service = client.discovered_api('calendar', 'v3')

    time_min = (Time.now - 1.month).utc.iso8601
    time_max = (Time.now + 1.month).utc.iso8601

    params = {
      'calendarId' => "#{user.email}",
      'maxResults' => "2500",
      'timeMin' => time_min,
      'timeMax' => time_max
      #     'timeZone' => "tokyo"
      # 'singleEvents' => 'True'
    }

    st1 = Time.now
    result = client.execute(
      api_method: service.events.list,
      parameters: params)
      puts "client execute: #{Time.now - st1}"

      # p result.data
      # p result.data.items

      return result.data.items
  end


  # CREATE: "refebokで作成したイベントを、Google calendarと同期"
  def self.insert_google_event(user, r_event)
    puts
    puts "5. 今からgcal api叩くよ"
    p r_event
    puts r_event.frequency

    client = Event.init_google_client(user)
    service = client.discovered_api('calendar', 'v3')

    if r_event.period == "毎年" then
      g_period = "YEARLY"
    elsif r_event.period == "毎月" then
      g_period = "MONTHLY"
    elsif r_event.period == "毎週" then
      g_period = "WEEKLY"
    elsif r_event.period == "毎日" then
      g_period = "DAILY"
    end


    if r_event.class == EventSeries
      puts "EventSeries 条件分岐せいこうしたよ！"
      event_resources = {
        'summary' => r_event.title,
        'start' => {'dateTime' => r_event.starttime - 9.hour, 
                    "timeZone" => "Asia/Tokyo"},
        'end' => {'dateTime' => r_event.endtime - 9.hour,
                  "timeZone" => "Asia/Tokyo"},
        'recurrence' => ["RRULE:FREQ=#{g_period};INTERVAL=#{r_event.frequency}"]
        #'id' => {}
      }

      puts 
      p event_resources
      puts 

      params = {
        'calendarId' => "#{user.email}"
      }

      result = client.execute(
        api_method: service.events.insert,
        parameters: params,
        body: JSON.dump(event_resources),
        headers: {'Content-Type' => 'application/json'}
      )

      p result.data
      puts 
    else
      puts "呼ばれてないよ！"
      event_resources = {
        'summary' => r_event.title,
        'start' => {'dateTime' => r_event.starttime - 9.hour},
        'end' => {'dateTime' => r_event.endtime - 9.hour}
      #'id' => {}
      }

      params = {
        'calendarId' => "#{user.email}"
      }

      result = client.execute(
        api_method: service.events.insert,
        parameters: params,
        body: JSON.dump(event_resources),
        headers: {'Content-Type' => 'application/json'}
      )

    end

    return result.data.id
  end



  #"UPDATE: Refebookで更新したデータをgoogleでも更新"
  def self.update_google_event(user, r_event, before_starttime)
    client = Event.init_google_client(user)
    service = client.discovered_api('calendar', 'v3')

    #"単独イベントの場合"
    if r_event.event_series_id == nil
      params = {
        'calendarId' => "#{user.email}",
        'eventId' => "#{r_event.gcal_id}"
      }

      g_result = client.execute(
          api_method: service.events.get,
          parameters: params
      )

      #"gcal送信用イベント更新"
      new_event = g_result.data
      new_event.summary = r_event.title
      new_event.start["dateTime"] = r_event.starttime - 9.hour
      new_event.end["dateTime"] = r_event.endtime - 9.hour

      client.execute(
          api_method: service.events.update,
          parameters: params,
          body_object: new_event,
          headers: {'Content-Type' => 'application/json'}
      )
    
    return "SINGLE"

    #"繰返しイベントの場合"
    else
      #"gcal送信用イベント更新"
      re_event =  user.event_series.find_by(id: r_event.event_series_id)
      re_gcal_id = re_event.gcal_id
      re_period = re_event.period
      re_frequency = re_event.frequency
      re_start = re_event.starttime
      
      params = {
        'calendarId' => "#{user.email}",
        'eventId' => "#{re_gcal_id}"
      }

      instances = client.execute(
        api_method: service.events.instances,
        parameters: params
      )

      

      #p instances.data.items
      puts 
      #p instance =  instances.data.items[1]
      puts 
      puts "更新前：#{before_starttime}"
      puts "更新後：#{r_event.starttime}"
      puts "比較てすと"
      puts instances.data.items[0].start["dateTime"].hour
      puts before_starttime.hour
      puts
      puts "以下に表示されれば成功！"
      puts  
      array_instance =  instances.data.items.select {|x| (x.start["dateTime"].year == before_starttime.year) and (x.start["dateTime"].day == before_starttime.day) and (x.start["dateTime"].hour == before_starttime.hour)}
     # p instances.data.items.select {|x| }
      p instance = array_instance[0]
      puts 
      puts "成功したよ？"
      
#      p gcal_data.scan(/([\d\-]+)/)




      #"上記のコードを上手く実装する 0115"
      puts
      instance.status = 'cancelled'
      puts
      puts "gcalへ送信前"
      p instance
      puts 

      newparams = {
        'calendarId' => "#{user.email}",
        'eventId' => instance.id
      }



      result = client.execute(
        api_method: service.events.update,
        parameters: newparams,
        body_object: instance,
        headers: {'Content-Type' => 'application/json'}
      )

      puts "cancelledになってる！"
      p result.data

      #"単独イベントをgcalに伝える"
      event_resources = {
        'summary' => r_event.title,
        'start' => {'dateTime' => r_event.starttime - 9.hour},
        'end' => {'dateTime' => r_event.endtime - 9.hour}
      }

      params = {
        'calendarId' => "#{user.email}"
      }

      result = client.execute(
        api_method: service.events.insert,
        parameters: params,
        body: JSON.dump(event_resources),
        headers: {'Content-Type' => 'application/json'}
      )
    end
    return result.data
  end






  "繰返しイベントの全部更新 or 未来の更新"
  def self.update_google_all_or_future_event(user, r_event, before_starttime, event_params)
    client = Event.init_google_client(user)
    service = client.discovered_api('calendar', 'v3')

    puts 
    p r_event
    puts 
    puts 
    p event_params
    puts 

    p re_event =  user.event_series.find_by(id: r_event.event_series_id)
    puts "gcal_id: #{re_gcal_id = re_event.gcal_id}"
    puts 
    p params = {
      'calendarId' => "#{user.email}",
      'eventId' => "#{re_gcal_id}"
    }

    g_result = client.execute(
        api_method: service.events.get,
        parameters: params
    )
    puts 
    puts "繰り返しイベントかな？"
    p g_result.data
    puts 

    #"gcal送信用イベント更新"
    new_event = g_result.data
    p new_event.summary = event_params["title"]
    p new_event.description = event_params["description"]
    # new_event.start["dateTime"] = r_event.starttime - 9.hour
    # new_event.end["dateTime"] = r_event.endtime - 9.hour

    client.execute(
        api_method: service.events.update,
        parameters: params,
        body_object: new_event,
        headers: {'Content-Type' => 'application/json'}
    )
    
  end


  #"DELETE: Refebookで削除したイベントは、Google Caldar上でも削除"
  def self.delete_google_event(user, r_event)
    client = Event.init_google_client(user)
    service = client.discovered_api('calendar', 'v3')

    if r_event.event_series_id == nil
      params = {
        'calendarId' => "#{user.email}",
        'eventId' => "#{r_event.gcal_id}"
      }
    else
      p re_event =  user.event_series.find_by(id: r_event.event_series_id)
       p gcal_id =  re_event.gcal_id
      params = {
        'calendarId' => "#{user.email}",
        'eventId' => "#{gcal_id}"
      }
    end

    client.execute(
      api_method: service.events.delete,
      parameters: params)
  end

  #"DELETE: Refebookで全て削除　=> gcalで削除"
  def self.delete_google_allevents(user, r_event)

  end




  #"Google APIのクライアントを初期化"
  def self.init_google_client(user)
    client = Google::APIClient.new(application_name: "Refebook")
    client.authorization.client_id = ENV["Google_APP_ID"]
    client.authorization.client_secret = ENV["Google_APP_SECRET"]
    client.authorization.scope =  'https://www.googleapis.com/auth/calendar'
    client.authorization.access_token = user.token
    client.authorization.refresh_token = user.refresh_token

    if client.authorization.refresh_token && client.authorization.expired?
      client.authorization.grant_type = 'refresh_token'
      client.authorization.fetch_access_token!
    end

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
        if event_series.period == '毎月' or event_series.period == '毎年'
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
