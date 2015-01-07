FULLCALENDAR_FILE_PATH = Rails.root.join('config', 'fullcalendar.yml')
config = File.exists?(FULLCALENDAR_FILE_PATH) ? YAML.load_file(FULLCALENDAR_FILE_PATH) || {} : {}
Configuration = {
  'editable'    => true,
  'header'      => {
    left: 'prev,next today',
    center: 'title',
    right: 'month,agendaWeek,agendaDay'
  },
 # 'defaultView' => 'agendaWeek',
  'height'      => 600,
  'slotMinutes' => 15,
  'dragOpacity' => 0.5,
  'selectable'  => true,
  #'timeFormat'  => "h:mm t{ - h:mm t}",
  'buttonText' => {
    prev: "<",
    next: ">",
    prevYear: "<<",
    nextYear: ">>",
    today: "今日",
    month: "月",
    week: "週",
    day: "日"
  },
  titleFormat: {
    month: "yyyy年M月",
    week: "yyyy年M月d日",
    day: "yyyy年M月d日'('ddd')'"
  },
  columnFormat: {
    month: "ddd",
    week: "d日'('ddd')'",
    day: "d日'('ddd')'"
  },
  dayNames: ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"],
  dayNamesShort: ["日", "月", "火", "水", "木", "金", "土"],
  allDayText: '終日',
}

Configuration.merge!(config)
Configuration['events'] = "#{Configuration['mount_path']}/events/get_events"