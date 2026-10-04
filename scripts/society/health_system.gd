extends Node
class_name HealthSystem
## 0.16 健康系统：居民健康/疾病微变化 → 生病影响工作效率（接入经济层）
## 影响因素：饥饿、住房拥挤、战争、年龄；治疗：诊所 Lv3 / 医院 Lv4

var world: Node = null

func bind(w: Node) -> void:
	world = w

## 每天结算（健康在 Day 层，微变化）
func daily_tick(residents: Array, city) -> void:
	var over_crowd: bool = city != null and city.population > city.housing_capacity
	var at_war: bool = false
	var civ = world.get("civ") if world else null
	if civ and civ.get("at_war") != null:
		at_war = civ.at_war
	var clinic: int = city.clinics if city else 0
	var hospital: int = city.hospitals if city else 0
	var heal: float = 0.2
	if hospital > 0: heal = 2.5
	elif clinic > 0: heal = 1.5
	for n in residents:
		var d: float = -heal
		if n.starve_days > 0: d += 0.8
		if n.age > 50: d += 0.02 * (n.age - 50) / 10.0
		if over_crowd: d += 0.3
		if at_war: d += 0.4
		n.sickness = clamp(n.sickness + d, 0.0, 100.0)
		n.health = 100.0 - n.sickness

## 生病率（面板用）：sickness > 30 的居民占比
func sick_rate(residents: Array) -> float:
	var sick: int = 0
	for n in residents:
		if n.sickness > 30.0: sick += 1
	if residents.is_empty(): return 0.0
	return sick * 100.0 / residents.size()
