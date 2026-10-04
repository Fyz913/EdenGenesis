extends Node
class_name SocialSimulation
## 0.16 社会模拟总指挥：串起 社会网络/教育/健康/犯罪/文化/阶层/稳定度
## 频率分层：每天=健康+不满+互动；每月=阶层/教育/犯罪/稳定度/政治压力；每年=文化/节日
## 所有输出都进入真实系统（history/memory/relationship/economy/government），不造假。

const NetworkScript: Script = preload("res://scripts/society/social_network.gd")
const EducationScript: Script = preload("res://scripts/society/education_system.gd")
const HealthScript: Script = preload("res://scripts/society/health_system.gd")
const CrimeScript: Script = preload("res://scripts/society/crime_system.gd")
const CultureScript: Script = preload("res://scripts/society/culture_system.gd")
const ClassScript: Script = preload("res://scripts/society/social_class.gd")

var world: Node = null
var network: Node
var education: Node
var health: Node
var crime: Node
var culture: Node
var class_sys: Node

var social_stability: float = 70.0

func bind(w: Node) -> void:
	world = w
	network = NetworkScript.new(); add_child(network); network.bind(w)
	education = EducationScript.new(); add_child(education); education.bind(w)
	health = HealthScript.new(); add_child(health); health.bind(w)
	crime = CrimeScript.new(); add_child(crime); crime.bind(w)
	culture = CultureScript.new(); add_child(culture); culture.bind(w)
	class_sys = ClassScript.new(); add_child(class_sys)
	# 全局引用（director / hud / 其他系统访问）
	w.set("social_sim", self)
	w.set("social_network", network)
	w.set("education_sys", education)
	w.set("health_sys", health)
	w.set("crime_sys", crime)
	w.set("culture_sys", culture)

## 每天：健康微变化 + 不满微变化 + 少量活跃关系互动
func daily_tick(residents: Array, city, gov) -> void:
	health.daily_tick(residents, city)
	_update_dissatisfaction(residents, gov)
	network.daily_interaction(4)

## 每月：阶层重算 / 教育 / 犯罪事件 / 稳定度 → 政治压力 / 网络重建
func monthly_tick(residents: Array, city, gov) -> Dictionary:
	var out: Dictionary = {}
	out["education"] = education.monthly_tick(residents, city, gov)
	out["crime"] = crime.monthly_tick(city, residents, gov)
	out["class_changes"] = _recalc_classes(residents)
	_calc_stability(residents, city, gov)
	network.build_network(residents)
	return out

## 每年：丰收节 / 文化传播 / 人口结构
func yearly_tick(residents: Array, city) -> Dictionary:
	return culture.yearly_tick(residents, city)

## 不满度：每月更新来源（失业/贫困/高税/住房/食物/战争/治安）
func _update_dissatisfaction(residents: Array, gov) -> void:
	var at_war: bool = false
	var civ = world.get("civ") if world else null
	if civ and civ.get("at_war") != null: at_war = civ.at_war
	var tax_high: bool = gov != null and gov.tax_rate > 0.08
	for n in residents:
		var d: float = 0.0
		if n.money < 20.0: d += 15.0
		if n.poverty > 5.0: d += 10.0
		if n.starve_days > 0: d += 20.0
		if tax_high: d += 10.0
		if at_war: d += 12.0
		if n.family and n.family.home_id == "": d += 8.0
		n.political_dissatisfaction = clamp(n.political_dissatisfaction * 0.8 + d * 0.2, 0.0, 100.0)

## 阶层：按真实财富每月重算，变化写入历史与记忆（社会流动）
func _recalc_classes(residents: Array) -> int:
	var changes: int = 0
	var yr: int = _year()
	for n in residents:
		var cur: String = class_sys.class_of(n.money)
		if cur != n.social_class:
			if n.social_class != "":
				changes += 1
				_record("社会", n.npc_name + " 由「" + n.social_class + "」变为「" + cur + "」")
				if n.get("life_memory"):
					n.life_memory.record("家境变化，如今属于" + cur + "阶层", 35, yr, "重要")
			n.social_class = cur
	return changes

## 社会稳定度 → 政府合法性 / 支持率（政治压力闭环）
func _calc_stability(residents: Array, city, gov) -> void:
	var hap: float = city.happiness if city else 50.0
	var infra: float = city.infrastructure if city else 10.0
	var unemp: float = 0.0
	if city and city.population > 0:
		unemp = float(city.unemployed) * 100.0 / city.population
	var crime_rate: float = crime.calculate_city_crime(city, residents)
	social_stability = clamp(50.0 + hap * 0.2 + infra * 0.15 - unemp * 25.0 - crime_rate * 0.15, 0.0, 100.0)
	if city: city.social_stability = social_stability
	if gov:
		var diff: float = social_stability - 70.0
		gov.legitimacy = clamp(gov.legitimacy + diff * 0.15, 0.0, 100.0)
	var politics = world.get("politics") if world else null
	if politics and politics.get("support_rate") != null:
		politics.support_rate = clamp(politics.support_rate + (social_stability - 70.0) * 0.2, 0.0, 100.0)

func _year() -> int:
	if world and world.get("ecosystem") and world.ecosystem.get("season_sys"):
		return world.ecosystem.season_sys.year
	return 1

func _record(kind: String, text: String) -> void:
	var civ = world.get("civ") if world else null
	var hist = civ.get("history") if civ else null
	if hist: hist.record("第%d年[%s] %s" % [_year(), kind, text])
