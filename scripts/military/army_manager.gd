extends Node
## 军队管理器：创建/补充军队、征召居民、每日后勤
## 军队不能凭空出现：数量受人口*0.15 上限约束；征召走居民参军条件

const ArmyScript: Script = preload("res://scripts/military/army.gd")
const SoldierScript: Script = preload("res://scripts/military/soldier.gd")
const LogisticsScript: Script = preload("res://scripts/military/military_logistics.gd")

var armies: Dictionary = {}        # civilization_id -> Army
var logistics: Node
# 外部文明人口估计（外交模块的设定，非居民实体）
var foreign_population := {"北境部落": 40.0, "沙漠城邦": 30.0}

func _ready() -> void:
	logistics = LogisticsScript.new()
	add_child(logistics)

func get_army(civ_id: String):
	return armies.get(civ_id, null)

## 创建/刷新一支军队：按人口上限约束，就地补充至上限
func ensure_army(civ_id: String, population: int, location: Vector3) -> void:
	var army = armies.get(civ_id)
	if army == null:
		army = ArmyScript.new()
		army.id = "army_" + civ_id
		army.civilization_id = civ_id
		army.location = location
		armies[civ_id] = army
	var max_n: int = army.max_soldiers(population)
	if army.soldiers < max_n:
		army.soldiers = mini(max_n, army.soldiers + 1)   # 每日缓慢补员
	army.recompute_strength()

## 从居民中征召（Eden 本土）：18-45 岁、未参军、非孩子
func enlist_from_population(world, civ_id: String, count: int) -> void:
	var army = armies.get(civ_id)
	if army == null: return
	var society = world.get("society")
	if society == null: return
	var candidates: Array = []
	for npc in society.population.residents:
		if npc.get("military_service") == null: continue
		if npc.military_service: continue
		var age_v: int = npc.get("age") if npc.get("age") != null else 0
		if age_v < 18 or age_v > 45: continue
		if npc.get("job") == "孩子": continue
		candidates.append(npc)
	var to_enlist: int = mini(count, candidates.size())
	for i in to_enlist:
		var npc = candidates[i]
		npc.enlist()
		var s = SoldierScript.new()
		s.human = npc
		s.human_id = npc.npc_name
		s.civilian_job = npc.job
		army.soldier_refs.append(s)
		army.soldiers = mini(army.max_soldiers(int(world.get("society").population.count())), army.soldiers + 1)
	army.recompute_strength()
	if to_enlist > 0:
		print("[Army] %s 征召 %d 名居民入伍" % [civ_id, to_enlist])

## 退役：战争结束释放参战居民回生产
func release_soldiers(world, civ_id: String) -> void:
	var army = armies.get(civ_id)
	if army == null: return
	for s in army.soldier_refs:
		if is_instance_valid(s.human):
			s.human.retire_from_military()
	army.soldier_refs.clear()
	army.soldiers = 0
	army.recompute_strength()
	# 重新安置回聚落
	var st = world.get("settlement")
	if st:
		st.ensure_housing(int(world.get("society").population.count()))

func daily_tick(world) -> void:
	# Eden 本土：按人口维护常备军（和平时期上限减半，战争时满额）
	var society = world.get("society")
	if society == null: return
	var pop: int = society.population.count()
	var eden_army = armies.get("Eden")
	var at_war: bool = false
	var war_mgr = world.get("war_mgr")
	if war_mgr and war_mgr.get_active_war_for("Eden"):
		at_war = true
	if eden_army == null:
		eden_army = ArmyScript.new()
		eden_army.id = "army_Eden"
		eden_army.civilization_id = "Eden"
		eden_army.location = Vector3(6, 0, -8)   # 军营位置
		armies["Eden"] = eden_army
	var target: int = eden_army.max_soldiers(pop)
	if not at_war:
		target = int(target * 0.5)
	if eden_army.soldiers < target:
		# 优先从居民中征召补齐
		var need: int = target - eden_army.soldiers
		enlist_from_population(world, "Eden", need)
	elif eden_army.soldiers > target:
		# 超过和平上限：释放差额
		release_excess(world, "Eden", eden_army.soldiers - target)
	# 外部文明：按估计人口维持军队
	for civ_id in foreign_population:
		ensure_army(civ_id, int(foreign_population[civ_id]), Vector3.ZERO)
	# 每日后勤（所有军队）
	for army in armies.values():
		logistics.daily_supply(army, world)

func release_excess(world, civ_id: String, n: int) -> void:
	var army = armies.get(civ_id)
	if army == null: return
	var released: int = 0
	for i in range(army.soldier_refs.size() - 1, -1, -1):
		if released >= n: break
		var s = army.soldier_refs[i]
		if is_instance_valid(s.human):
			s.human.retire_from_military()
		army.soldier_refs.remove_at(i)
		released += 1
	army.soldiers = maxi(0, army.soldiers - released)
	army.recompute_strength()
