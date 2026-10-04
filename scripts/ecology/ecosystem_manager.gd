extends Node
## 生态管理器：整合季节/天气/动物
## 视觉安全原则：只调整 Terrain 中地面的季节色调（永不变白）、SnowLayer 透明度、灯光/天空。
## 绝不遍历或修改 Buildings / Residents。

const SeasonScript: Script = preload("res://scripts/ecology/season_system.gd")
const WeatherScript: Script = preload("res://scripts/ecology/weather_system.gd")
const AnimalScript: Script = preload("res://scripts/ecology/animal_manager.gd")

var season_sys: Node
var weather_sys: Node3D
var animal_sys: Node3D

var forest_coverage: float = 75.0
var animal_stability: String = "稳定"
var water_status: String = "正常"
var pollution: float = 0.0
var _target_snow: float = 0.0

func _ready() -> void:
	season_sys = SeasonScript.new(); add_child(season_sys)
	weather_sys = WeatherScript.new(); add_child(weather_sys)
	animal_sys = AnimalScript.new(); add_child(animal_sys)
	if not season_sys.season_changed.is_connected(_on_season_changed):
		season_sys.season_changed.connect(_on_season_changed)
	if not weather_sys.weather_changed.is_connected(_apply_environment):
		weather_sys.weather_changed.connect(_apply_environment)
	_apply_environment()

func _process(delta: float) -> void:
	# 积雪透明度平滑过渡
	var world = get_node_or_null("/root/Main/World")
	if world and world.get("snow_material"):
		var cur: float = world.snow_material.albedo_color.a
		var nxt: float = lerp(cur, _target_snow, delta * 1.5)
		world.snow_material.albedo_color.a = nxt
		world.snow_layer.visible = nxt > 0.02

func _on_season_changed(_s: String) -> void:
	_apply_environment()
	var world = get_node_or_null("/root/Main/World")
	match season_sys.season:
		"冬":
			animal_stability = "稀少"
			forest_coverage -= 1.0
		"春":
			animal_stability = "增长"
			forest_coverage += 2.0
			# 每进入新的一年自动存档
			if season_sys.year > 1 and world and world.has_method("save_game"):
				world.save_game()
		"夏":
			animal_stability = "稳定"
		"秋":
			animal_stability = "稳定"
	forest_coverage = clamp(forest_coverage, 10.0, 100.0)
	var toast = get_node_or_null("/root/Main/EventToast")
	if toast:
		var icons = {"春":"🌱","夏":"☀","秋":"🍂","冬":"❄"}
		toast.show_event(icons.get(season_sys.season,""), season_sys.season + "季来临")

func _apply_environment(_w: String = "") -> void:
	var world = get_node_or_null("/root/Main/World")
	if world == null: return
	var colors: Dictionary = season_sys.get_season_color()

	# 1) 地面季节色调：春绿/夏深绿/秋黄，冬季保持枯黄底（雪由积雪层覆盖）
	if world.get("ground_material"):
		var gc: Color
		match season_sys.season:
			"春": gc = Color(0.38, 0.63, 0.3)
			"夏": gc = Color(0.28, 0.55, 0.2)
			"秋": gc = Color(0.52, 0.44, 0.22)
			"冬": gc = Color(0.45, 0.48, 0.4)  # 暗灰枯草，不是白色
			_: gc = colors.ground
		world.ground_material.albedo_color = gc

	# 2) 积雪层：仅冬季淡入
	_target_snow = 0.85 if season_sys.season == "冬" else 0.0

	# 3) 太阳光
	var light = get_node_or_null("/root/Main/DirectionalLight3D")
	if light:
		light.light_color = colors.light
		match season_sys.season:
			"冬": light.light_energy = 0.75
			"夏": light.light_energy = 1.2
			_: light.light_energy = 1.0

	# 4) 天空
	var env_node = get_node_or_null("/root/Main/WorldEnvironment")
	if env_node and env_node.environment:
		env_node.environment.background_color = colors.sky
		env_node.environment.ambient_light_color = colors.sky

func get_ecology_text() -> String:
	return "森林: %.0f%%\n动物: %s\n水源: %s\n天气: %s\n季节: %s" % [
		forest_coverage, animal_stability, water_status, weather_sys.weather, season_sys.season
	]
