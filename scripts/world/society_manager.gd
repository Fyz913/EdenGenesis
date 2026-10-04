extends Node
## 村庄社会大脑：维护人口、家庭、关系

const PopulationClass = preload("res://scripts/society/population.gd")
const FamilyClass = preload("res://scripts/society/family.gd")
const MarriageClass = preload("res://scripts/society/marriage.gd")
const ChildClass = preload("res://scripts/society/child.gd")
const NpcScene = preload("res://scenes/npc.tscn")

var population: Node
var families: Array = []
var world: Node = null  # 用于在世界里生成新 NPC
var _social_tick: float = 0.0
var _child_timer: float = 0.0
var _age_timer: float = 0.0
var _marriage_timer: float = 0.0
## 演示节奏（0.19.1）：8 秒 = 1 岁；每 10 秒各家庭生一孩（上限 4）；每 15 秒成年单身分家结婚
const AGE_STEP_SEC: float = 8.0
const CHILD_INTERVAL: float = 10.0
const CHILD_MAX_PER_FAMILY: int = 4
const MARRIAGE_INTERVAL: float = 15.0
## 0.19.6 调试开关：关闭后屏蔽社会事件高频 print
const DEBUG_SOCIAL: bool = false

func _ready() -> void:
	population = PopulationClass.new()
	add_child(population)
	print("[Society] 社会系统初始化，人口: ", population.count())

func register(npc: Node) -> void:
	population.add(npc)

func _process(delta: float) -> void:
	_social_tick += delta
	_child_timer += delta
	_age_timer += delta
	_marriage_timer += delta
	# 每 2 秒扫一次关系
	if _social_tick >= 2.0:
		_social_tick = 0.0
		_check_proximities()
	# 每 8 秒全体 +1 岁（孩子会成年）
	if _age_timer >= AGE_STEP_SEC:
		_age_timer = 0.0
		_age_up()
	# 每 10 秒尝试一次家庭生孩子（加速演示，但不会爆炸）
	if _child_timer >= CHILD_INTERVAL:
		_child_timer = 0.0
		_try_have_children()
	# 每 15 秒：成年单身分家结婚 → 新家庭继续生育（人口闭环）
	if _marriage_timer >= MARRIAGE_INTERVAL:
		_marriage_timer = 0.0
		_try_adult_marriage()

## 全体居民年龄 +1（演示速率：8 秒 = 1 岁）
func _age_up() -> void:
	for npc in population.residents:
		if npc.get("age") == null: continue
		npc.age += 1
		# 孩子成年：转职、恢复体型（工作点由 AI 每小时决策时按 job 定位）
		if npc.job == "孩子" and npc.age >= 18:
			var adult_job: String = ["农民", "伐木工", "矿工", "商人", "铁匠", "渔夫"].pick_random()
			if npc.has_method("retrain"):
				npc.retrain(adult_job)
			npc.job = adult_job
			npc.scale = Vector3.ONE
			_fire_toast("🌱", npc.npc_name + " 成年，成为" + adult_job)
			if DEBUG_SOCIAL: print("[Society] 成年：", npc.npc_name, "→", adult_job)

## 成年单身居民配对结婚，组建新家庭（人口增长不封顶）
## 0.19.5：全两两 O(S²) 改为随机采样配对（每轮最多试 MAX_PAIRS 对），人口多时不再卡顿
const MAX_PAIRS_PER_TICK: int = 80
func _try_adult_marriage() -> void:
	var singles: Array = []
	for npc in population.residents:
		if not is_instance_valid(npc): continue
		if npc.get("age") == null: continue
		if npc.age < 18: continue
		if npc.get("spouse") != null: continue
		singles.append(npc)
	if singles.size() < 2: return
	var tried: int = 0
	while tried < MAX_PAIRS_PER_TICK and singles.size() >= 2:
		var ai: int = randi() % singles.size()
		var a: Node = singles[ai]
		if not is_instance_valid(a) or a.get("spouse") != null:
			singles.remove_at(ai); tried += 1; continue
		var bi: int = randi() % singles.size()
		if bi == ai: bi = (bi + 1) % singles.size()
		var b: Node = singles[bi]
		if not is_instance_valid(b) or b.get("spouse") != null:
			tried += 1; continue
		tried += 1
		if MarriageClass.can_marry(a, b):
			register_family(a, b)
			singles.erase(a); singles.erase(b)
			# 新房保障
			var st = world.get("settlement") if world else null
			if st:
				st.ensure_housing(population.count())
			var civ = world.get("civ") if world else null
			if civ:
				civ.set_population(population.count())

## 0.19.6：关系邻近检测统一走 SpatialGrid（50m Cell，只查附近 3×3）
func _check_proximities() -> void:
	var list: Array = population.residents
	if list.size() < 2: return
	var grid = null
	if world:
		grid = world.get_node_or_null("SpatialGrid")
	if grid == null:
		return
	grid.rebuild(list)
	for a in list:
		if not is_instance_valid(a): continue
		for b in grid.get_nearby(a.global_position, 1):
			if b == a or not is_instance_valid(b): continue
			if a.global_position.distance_to(b.global_position) < 5.0:
				_make_friend(a, b)

func _make_friend(a: Node, b: Node) -> void:
	if a.get("relationship") and b.get("relationship"):
		a.relationship.add_relation(b.npc_name, 2)
		b.relationship.add_relation(a.npc_name, 2)

func _try_have_children() -> void:
	for fam in families:
		if fam.father == null or fam.mother == null: continue
		if fam.children.size() >= CHILD_MAX_PER_FAMILY: continue
		var child = ChildClass.new()
		child.setup(fam.father, fam.mother)
		fam.add_kid(child)
		# 真的在世界里生成一个小 NPC
		_spawn_child_npc(fam)
		if DEBUG_SOCIAL: print("[Society] 新孩子出生：父亲=", fam.father.npc_name, " 母亲=", fam.mother.npc_name, " 当前孩子数=", fam.children.size())

func _spawn_child_npc(fam) -> void:
	if world == null: return
	var baby: CharacterBody3D = NpcScene.instantiate()
	var baby_name: String = "小" + fam.father.npc_name.substr(1, 1) + str(fam.children.size())
	baby.set("npc_name", baby_name)
	baby.set("job", "孩子")
	baby.set("age", 0)
	baby.scale = Vector3(0.5, 0.5, 0.5)  # 小孩小一点
	world.resident_root.add_child(baby)
	var home: Vector3 = fam.father.job_node.home_position
	baby.position = home + Vector3(randf_range(-1,1), 0, randf_range(-1,1))
	baby.setup(home, home, home)
	world.clock.subscribe(baby)
	# 孩子继承父母性格
	if baby.get("personality_sys") and fam.father.get("personality_sys") and fam.mother.get("personality_sys"):
		baby.personality_sys.inherit_from(fam.father.personality_sys.traits, fam.mother.personality_sys.traits)
	# 人生记忆：孩子的出生 + 父母的记忆
	var yr: int = 1
	var world_eco = world.get("ecosystem")
	if world_eco and world_eco.get("season_sys"): yr = world_eco.season_sys.year
	baby.experience({"text": "我出生在 Eden，父亲是" + fam.father.npc_name + "，母亲是" + fam.mother.npc_name, "importance": 95, "year": yr, "kind": "出生"})
	fam.father.experience({"text": "我的孩子" + baby_name + "出生了", "importance": 80, "year": yr, "kind": "出生"})
	fam.mother.experience({"text": "我的孩子" + baby_name + "出生了", "importance": 80, "year": yr, "kind": "出生"})
	# 注册到人口
	population.add(baby)
	# 住房不足则自动盖新房
	var st = world.get("settlement")
	if st:
		st.ensure_housing(population.count())
	# 通知文明系统人口变化
	var civ = world.get("civ")
	if civ:
		civ.set_population(population.count())
	# 聚落自动升级：人口 + 粮食储备 + 住房 同时满足
	if st:
		var new_lv: int = 1
		var n: int = population.count()
		if n >= 50: new_lv = 3
		elif n >= 15: new_lv = 2
		var food_ok: bool = true
		var house_ok: bool = st.capacity() >= n
		var econ = world.get("economy")
		if econ:
			food_ok = econ.market.stock.get("food", 0.0) >= n * 3.0
		if new_lv > st.level and food_ok and house_ok:
			st.upgrade_to(new_lv)
			_fire_toast("🏛", "Eden 升级为 " + ["","村庄","城镇","城市"][new_lv])
		elif new_lv > st.level and not food_ok:
			_fire_toast("📦", "人口已达标，但粮食储备不足，无法升级")
	_fire_toast("👶", "新居民出生：" + baby_name)

func _fire_toast(icon: String, text: String) -> void:
	var toast = get_node_or_null("/root/Main/EventToast")
	if toast and toast.has_method("show_event"):
		toast.show_event(icon, text)

## 居民离世/离开：从人口、家庭、世界安全移除，同步文明数据并记录历史
func remove_resident(npc: Node, reason: String) -> void:
	if not is_instance_valid(npc): return
	if population.count() <= 1:
		_fire_toast("🛡", "村庄只剩最后一人，不会继续减少")
		npc.starve_days = 0
		return
	# 家庭解绑
	if npc.family:
		var fam = npc.family
		if fam.father == npc: fam.father = null
		elif fam.mother == npc: fam.mother = null
		else: fam.children.erase(npc)
	# 配偶解绑
	if npc.spouse and is_instance_valid(npc.spouse) and npc.spouse.get("spouse") == npc:
		npc.spouse.spouse = null
	# 从人口移除
	population.remove(npc)
	# 文明人口同步
	var civ = world.get("civ")
	if civ:
		civ.set_population(population.count())
	# 历史记录
	var hist = civ.get("history") if civ else null
	var yr: int = 1
	var eco = world.get("ecosystem")
	if eco and eco.get("season_sys"): yr = eco.season_sys.year
	if hist:
		hist.record("第%d年：%s %s" % [yr, npc.npc_name, reason])
	# 从世界移除
	if is_instance_valid(npc):
		npc.queue_free()
	_fire_toast("⚰️", npc.npc_name + " " + reason)

## 贫困居民寻找新工作：连续贫困且非产粮岗的成年人，转行产粮职业
func handle_social_mobility() -> void:
	if world == null: return
	for npc in population.residents:
		var age_v = npc.get("age") if npc.get("age") != null else 0
		if age_v < 18: continue
		var pov = npc.get("poverty") if npc.get("poverty") != null else 0.0
		if pov < 4.0: continue
		if npc.get("job") in ["农民", "农夫", "渔夫", "面包师"]:
			npc.poverty = 0.0
			continue
		var new_job: String = ["农民", "渔夫", "面包师"].pick_random()
		npc.retrain(new_job)
		_fire_toast("🔁", npc.npc_name + " 为求生计，改当" + new_job)

## 饥荒检查：连续挨饿过久的居民离世
func handle_famine() -> void:
	if world == null: return
	var econ = world.get("economy")
	if econ == null: return
	var victims: Array = econ.starving_list(population.residents, 5)
	for v in victims:
		remove_resident(v, "因饥荒离世")

func register_family(f: Node, m: Node) -> void:
	var fam = FamilyClass.new()
	fam.create(f, m, "family_" + str(families.size() + 1))
	f.family = fam
	m.family = fam
	fam.father.spouse = fam.mother
	fam.mother.spouse = fam.father
	families.append(fam)
	# 结婚人生事件
	var yr: int = 1
	if world and world.get("ecosystem") and world.ecosystem.get("season_sys"): yr = world.ecosystem.season_sys.year
	if f.has_method("experience"):
		f.experience({"text": "我与" + m.npc_name + "结为夫妻", "importance": 85, "year": yr, "kind": "结婚"})
		m.experience({"text": "我与" + f.npc_name + "结为夫妻", "importance": 85, "year": yr, "kind": "结婚"})
	if DEBUG_SOCIAL: print("[Society] 新家庭：", f.npc_name, " & ", m.npc_name)
