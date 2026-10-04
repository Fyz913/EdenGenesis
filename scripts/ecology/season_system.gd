extends Node
## 季节系统：0.19.7 起改为统一时间源 WorldTime 的镜像。
## 自身不再计时；day/year/month 从 WorldTime 同步，month→season 映射，保留
## season_changed 供生态渲染（颜色/光照）使用。旧系统读 season_sys.year/day 不变。

signal season_changed(season: String)

var year: int = 1
var day: int = 1
var month: int = 1
var season: String = "春"
var seasons: Array = ["春", "夏", "秋", "冬"]
var days_per_season: int = 4  # 兼容旧读取（1 年 = 16 天，已由 WorldTime 统一驱动）

func _ready() -> void:
	var clock = get_node_or_null("/root/Main/WorldTime")
	if clock:
		if not clock.day_changed.is_connected(_on_world_day):
			clock.day_changed.connect(_on_world_day)
		if not clock.month_changed.is_connected(_on_world_month):
			clock.month_changed.connect(_on_world_month)
		if not clock.year_changed.is_connected(_on_world_year):
			clock.year_changed.connect(_on_world_year)
		# 初始同步一次
		year = clock.year
		day = clock.day
		month = clock.month
		season = _season_of_month(month)
		_on_world_month(month)

func _on_world_day(d: int) -> void:
	day = d
	var clock = get_node_or_null("/root/Main/WorldTime")
	if clock:
		year = clock.year

func _on_world_month(m: int) -> void:
	month = m
	var new_season: String = _season_of_month(m)
	if new_season != season:
		season = new_season
		season_changed.emit(season)

func _on_world_year(y: int) -> void:
	year = y

func _season_of_month(m: int) -> String:
	match m:
		1: return "春"
		2: return "夏"
		3: return "秋"
		4: return "冬"
	return "春"

## 读档同步（SaveManager 恢复 WorldTime 后调用一次，season 渲染立即对齐）
func sync_from_clock() -> void:
	var clock = get_node_or_null("/root/Main/WorldTime")
	if clock:
		year = clock.year
		day = clock.day
		month = clock.month
		var s: String = _season_of_month(month)
		if s != season:
			season = s
			season_changed.emit(season)

func get_season_color() -> Dictionary:
	match season:
		"春": return {"ground": Color(0.35, 0.62, 0.28), "sky": Color(0.55, 0.75, 0.95), "light": Color(1, 0.95, 0.85)}
		"夏": return {"ground": Color(0.28, 0.55, 0.2), "sky": Color(0.4, 0.65, 0.9), "light": Color(1, 0.9, 0.7)}
		"秋": return {"ground": Color(0.55, 0.45, 0.2), "sky": Color(0.7, 0.65, 0.55), "light": Color(1, 0.75, 0.5)}
		"冬": return {"ground": Color(0.85, 0.87, 0.9), "sky": Color(0.75, 0.8, 0.88), "light": Color(0.85, 0.88, 1)}
	return {"ground": Color(0.35, 0.6, 0.25), "sky": Color(0.5, 0.7, 0.95), "light": Color(1,1,1)}
