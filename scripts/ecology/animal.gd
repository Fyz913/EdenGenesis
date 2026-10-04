extends CharacterBody3D
## 动物：陆地漫游 / 鱼在河里游

@export var animal_name: String = "鹿"
@export var kind: String = "land"
var speed: float = 1.5
var gravity: float = 20.0
var target: Vector3
var _wait: float = 0.0
var body_color: Color = Color(0.5, 0.35, 0.2)

@onready var body: MeshInstance3D = $Body

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	if body:
		body.material_override = mat
	_pick_target()

func _pick_target() -> void:
	if kind == "fish":
		target = Vector3(randf_range(-25, 25), -0.1, -15 + randf_range(-1.5, 1.5))
		speed = 0.8
	else:
		target = Vector3(randf_range(-35, 35), 0, randf_range(-35, 25))
		speed = randf_range(1.0, 2.5)

func _physics_process(delta: float) -> void:
	if kind == "land" and not is_on_floor():
		velocity.y -= gravity * delta
	var to: Vector3 = target - position
	to.y = 0
	if to.length() > 0.5:
		var d: Vector3 = to.normalized()
		velocity.x = d.x * speed
		velocity.z = d.z * speed
		if kind == "land":
			look_at_from_position(position, position + d, Vector3.UP)
	else:
		velocity.x = 0; velocity.z = 0
		_wait += delta
		if _wait > randf_range(2, 5):
			_wait = 0
			_pick_target()
	# 鱼不受重力
	if kind == "fish":
		velocity.y = 0
		position.y = -0.1
	move_and_slide()
