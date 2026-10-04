extends Node
class_name NationalStatistics
## 0.18 国家统计：聚合国家全维度数据（全部来自真实系统），供 TAB 面板与存档。

## 国家稳定度：经济 + 就业 + 幸福 + 合法性 + 治安（全部真实）
func calculate_stability(world, country) -> float:
	var econ = world.get("economy") if world else null
	var sim = world.get("social_sim") if world else null
	var city_mgr = world.get("city_mgr") if world else null
	var society = world.get("society")
	var residents: Array = society.population.residents if society else []
	var score: float = 50.0
	# 经济：市场状态
	if econ:
		var fed: float = econ.last_fed_ratio
		score += (fed - 0.5) * 40.0
		score += clampf((econ.market.cash - 200.0) * 0.02, -20.0, 20.0)
	# 就业
	if econ and not residents.is_empty():
		var emp: float = econ.employment_rate(residents)
		score += (emp - 50.0) * 0.2
	# 幸福
	if not residents.is_empty():
		var happy_sum: float = 0.0
		for n in residents:
			if n.get("needs"): happy_sum += n.needs.happiness
		score += (happy_sum / residents.size() - 50.0) * 0.2
	# 合法性（政府表现）
	score += (country.legitimacy - 50.0) * 0.2
	# 治安（0.16 犯罪率）
	var crime_sys = world.get("crime_sys") if world else null
	var city = city_mgr.eden_city() if city_mgr else null
	if crime_sys and city:
		score -= crime_sys.calculate_city_crime(city, residents) * 0.15
	if sim:
		score = (score + sim.social_stability) * 0.5
	return clampf(score, 0.0, 100.0)

## 国家面板数据（TAB 国家）
func nation_data(world, country, country_mgr) -> Dictionary:
	if country == null:
		return {"formed": false}
	var gov = null
	var civ = world.get("civ")
	if civ: gov = civ.get("government")
	var army_mgr = world.get("army_mgr")
	var soldiers: int = 0
	if army_mgr:
		var army = army_mgr.armies.get("Eden") if army_mgr.armies else null
		if army: soldiers = army.soldiers
	var econ = world.get("economy")
	return {
		"formed": true,
		"name": country.name,
		"government_type": gov.type if gov else country.government_type,
		"leader": gov.leader_id if gov else "",
		"capital": country.capital_city_id,
		"population": country.population,
		"cities": country.city_ids.size(),
		"territory": country.territory_cells.size(),
		"treasury": gov.treasury if gov else 0.0,
		"income": country.income,
		"expenses": country.expenses,
		"tax_rate": gov.tax_rate if gov else 0.0,
		"legitimacy": gov.legitimacy if gov else 50.0,
		"stability": country.stability,
		"soldiers": soldiers,
		"military_power": gov.military_power if gov else 0.0,
		"military_budget": gov.military_budget if gov else 0.0,
		"deficit_months": country.deficit_months,
		"revolution_risk": country.revolution_risk,
		"laws": _laws_summary(country),
		"groups": _groups_summary(country),
		"budget": country_mgr.budget.summary(country) if country_mgr else {},
		"tax": country_mgr.tax.summary() if country_mgr else {},
		"history": country.history.duplicate(),
	}

func _laws_summary(country) -> Array:
	var out: Array = []
	for l in country.laws:
		out.append({"name": l.name, "enabled": l.enabled, "category": l.category})
	return out

func _groups_summary(country) -> Array:
	var out: Array = []
	for g in country.political_groups:
		out.append({"name": g.name, "members": g.members, "power": g.power, "demand": g.demand})
	return out
