extends Node
class_name PoliticalSystem
## 0.18 政治系统：政治集团从真实居民/组织聚合（不造假成员）；
## 集团产生政治压力（需求偏好）→ 决策系统；合法性/稳定双低 → 政治危机
## （留原因不随机）；革命风险积累 → 改革压力事件（不直接倒台）。

var world: Node = null

func bind(w: Node) -> void:
	world = w

## 每月：聚合政治集团（真实组织成员）+ 计算力量与压力
func monthly_pressure(w, country) -> void:
	world = w
	if country == null: return
	var org_mgr = world.get("org_mgr") if world else null
	var society = world.get("society") if world else null
	country.political_groups = []
	var groups: Array = [
		{"id": "farmers_guild", "name": "农民协会", "demand": "降低农业税负，保障粮食价格"},
		{"id": "merchant_guild", "name": "商会", "demand": "降低贸易税，开放更多贸易路线"},
		{"id": "crafts_guild", "name": "工匠协会", "demand": "提高工匠工资，增加工坊建设"},
	]
	for g in groups:
		var members: Array = []
		var org = org_mgr.organizations.get(g.id) if org_mgr else null
		if org:
			members = org.members if org.get("members") != null else []
		var power: float = members.size() * 0.5
		if org: power += org.treasury * 0.1
		# 影响力：成员数量 + 居民富裕度（真实）
		if society:
			for n in society.population.residents:
				if members.has(n.npc_name) and n.get("money") != null:
					power += n.money * 0.001
		country.political_groups.append({
			"id": g.id, "name": g.name,
			"members": members.size(), "power": power,
			"pressure": clampf(power * 0.1, 0.0, 100.0),
			"demand": g.demand,
		})
	# 军事集团（士兵来源=真实军队）
	var army_mgr = world.get("army_mgr") if world else null
	var soldiers: int = 0
	if army_mgr:
		var army = army_mgr.armies.get("Eden") if army_mgr.armies else null
		if army: soldiers = army.soldiers
	country.political_groups.append({
		"id": "military", "name": "军事集团", "members": soldiers, "power": soldiers * 0.8,
		"pressure": clampf(soldiers * 0.08, 0.0, 100.0), "demand": "增加军费，巩固国防",
	})

## 每年：合法性/稳定双低 → 政治危机（留原因）；革命风险积累
func annual_crisis(w, country, gov) -> float:
	world = w
	if country == null or gov == null: return country.revolution_risk
	var sim = world.get("social_sim") if world else null
	var social_stability: float = sim.social_stability if sim else 70.0
	var reasons: Array = []
	# 真实原因：贫困率 / 失业率 / 粮价 / 合法性 / 稳定
	var econ = world.get("economy") if world else null
	var residents: Array = []
	var society = world.get("society")
	if society: residents = society.population.residents
	var poverty: float = 0.0
	var unemployment: float = 0.0
	if not residents.is_empty():
		var poor: int = 0
		var jobless: int = 0
		for n in residents:
			if n.get("money") != null and n.money < 20.0: poor += 1
			if n.get("job") == null or n.job == "": jobless += 1
		poverty = poor * 100.0 / residents.size()
		unemployment = jobless * 100.0 / residents.size()
	var food_price: float = econ.market.prices.get("food", 5.0) if econ else 5.0
	if poverty >= 30.0: reasons.append("贫困率 %d%%" % int(poverty))
	if unemployment >= 15.0: reasons.append("失业率 %d%%" % int(unemployment))
	if food_price >= 8.0: reasons.append("粮价 +%d%%" % int((food_price / 5.0 - 1.0) * 100.0))
	if country.legitimacy < 20.0: reasons.append("合法性 %d%%" % int(country.legitimacy))
	if social_stability < 30.0: reasons.append("社会稳定 %d%%" % int(social_stability))
	# 政治危机：双低 → 事件（记录原因，不直接倒台）
	if country.legitimacy < 20.0 and social_stability < 30.0:
		country.revolution_risk = min(100.0, country.revolution_risk + 15.0)
		country.record("第%d年 政治危机：%s" % [_year(), "、".join(reasons) if not reasons.is_empty() else "政府权威下降"])
		_hist("[国家]", "政治危机！原因：" + ("、".join(reasons) if not reasons.is_empty() else "政府权威下降"))
	# 革命风险高 → 改革压力（政府妥协方向，具体结果由后续政策决定）
	if country.revolution_risk >= 80.0:
		country.record("第%d年 革命风险逼近：%s，政府面临改革压力" % [_year(), "、".join(reasons)])
		_hist("[国家]", "革命风险高涨（%d%%），政府被迫改革" % int(country.revolution_risk))
		country.revolution_risk = 40.0   # 改革缓和（真实结果留给决策系统）
		return country.revolution_risk
	# 平稳年：风险自然回落
	country.revolution_risk = maxf(0.0, country.revolution_risk - 2.0)
	return country.revolution_risk

## 面板摘要
func summary(country) -> Dictionary:
	var out: Array = []
	for g in country.political_groups:
		out.append({"name": g.name, "members": g.members, "power": g.power, "demand": g.demand})
	return {"groups": out, "revolution_risk": country.revolution_risk}

func _year() -> int:
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"):
		return eco.season_sys.year
	return 1

func _hist(kind: String, text: String) -> void:
	var civ = world.get("civ") if world else null
	var hist = civ.get("history") if civ else null
	if hist: hist.record("第%d年[%s] %s" % [_year(), kind, text])
