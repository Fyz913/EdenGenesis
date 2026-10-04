extends CharacterBody3D
class_name EdenNPC
## 居民主体：组合 AI 大脑 / 人格 / 情绪 / 记忆 / 目标 / 需求 / 职业 / 关系

@export var npc_name: String = "阿尔"
@export var job: String = "铁匠"
var age: int = 32
var gender: String = "男"

var speed: float = 2.5
var gravity: float = 20.0
var target: Vector3 = Vector3.ZERO
var current_action: String = "idle"
var _walk_phase: float = 0.0
var _work_phase: float = 0.0

# 子系统
var ai: Node                 # AI 决策大脑
var personality_sys: Node    # 人格
var emotion_sys: Node        # 情绪
var life_memory: Node        # 长期记忆
var goal_sys: Node           # 目标
var life_events: Node        # 人生事件
var needs: Node
var job_node: Node
var relationship: Node
var memory: Node             # 兼容旧简版记忆

# 社会关系
var spouse: Node = null
var family: Node = null

# 经济
const InventoryScript: Script = preload("res://scripts/economy/inventory.gd")
var money: float = 20.0
var inventory
var poverty: float = 0.0
var starve_days: int = 0   # 连续挨饿天数，>=5 触发饥荒离开

# 政治（0.13）
var organizations: Array = []
var policy_preferences: Dictionary = {}

# 军事（0.14）
var military_service: bool = false
var migration_pressure: float = 0.0   # 战争/贫困带来的迁移意愿
var civilian_job_backup: String = ""  # 参军前职业（退役后恢复）

# 社会生命（0.16）
var education: float = 0.0                     # 教育值 0-100
var school_years: int = 0                      # 受教育年限（儿童计）
var health: float = 100.0                      # 健康 0-100
var sickness: float = 0.0                      # 疾病程度 0-100
var political_dissatisfaction: float = 0.0     # 政治不满 0-100
var social_class: String = "普通"              # 每月按真实财富重算
var home_house_id: String = ""                 # 绑定真实房屋 id
var job_building_id: String = ""               # 绑定工作建筑 id
var company_id: String = ""                    # 0.20 企业归属（企业层月度分红）

# 知识与技能（0.17）
var skills: Dictionary = {}                    # {领域: 技能值 0-100}
var skill_exp: int = 0                         # 实验/工作累计次数（发明条件）

# 统一居民数据模型（Human 层）
const PersonModelScript: Script = preload("res://scripts/human/person_model.gd")
var person

# 技能（0.17）
const SkillScript: Script = preload("res://scripts/technology/skill_system.gd")
var skill_sys: Node

signal reply_ready(text: String)

@onready var name_label: Label3D = $NameLabel
var player: Node3D = null
var action_label: Label3D = null   # 0.14.5 头顶实时状态图标

func _ready() -> void:
	player = get_node_or_null("/root/Main/Player")
	inventory = InventoryScript.new()
	_join_initial_organizations()
	_setup_policy_preferences()
	# 人格 / 情绪 / 记忆 / 目标 / 事件 / 大脑
	personality_sys = preload("res://scripts/ai/personality.gd").new(job, randf())
	add_child(personality_sys)
	emotion_sys = preload("res://scripts/ai/emotion_system.gd").new()
	add_child(emotion_sys)
	life_memory = preload("res://scripts/ai/memory_system.gd").new()
	add_child(life_memory)
	goal_sys = preload("res://scripts/ai/goal_system.gd").new()
	add_child(goal_sys)
	goal_sys.setup(job, age, personality_sys.archetype)
	life_events = preload("res://scripts/human/life_event.gd").new()
	add_child(life_events)
	ai = preload("res://scripts/ai/ai_brain.gd").new()
	add_child(ai)
	needs = preload("res://scripts/npc/npc_needs.gd").new()
	add_child(needs)
	job_node = preload("res://scripts/npc/npc_job.gd").new()
	add_child(job_node)
	relationship = preload("res://scripts/society/relationship.gd").new()
	add_child(relationship)
	memory = preload("res://scripts/npc/npc_memory.gd").new()
	add_child(memory)
	# 技能（0.17）：按职业与年龄初始化
	skill_sys = SkillScript.new()
	add_child(skill_sys)
	skills = skill_sys.init_skills(job, age)

	# 身份档案
	person = PersonModelScript.new({
		"person_name": npc_name, "age": age, "job": job,
		"personality": personality_sys.archetype, "goal": goal_sys.life_dream,
	})
	# 初始人生记忆
	life_memory.record("我出生在 Eden 村，是这里最早的居民之一", 80, _year(), "人生")
	life_memory.record("我成为了一名" + job, 40, _year(), "重要")

	_apply_job_visual()

	# 头顶状态图标（0.14.5）：跟随名字，显示当前行为 emoji
	action_label = Label3D.new()
	action_label.position = Vector3(0, 2.42, 0)
	action_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	action_label.pixel_size = 0.004
	action_label.font_size = 64
	action_label.outline_size = 8
	action_label.modulate = Color(1, 1, 1, 0.95)
	add_child(action_label)
	_update_action_icon()

	_update_label()
	print("[NPC] ", npc_name, " 出生 | ", job, " | ", personality_sys.archetype)

# 0.14.5：当前行为 → 头顶图标
func _update_action_icon() -> void:
	if action_label == null: return
	var icon: String = "🚶"
	match current_action:
		"工作": icon = "🔨"
		"吃饭": icon = "🍚"
		"睡觉", "休息": icon = "💤"
		"社交": icon = "💬"
		"探索": icon = "🌿"
		"idle": icon = "🚶"
	action_label.text = icon
	# 参军状态单独标识
	if military_service:
		action_label.text = "⚔️"

func _year() -> int:
	var world = get_node_or_null("/root/Main/World")
	if world and world.get("ecosystem") and world.ecosystem.get("season_sys"):
		return world.ecosystem.season_sys.year
	return 1

# ---------- 组织 / 政治意见（0.13） ----------
func join_organization(org_id: String) -> void:
	if not organizations.has(org_id):
		organizations.append(org_id)
	var world = get_node_or_null("/root/Main/World")
	if world and world.get("org_mgr"):
		world.org_mgr.join(org_id, npc_name)

func _join_initial_organizations() -> void:
	join_organization("eden_village")
	var guild: String = ""
	match job:
		"铁匠", "织布工", "面包师": guild = "crafts_guild"
		"农民", "农夫", "渔夫": guild = "farmers_guild"
		"商人": guild = "merchant_guild"
	if guild != "":
		join_organization(guild)

func _setup_policy_preferences() -> void:
	# 职业影响政治偏好（农民重粮食，商人重税率）
	match job:
		"农民", "农夫", "渔夫":
			policy_preferences = {"food_reserve": 70, "forest_protection": 60, "tax_rate": 20}
		"商人":
			policy_preferences = {"trade_tax": 20, "tax_rate": 15, "forest_protection": 30}
		_:
			policy_preferences = {"tax_rate": 40, "forest_protection": 50, "food_reserve": 50}

func _update_label() -> void:
	if name_label:
		name_label.text = npc_name + "\n" + job
	var shirt: MeshInstance3D = get_node_or_null("Body")
	if shirt:
		var mat := StandardMaterial3D.new()
		match job:
			"铁匠": mat.albedo_color = Color(0.15, 0.15, 0.18, 1)
			"农民", "农夫": mat.albedo_color = Color(0.25, 0.55, 0.25, 1)
			"商人": mat.albedo_color = Color(0.9, 0.75, 0.2, 1)
			"渔夫": mat.albedo_color = Color(0.2, 0.4, 0.6, 1)
			"面包师": mat.albedo_color = Color(0.85, 0.6, 0.4, 1)
			"织布工": mat.albedo_color = Color(0.7, 0.4, 0.6, 1)
			"孩子": mat.albedo_color = Color(0.9, 0.9, 0.6, 1)
			_: mat.albedo_color = Color(0.25, 0.45, 0.85, 1)
		shirt.material_override = mat

# ---------- 经济/社会接口 ----------
## 贫困居民转行产粮职业（寻找新工作）：更新职业、工作点、衣服、目标与记忆
func retrain(new_job: String) -> void:
	var old_job: String = job
	job = new_job
	var settlement = get_node_or_null("/root/Main/World/settlement")
	if settlement and settlement.has_method("get_work_for"):
		job_node.work_position = settlement.get_work_for(new_job)
	_update_label()
	if goal_sys:
		goal_sys.setup(job, age, personality_sys.archetype if personality_sys else "普通")
	life_memory.record("村里闹饥荒，我放下了" + old_job + "的营生，改当" + new_job + "讨生活", 45, _year(), "重要")
	poverty = 0.0

# ---------- 军事（0.14） ----------
## 参军条件：18-45 岁、未参军、不是孩子
func can_enlist() -> bool:
	if age < 18 or age > 45: return false
	if military_service: return false
	if job == "孩子": return false
	return true

func enlist() -> void:
	if not can_enlist(): return
	military_service = true
	civilian_job_backup = job
	job = "士兵"
	_update_label()
	_update_action_icon()
	life_memory.record("我响应号召，入伍为 Eden 而战", 70, _year(), "人生")
	# 离开工作岗位 → 家庭收入下降由经济系统自然体现

func retire_from_military() -> void:
	if not military_service: return
	military_service = false
	if civilian_job_backup != "":
		job = civilian_job_backup
		civilian_job_backup = ""
	else:
		job = "农民"
	_update_label()
	_update_action_icon()
	life_memory.record("战争结束了，我脱下戎装，回归" + job + "的生活", 60, _year(), "人生")

# ---------- 对话（本地基于人格/记忆/情绪生成，无需服务器） ----------
func chat(text: String) -> void:
	reply_ready.emit(say(text))

func say(input_text: String) -> String:
	var t := input_text
	# 记住玩家说的话（普通记忆）
	life_memory.record("玩家对我说：" + t, 5, _year(), "普通")
	if "你好" in t or "嗨" in t or "hi" in t.to_lower():
		var greet := "你好，我是" + npc_name + "，村里的" + job + "。"
		# 关系越熟越热情
		var rv: int = relationship.get_relation("玩家")
		if rv >= 40: greet = "又见面了，我的朋友！我是" + npc_name + "。"
		return greet
	if "记得" in t:
		var m: Array = life_memory.top(1)
		if not m.is_empty():
			return "我当然记得……" + m[0].event + "。"
		return "我记性不太好，最近没什么特别的事。"
	if "工作" in t or "做什么" in t or "忙" in t:
		return _work_line()
	if "天气" in t:
		return _weather_line()
	if "梦想" in t or "目标" in t or "理想" in t:
		return "我的梦想是" + goal_sys.life_dream + "。"
	if "心情" in t or "怎么样" in t:
		return "我现在感觉" + emotion_sys.mood() + "。"
	if "家人" in t or "妻子" in t or "家庭" in t:
		if spouse:
			return "我的爱人是" + spouse.npc_name + "，我们一起在村里生活。"
		return "我目前还是一个人。"
	# 默认：结合情绪 + 今日目标
	return ai.inner_thought(self)

func _work_line() -> String:
	match job:
		"铁匠": return ["我正在打农具，村里的铁器都出自我手。", "炉火不能灭，今天还有好几把锄头要打。"].pick_random()
		"农夫", "农民":
			var w := _weather_line()
			return "我在照看庄稼。" + w
		"渔夫": return ["今天河上的渔获还不错。", "打鱼要耐得住性子，我天生就是这块料。"].pick_random()
		"商人": return ["我在市场做点买卖，货物从北境部落一路到沙漠城邦。", "低买高卖，这就是我的营生。"].pick_random()
		"面包师": return "我在烤面包，闻到麦香了吗？"
		"织布工": return "我在织布，想给家里人做几件新衣裳。"
		"孩子": return "我还小，今天只想在村里玩！"
	return "我在忙今天的活计。"

func _weather_line() -> String:
	var world = get_node_or_null("/root/Main/World")
	if world and world.get("ecosystem") and world.ecosystem.get("weather_sys"):
		var w: String = world.ecosystem.weather_sys.weather
		match w:
			"雨": return "今年雨水足，庄稼应该有好收成。"
			"暴雨": return "这暴雨来得凶，但愿别冲了田。"
			"雪": return "下雪了，今年冬天怕是不好熬。"
			"干旱": return "再不下雨，今年的粮食就悬了。"
	return "今天天气不错。"

# ---------- 人生事件外部接口 ----------
func experience(ev: Dictionary) -> void:
	life_events.log_event(life_memory, emotion_sys, ev.get("text",""), ev.get("importance",10), ev.get("year",_year()), ev.get("kind","普通"))

func setup(home: Vector3, work: Vector3, food: Vector3) -> void:
	job_node.home_position = home
	job_node.work_position = work
	job_node.food_position = food
	position = home
	target = home

func on_hour_changed(_hour: int) -> void:
	_decide()

func _decide() -> void:
	var sched = get_node_or_null('/root/Main/World/Scheduler')
	if sched and sched.has_method('note_ai_tick'):
		sched.note_ai_tick()
	var clock: Node = get_node_or_null("/root/Main/WorldTime")
	var hour: int = clock.get_hour() if clock else 12
	var action: String = ai.decide(needs, hour, personality_sys, emotion_sys)
	if action != current_action:
		current_action = action
		execute(action)

func execute(action: String) -> void:
	match action:
		"工作":
			target = job_node.work_at()
		"吃饭":
			target = job_node.food_at()
		"睡觉", "休息":
			target = job_node.home_at()
		"社交":
			target = Vector3(randf_range(-2,2), 0, randf_range(-2,2))
		"探索":
			target = Vector3(randf_range(-18,18), 0, randf_range(-18,18))
	_update_action_icon()

var _far_acc: float = 0.0
var sim_position: Vector3 = Vector3.ZERO   # Data 层快照（0.19.7 模拟队列）
var sim_health: float = 100.0
var _sim_tick: int = 0

## 0.19.7 Data 层轻量模拟：由 SimQueue 分批调用（每 10 秒一批，每帧 ≤30）
func simulate() -> void:
	_sim_tick += 1
	sim_position = position
	if needs and needs.get("health") != null:
		sim_health = needs.health
func _physics_process(delta: float) -> void:
	# 0.19.6 LOD1：远处 NPC 走低频平移（5Hz，无物理、无摆动动画），近处完整物理
	var d_player: float = 99999.0
	if player:
		d_player = global_position.distance_to(player.global_position)
	if d_player > 100.0:
		_far_acc += delta
		if _far_acc < 0.2:
			return
		_far_acc = 0.0
		if target != Vector3.ZERO:
			var to_target: Vector3 = target - position
			to_target.y = 0.0
			if to_target.length() > 0.8:
				var dir: Vector3 = to_target.normalized()
				position += dir * speed * 0.2
			elif d_player <= 150.0:
				_arrived(delta * 0.2)
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	var move_speed: float = speed
	if needs.hunger < 20.0:
		move_speed = speed * 0.5
	if target != Vector3.ZERO:
		var to_target: Vector3 = target - position
		to_target.y = 0.0
		if to_target.length() > 0.8:
			var dir: Vector3 = to_target.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			look_at_from_position(position, position + dir, Vector3.UP)
			_walk_phase += delta * 10.0
			$Body.position.y = 0.95 + sin(_walk_phase) * 0.05
			$ArmL.rotation.x = sin(_walk_phase) * 0.5
			$ArmR.rotation.x = -sin(_walk_phase) * 0.5
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			$Body.position.y = lerp($Body.position.y, 0.95, delta * 5)
			_arrived(delta)
	move_and_slide()

func _arrived(delta: float) -> void:
	match current_action:
		"吃饭":
			needs.eat()
			emotion_sys.adjust("幸福", 2.0)
		"睡觉", "休息":
			needs.sleep()
			emotion_sys.daily_decay()
		"工作":
			_work_anim(delta)
		"社交":
			emotion_sys.adjust("幸福", delta * 2.0)

func _work_anim(delta: float) -> void:
	_work_phase += delta * 3.0
	match job:
		"铁匠":
			$ArmR.rotation.x = -abs(sin(_work_phase)) * 2.2 + 0.3
			$ArmL.rotation.x = 0.2
		"农夫", "农民":
			$Body.rotation.x = lerp($Body.rotation.x, 0.35, delta * 4.0)
			$ArmL.rotation.x = 1.2
			$ArmR.rotation.x = 1.2
		_:
			$ArmL.rotation.x = sin(_work_phase) * 0.3
			$ArmR.rotation.x = -sin(_work_phase) * 0.3

func _process(delta: float) -> void:
	# LOD（0.15）：远离玩家时降频更新，近处全量——支撑大规模人口模拟
	var lod_far: bool = false
	if player:
		var d0: float = global_position.distance_to(player.global_position)
		lod_far = d0 > 60.0
		if name_label:
			name_label.visible = d0 < 12.0
			name_label.modulate.a = clamp(1.0 - (d0 - 6.0) / 6.0, 0.0, 1.0)
			if action_label:
				action_label.visible = name_label.visible
				action_label.modulate.a = name_label.modulate.a
	if lod_far:
		if Engine.get_physics_frames() % 600 == 0:
			needs.update(delta * 60.0)
			_decide()
		return
	needs.update(delta)
	if current_action != "工作":
		$Body.rotation.x = lerp($Body.rotation.x, 0.0, delta * 4.0)
	if Engine.get_physics_frames() % 300 == 0:
		_decide()

func _apply_job_visual() -> void:
	# 0.19.1 职业外观：衣服配色 + 职业帽
	var body: MeshInstance3D = get_node_or_null("Body")
	var job_col: Color
	match job:
		"农民": job_col = Color(0.45, 0.6, 0.3)
		"伐木工": job_col = Color(0.55, 0.4, 0.25)
		"矿工": job_col = Color(0.5, 0.5, 0.52)
		"铁匠": job_col = Color(0.3, 0.32, 0.5)
		"商人": job_col = Color(0.7, 0.35, 0.3)
		"渔夫": job_col = Color(0.3, 0.55, 0.6)
		_: job_col = Color(0.25, 0.45, 0.85)
	if body:
		var bm := StandardMaterial3D.new()
		bm.albedo_color = job_col; bm.roughness = 0.9
		body.material_override = bm
	# 职业帽（铁匠/矿工=筒帽，商人=宽檐帽，其他=小帽）
	var hat := MeshInstance3D.new()
	var hat_col := job_col.darkened(0.25)
	match job:
		"铁匠", "矿工":
			hat.mesh = CylinderMesh.new()
			hat.mesh.top_radius = 0.16; hat.mesh.bottom_radius = 0.2; hat.mesh.height = 0.22
			hat.position = Vector3(0, 1.82, 0)
			hat.rotation.x = deg_to_rad(6)
		"商人":
			hat.mesh = CylinderMesh.new()
			hat.mesh.top_radius = 0.3; hat.mesh.bottom_radius = 0.32; hat.mesh.height = 0.08
			hat.position = Vector3(0, 1.72, 0)
		_:
			hat.mesh = SphereMesh.new()
			hat.mesh.radius = 0.13; hat.mesh.height = 0.24
			hat.position = Vector3(0, 1.83, 0)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = hat_col; hm.roughness = 0.85
	hat.material_override = hm
	add_child(hat)