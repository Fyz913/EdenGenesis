extends Node
## 人口迁移系统（0.15）：
## 1) 迁移评分 = 住房*0.1 + 就业*0.1 + 幸福*0.3 + 繁荣*0.3 + 基础设施*0.2
## 2) 每年根据评分与城市承载力真实迁入/迁出居民（改变 Human 数据，不造假）
## 迁入：住房有富余 + 食物充足 + 城市吸引力高 → 生成一名"外来移民"入住空房、进入就业。
## 迁出：战争/幸福过低 + 有富余人口 → 一名居民离乡（从世界移除）。

const NpcScene = preload("res://scenes/npc.tscn")

const IMMIGRANT_FAMILY_NAMES := ["韩", "曹", "严", "华", "金", "魏", "陶", "姜", "苏", "马"]
const IMMIGRANT_GIVEN_NAMES := ["山", "河", "川", "风", "云", "雷", "雨", "雪", "林", "石"]

func calculate_score(city) -> float:
	if city == null: return 0.0
	return (city.housing_capacity * 0.1
		+ city.employment_capacity * 0.1
		+ city.happiness * 0.3
		+ city.prosperity * 0.3
		+ city.infrastructure * 0.2)

## 每年一次：处理迁入/迁出
func yearly_tick(city, world) -> void:
	if city == null or world == null: return
	var society = world.get("society")
	if society == null: return
	var pop: int = society.population.count()
	# ---- 迁出：战争或幸福过低 ----
	var war_mgr = world.get("war_mgr")
	var at_war: bool = false
	if war_mgr and war_mgr.has_method("get_active_war_for"):
		at_war = war_mgr.get_active_war_for("Eden") != null
	city.migration_out = 0
	if (at_war or city.happiness < 25.0) and pop > 12:
		if randf() < 0.35:
			_exile_one(city, world)
			city.migration_out = 1
	# ---- 迁入：评分高 + 住房富余 + 食物充足 ----
	city.migration_in = 0
	var score: float = calculate_score(city)
	var housing_room: bool = city.housing_capacity >= pop * 1.3
	if score > 40.0 and housing_room and city.food_supply > pop * 2.0 and pop < 500:
		if randf() < 0.5:
			_immigrate_one(city, world)
			city.migration_in = 1

## 生成一名外来移民：真实加入世界（新 NPC + 入住房 + 就业 + 记忆）
func _immigrate_one(city, world) -> void:
	var society = world.get("society")
	var settlement = world.get("settlement")
	if society == null or settlement == null: return
	var npc = NpcScene.instantiate()
	var name: String = IMMIGRANT_FAMILY_NAMES.pick_random() + IMMIGRANT_GIVEN_NAMES.pick_random()
	npc.set("npc_name", name)
	npc.set("age", randi_range(18, 35))
	npc.set("job", _needed_job(city, society))
	# 入住：找空房或新盖
	var slot_idx: int = _find_empty_home(settlement)
	if slot_idx < 0:
		settlement.ensure_housing(society.population.count() + 1)
		slot_idx = settlement.home_slots.size() - 1
	var home: Vector3 = settlement.home_slots[slot_idx].door
	settlement.bind_owner(slot_idx, name)
	var work: Vector3 = settlement.get_work_for(npc.job)
	world.resident_root.add_child(npc)
	npc.setup(home, work, settlement.get_food_position())
	world.clock.subscribe(npc)
	society.register(npc)
	var yr: int = _current_year(world)
	if npc.has_method("experience"):
		npc.experience({"text": "我听闻 Eden 繁荣安定，从外地迁来定居，成为" + npc.job, "importance": 70, "year": yr, "kind": "迁移"})
	var civ = world.get("civ")
	if civ and civ.has_method("set_population"):
		civ.set_population(society.population.count())
	_fire_toast(world, "🧳", "新居民迁入 Eden：" + name + "（" + npc.job + "）")
	print("[City] 移民迁入：", name, " 职业：", npc.job)

## 一名居民离乡：真实移除（保护：只剩 12 人不再减少）
func _exile_one(city, world) -> void:
	var society = world.get("society")
	if society == null: return
	var pool: Array = []
	for n in society.population.residents:
		if n.get("age") >= 18 and n.get("job") != "孩子" and n.get("military_service") != true:
			pool.append(n)
	if pool.is_empty(): return
	var leaver = pool.pick_random()
	society.remove_resident(leaver, "迁往他乡")
	city.migration_out += 1
	city.migration_pressure = max(0.0, city.migration_pressure - 10.0)

func _find_empty_home(settlement) -> int:
	var slots = settlement.get("home_slots")
	if slots == null: return -1
	for i in range(slots.size()):
		if slots[i].get("owner", "") == "":
			return i
	return -1

## 按城市需求缺口选职业：商业建筑多 → 商人；工坊多 → 铁匠/矿工；否则产粮岗
func _needed_job(city, society) -> String:
	var job_counts: Dictionary = {}
	for n in society.population.residents:
		var j: String = n.job
		job_counts[j] = job_counts.get(j, 0) + 1
	var candidates: Array = []
	if city.commercial_buildings >= 3:
		candidates = ["商人", "面包师", "织布工"]
	elif city.industrial_buildings >= 2:
		candidates = ["铁匠", "矿工", "伐木工"]
	else:
		candidates = ["农民", "渔夫", "农夫"]
	# 选当前人数最少的
	var best: String = candidates[0]
	var best_n: int = 999999
	for c in candidates:
		var n: int = job_counts.get(c, 0)
		if n < best_n:
			best_n = n
			best = c
	return best

func _current_year(world) -> int:
	var eco = world.get("ecosystem")
	if eco and eco.get("season_sys"):
		return eco.season_sys.year
	return 1

func _fire_toast(world, icon: String, text: String) -> void:
	var toast = get_node_or_null("/root/Main/EventToast")
	if toast and toast.has_method("show_event"):
		toast.show_event(icon, text)
