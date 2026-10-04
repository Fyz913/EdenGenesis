extends Node
class_name GovernmentSystem
## 0.18 政府系统：在 0.13 部落→村社→城镇议会 之上，扩展国家级制度转型。
## 转型必须真实条件触发（多城/人口/教育/组织/稳定），不按年份。
## 王国：多城市 + 总人口≥300 + 组织齐备
## 共和国：城镇规模 + 教育率 + 政治组织 + 稳定
## 帝国：多地区 + 行政能力 + 军事实力

var world: Node = null

func bind(w: Node) -> void:
	world = w

func evaluate_transition(w, gov, country) -> void:
	world = w
	if gov == null or country == null: return
	var civ = world.get("civ") if world else null
	var city_mgr = world.get("city_mgr") if world else null
	var cities: Array = city_mgr.get_all_cities() if city_mgr and city_mgr.has_method("get_all_cities") else []
	var total_pop: int = country.population
	# 王国：≥2 城 + 总人口≥300 + 有组织 + 稳定≥50
	if gov.type in ["村社", "城镇议会"] and cities.size() >= 2 and total_pop >= 300 and country.stability >= 50.0:
		_switch(gov, country, "王国", "多座城市与稳定人口促成王国建立")
		return
	# 共和国：人口≥800 + 教育率≥40 + 组织≥3 + 稳定≥60
	if gov.type == "王国" and total_pop >= 800 and _education_rate(world) >= 40.0 and _org_count(world) >= 3 and country.stability >= 60.0:
		_switch(gov, country, "共和国", "教育与政治组织成熟，王权让位于共和制度")
		return
	# 帝国：≥3 城 + 人口≥2000 + 领土广 + 军力强
	if gov.type in ["王国", "共和国"] and cities.size() >= 3 and total_pop >= 2000 and country.territory_cells.size() >= 80 and _military_power(gov) >= 200.0:
		_switch(gov, country, "帝国", "辽阔领土与强大军力催生帝国体制")
		return

func _switch(gov, country, new_type: String, reason: String) -> void:
	gov.type = new_type
	country.government_type = new_type
	country.record("第%d年 Eden 制度转型：%s（%s）" % [_year(), new_type, reason])
	_hist("[国家]", "Eden 升级为" + new_type + "！" + reason)
	_toast("🏛", "Eden 进入" + new_type + "时代")

func _education_rate(world) -> float:
	var edu_sys = world.get("education_sys") if world else null
	if edu_sys and edu_sys.has_method("education_rate"):
		var society = world.get("society")
		if society:
			return edu_sys.education_rate(society.population.residents)
	return 0.0

func _org_count(world) -> int:
	var org_mgr = world.get("org_mgr") if world else null
	return org_mgr.organizations.size() if org_mgr else 0

func _military_power(gov) -> float:
	return gov.military_power if gov else 0.0

func _year() -> int:
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"):
		return eco.season_sys.year
	return 1

func _hist(kind: String, text: String) -> void:
	var civ = world.get("civ") if world else null
	var hist = civ.get("history") if civ else null
	if hist: hist.record("第%d年[%s] %s" % [_year(), kind, text])

func _toast(icon: String, text: String) -> void:
	var toast = get_node_or_null("/root/Main/EventToast")
	if toast and toast.has_method("show_event"):
		toast.show_event(icon, text)
