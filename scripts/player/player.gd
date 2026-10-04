extends CharacterBody3D
## 第三人称玩家：鼠标转视角，滚轮缩放

@export var speed: float = 6.0
@export var mouse_speed: float = 0.002
@export var min_dist: float = 3.0
@export var max_dist: float = 10.0
var gravity: float = 20.0
var cam_dist: float = 6.0
var cam_yaw: float = 0.0
var cam_pitch: float = -0.2

@onready var camera: Camera3D = $Camera3D
@onready var interact_area: Area3D = $InteractArea
@onready var dialogue_ui: CanvasLayer = %DialogueLayer

var nearby_npc: CharacterBody3D = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if dialogue_ui.visible: return
	if event is InputEventMouseMotion:
		cam_yaw -= event.relative.x * mouse_speed
		cam_pitch = clamp(cam_pitch - event.relative.y * mouse_speed, -1.0, 0.5)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam_dist = max(min_dist, cam_dist - 0.5)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_dist = min(max_dist, cam_dist + 0.5)
	if event.is_action_pressed("ui_cancel"):
		# ESC 切换鼠标捕获：再次按 ESC 恢复视角控制
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event.is_action_pressed("interact") and nearby_npc:
		dialogue_ui.open(nearby_npc)

func _physics_process(delta: float) -> void:
	if dialogue_ui.visible:
		velocity.x = 0.0; velocity.z = 0.0
		if not is_on_floor(): velocity.y -= gravity * delta
		move_and_slide(); return
	if not is_on_floor(): velocity.y -= gravity * delta
	var d: Vector2 = Input.get_vector("move_left","move_right","move_forward","move_backward")
	# 相机前向与右向（与相机 offset 公式严格对应，修正 90° 旋转错位）
	var forward_dir: Vector3 = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right_dir: Vector3 = Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var move: Vector3 = forward_dir * -d.y + right_dir * d.x
	if move.length() > 0.1:
		velocity.x = move.x * speed; velocity.z = move.z * speed
		# 玩家面向移动方向
		look_at_from_position(global_position, global_position + Vector3(move.x, 0, move.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	move_and_slide()
	# 相机跟随
	var cam_pos: Vector3 = global_position + Vector3(0, 2.0, 0)
	var offset: Vector3 = Vector3(sin(cam_yaw) * cos(cam_pitch), -sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch)) * cam_dist
	camera.global_position = cam_pos + offset
	camera.look_at(cam_pos, Vector3.UP)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("chat"):
		nearby_npc = body

func _on_body_exited(body: Node3D) -> void:
	if body == nearby_npc: nearby_npc = null
