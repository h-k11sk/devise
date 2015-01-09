class EventsController < ApplicationController
  before_action :authenticate_user!

  #layout Configuration['layout'] || 'application'

  before_filter :load_event, only: [:edit, :update, :destroy, :move, :resize]
  before_filter :determine_event_type, only: :create


  def index

  end

  def get_gcal_events
    if current_user.token?
      # st1 = Time.now
      get_gcal_events = Event.get_google_events(current_user)
      # puts "google apiの全実行時間： #{Time.now - st1}"

      g_events = []
      get_gcal_events.each do |g_event|
        @event = current_user.events.build(
          title: g_event.summary,
          starttime: g_event.start["dateTime"],
          endtime: g_event.end["dateTime"],
          gcal_id: g_event.id
        )

        if @event.starttime.nil?
          @event.starttime, @event.endtime = g_event.start["date"], g_event.end["date"]
        else
          @event.starttime = @event.starttime + 9.hour
          @event.endtime = @event.endtime + 9.hour
        end

        @event.save if @event.gcal_unique?(current_user)
        g_events << @event

      end
      current_user.delete_gcal_excess(g_events)
    end

    #puts "イベント更新の実行時間： #{Time.now - st1}"

    redirect_to current_user
  end


  def create
    if @event.save
      @event.gcal_id = Event.insert_google_event(current_user, @event) 
      @event.save
      render nothing: true
    else
      render text: @event.errors.full_messages.to_sentence, status: 422
    end
  end


  def new
    respond_to do |format|
      format.js
    end
  end

  def get_events
    start_time = Time.at(params[:start].to_i).to_formatted_s(:db)
    end_time   = Time.at(params[:end].to_i).to_formatted_s(:db)

    @event_feeds = current_user.event_feed(start_time, end_time)
    events = []

    @event_feeds.each do |event|
      events << { id: event.id,
                  title: event.title,
                  description: event.description || '',
                  start: event.starttime.iso8601,
                  end: event.endtime.iso8601,
                  allDay: event.all_day,
                  color: event.user_id == current_user.id ? "#4c6cb3" : "#c53d43",
                  recurring: (event.event_series_id) ? true : false }
    end

    render json: events.to_json
  end

  def move
    if @event
      @event.starttime = make_time_from_minute_and_day_delta(@event.starttime)
      @event.endtime   = make_time_from_minute_and_day_delta(@event.endtime)
      @event.all_day   = params[:all_day]
      @event.save

      Event.update_google_event(current_user, @event)
    end
    render nothing: true
  end

  def resize
    if @event
      @event.endtime = make_time_from_minute_and_day_delta(@event.endtime)
      @event.save
      Event.update_google_event(current_user, @event)
    end
    render nothing: true
  end

  def edit
    render json: { form: render_to_string(partial: 'edit_form') }
  end

  def update
    case params[:event][:commit_button]
    when 'Update All Occurrence'
      @events = @event.event_series.events
      @event.update_events(@events, event_params)
    when 'Update All Following Occurrence'
      @events = @event.event_series.events.where('starttime > :start_time',
                                                 start_time: @event.starttime.to_formatted_s(:db)).to_a
      @event.update_events(@events, event_params)
    else
      @event.attributes = event_params
      @event.save
      Event.update_google_event(current_user, @event)
    end
    render nothing: true
  end

  def destroy
    case params[:delete_all]
    when 'true'
      @event.event_series.destroy
    when 'future'
      @events = @event.event_series.events.where('starttime > :start_time',
                                                 start_time: @event.starttime.to_formatted_s(:db)).to_a
      @event.event_series.events.delete(@events)
    else
      Event.delete_google_event(current_user, @event)
      @event.destroy
    end
    render nothing: true
  end




  private

  def load_event

    @event = current_user.events.find_by(id: params[:id])

    unless @event
      render json: { message: "Event Not Found.."}, status: 404 and return
    end
  end

  def event_params
    params.require(:event).permit('title', 'description', 'starttime', 'endtime', 'all_day', 'period', 'frequency', 'commit_button')
  end

  def determine_event_type
    if params[:event][:period] == "なし"
      #        @event = Event.new(event_params)
      @event = current_user.events.build(event_params)
    else
      #    @event = EventSeries.new(event_params)
      @event = current_user.event_series.build(event_params)
    end
  end

  def make_time_from_minute_and_day_delta(event_time)
    params[:minute_delta].to_i.minutes.from_now((params[:day_delta].to_i).days.from_now(event_time))
  end
end
