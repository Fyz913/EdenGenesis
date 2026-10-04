extends Node
class_name CrimeSystem
## 0.16 犯罪系统（社会层面，不做 GTA）：
## 犯罪率 = f(贫困比, 失业比, 幸福, 基建, 治安建筑)
## 犯罪不凭空产生：每月按概率触发真实事件（受害者/嫌疑人/地点/时间）→ 历史+记忆+关系

var world: Node = null

func bind(w: Node) -> void:
	world = w

## 城市犯罪率 0-100
func calculate_city_crime(city, residents: Array) -> float:
	var crime: float = 10.0
	var pop: int = city.population if city else residents.size()
	if pop > 0:
		var poor: int = 0
		for n in residents:
			if n.money < 20.0: poor += 1
		crime += (poor * 100.0 / pop) * 30.0
		# 失业比（有劳动能力但无职业）
		var idle: int = 0
		for n in residents:
			if n.age >= 18 and n.job == "孩子": idle += 1
		crime += (idle * 100.0 / pop) * 25.0
	var hap: float = city.happiness if city else 50.0
	var infra: float = city.infrastructure if city else 10.0
	crime -= hap * 0.15
	crime -= infra * 0.1
	if city:
		var gp = city.get("guard_posts")
		var ps = city.get("police_stations")
		if gp != null: crime -= gp * 8.0
		if ps != null: crime -= ps * 12.0
	return clamp(crime, 0.0, 100.0)

## 每月：犯罪率高于阈值时可能触发真实事件
func monthly_tick(city, residents: Array, gov) -> bool:
	var rate: float = calculate_city_crime(city, residents)
	if rate < 40.0: return false
	if randf() > 0.3: return false
	# 真实事件：受害者 / 嫌疑人 / 地点 / 时间
	var victims: Array = residents.filter(func(n): return n.money >= 10.0)
	if victims.is_empty(): return false
	var victim = victims.pick_random()
	var suspects: Array = residents.filter(func(n): return n != victim)
	if suspects.is_empty(): return false
	var suspect = suspects.pick_random()
	var places: Array = ["市场", "住宅区", "仓库", "酒馆附近", "农田边"]
	var place: String = places.pick_random()
	var yr: int = 1
	if world and world.get("ecosystem") and world.ecosystem.get("season_sys"):
		yr = world.ecosystem.season_sys.year
	var kinds: Array = ["钱袋被窃", "货物被偷", "遭到勒索"]
	var kind: String = kinds.pick_random()
	var text: String = "%s 在%s遭遇盗窃，%s的%s被%s所盗。" % [victim.npc_name, place, victim.npc_name, kind, suspect.npc_name]
	# 历史 + 双方记忆/关系
	var civ = world.get("civ") if world else null
	if civ and civ.get("history"):
		civ.history.record("第%d年[治安] %s" % [yr, text])
	var net: Node = world.get("social_network") if world else null
	if net and net.has_method("social_event"):
		net.social_event(victim, suspect, -25, "我的" + kind + "被" + suspect.npc_name + "偷走了", 60)
	# 受害者幸福受损
	if victim.get("needs"):
		victim.needs.happiness = max(0.0, victim.needs.happiness - 8.0)
	return true
