extends Node3D
## 天气系统：晴/雨/暴雨/雪，带粒子视觉

signal weather_changed(w: String)

var weather: String = "晴"
var weathers: Array = ["晴", "晴", "晴", "雨", "暴雨", "雪"]
var _weather_timer: float = 0.0
var weather_length: float = 25.0
var particles: GPUParticles3D

func _ready() -> void:
	particles = GPUParticles3D.new()
	particles.amount = 2000
	particles.lifetime = 2.0
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 0.1
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, -5, 0)
	particles.process_material = mat
	# 雨点小长条
	var draw_mesh := MeshInstance3D.new()
	var box := BoxMesh.new(); box.size = Vector3(0.02, 0.3, 0.02)
	var rain_mat := StandardMaterial3D.new()
	rain_mat.albedo_color = Color(0.6, 0.75, 0.95, 0.6)
	rain_mat.vertex_color_use_as_albedo = true
	box.material = rain_mat
	draw_mesh.mesh = box
	particles.draw_pass_1 = box
	particles.visibility_aabb = AABB(Vector3(-30,-30,-30), Vector3(60,60,60))
	particles.emitting = false
	add_child(particles)

func _process(delta: float) -> void:
	_weather_timer += delta
	if _weather_timer >= weather_length:
		_weather_timer = 0.0
		random_weather()
	# 粒子跟随玩家
	var player = get_node_or_null("/root/Main/Player")
	if player:
		position = player.position

func random_weather() -> void:
	weather = weathers.pick_random()
	_apply_weather()
	weather_changed.emit(weather)
	print("[Weather] ", weather)

func _apply_weather() -> void:
	match weather:
		"晴":
			particles.emitting = false
		"雨":
			particles.emitting = true
			particles.amount = 1500
		"暴雨":
			particles.emitting = true
			particles.amount = 4000
		"雪":
			particles.emitting = true
			particles.amount = 2000

func crop_yield_multiplier() -> float:
	match weather:
		"雨": return 1.2
		"干旱": return 0.7
		"暴雨": return 0.5
		"雪": return 0.3
	return 1.0
