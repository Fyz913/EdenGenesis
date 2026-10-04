extends Node
## 0.19.7 统一世界时间源（唯一权威）。
## 所有系统（季节/文明/经济/政治/战争/NPC 作息）必须从此读取时间，
## 禁止自行维护 day/month/year。
## 两条线（同一来源）：
##   hour 线（作息）：1 现实秒 = 0.05 游戏小时（约 8 现实分钟 = 1 天）
##   day 线（文明/季节）：12 现实秒 = 1 游戏天；4 天 = 1 月；4 月 = 1 年
## 事件：hour_changed / day_changed / month_changed / year_changed

signal hour_changed(hour: int)
signal day_changed(day: int)
signal month_changed(month: int)
signal year_changed(year: int)

var hour: float = 8.0
var day: int = 1
var month: int = 1
var year: int = 1
var time_scale: float = 1.0
var day_length: float = 12.0        # 现实秒 = 1 游戏天
var days_per_month: int = 4
var months_per_year: int = 4

var _day_timer: float = 0.0
var _last_hour: int = 8
var _last_day: int = 1
var _last_month: int = 1
var _last_year: int = 1
var listeners: Array = []           # 订阅作息变化的节点（兼容旧 on_hour_changed 接口）
var _speed_index: int = 0
const SPEEDS := [1.0, 5.0, 20.0, 60.0]

func _process(delta: float) -> void:
	var ts: float = time_scale
	# —— 作息线：小时推进（保持 0.14.5 流速，NPC 日程不突变）——
	hour += delta * 0.05 * ts
	if hour >= 24.0:
		hour -= 24.0
	var hi: int = int(hour)
	if hi != _last_hour:
		_last_hour = hi
		hour_changed.emit(hi)
		for l in listeners:
			if is_instance_valid(l):
				l.on_hour_changed(hi)
	# —— 文明线：天/月/年推进（季节/文明节奏，12 现实秒 = 1 天）——
	_day_timer += delta * ts
	if _day_timer >= day_length:
		_day_timer = 0.0
		next_day()

func next_day() -> void:
	day += 1
	if day > days_per_month:
		day = 1
		month += 1
		if month > months_per_year:
			month = 1
			year += 1
			year_changed.emit(year)
		month_changed.emit(month)
	day_changed.emit(day)

func get_hour() -> int:
	return int(hour)

func get_time_string() -> String:
	return "%02d:%02d" % [int(hour), int((hour - int(hour)) * 60)]

func get_day() -> int:
	return day

func get_month() -> int:
	return month

func get_year() -> int:
	return year

func get_season() -> String:
	match month:
		1: return "春"
		2: return "夏"
		3: return "秋"
		4: return "冬"
	return "春"

func subscribe(node: Node) -> void:
	if node and not listeners.has(node):
		listeners.append(node)

## 存档快照（供 SaveManager 写入 time.json）
func snapshot() -> Dictionary:
	return {
		"hour": hour, "day": day, "month": month, "year": year,
		"time_scale": time_scale, "day_length": day_length,
	}

## 读档恢复（SaveManager.load_core 调用；旧档无 month 时由 day 推算）
func restore(data: Dictionary) -> void:
	if data.has("hour"): hour = float(data["hour"])
	if data.has("day"): day = int(data["day"])
	if data.has("month"): month = int(data["month"])
	else: month = int(floor((day - 1) / days_per_month)) + 1
	if data.has("year"): year = int(data["year"])
	if data.has("time_scale"): time_scale = float(data["time_scale"])
	_last_hour = int(hour)
	_last_day = day
	_last_month = month
	_last_year = year

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		_speed_index = (_speed_index + 1) % SPEEDS.size()
		time_scale = SPEEDS[_speed_index]
		get_viewport().set_input_as_handled()
		var toast = get_node_or_null("/root/Main/EventToast")
		if toast and toast.has_method("show_event"):
			var label: String = str(int(time_scale)) + "×"
			if time_scale == 1.0:
				label = "1× 正常"
			toast.show_event("⏩", "时间流速 " + label)
