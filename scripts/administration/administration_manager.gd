extends Node
class_name AdministrationManager
## 0.19 行政总管：国家 → 省 → 区 → 城市 分层治理。
## 省长/区长来自真实居民（0.16 Human 系统）；行政能力真实计算
## （政府能力+道路+教育+官员能力-距离）；偏远地区腐败损耗税收（记录，不重复扣款）。

const ProvinceScript: Script = preload("res://scripts/administration/province.gd")
const DistrictScript: Script = preload("res://scripts/administration/district.gd")

var world: Node = null
var provinces: Array = []      # Province
var admin_districts: Dictionary = {}   # city_id -> AdminDistrict

func bind(w: Node) -> void:
	world = w

func eden_country():
	var cm = world.get("country_mgr") if world else null
	return cm.eden_country() if cm else null

# ---------------- 建省（按地理真实分省） ----------------
func ensure_provinces(country) -> void:
	if not provinces.is_empty(): return
	var city_mgr = world.get("city_mgr")
	if city_mgr == null: return
	var capital: Vector3 = Vector3.ZERO
	var capital_city = city_mgr.get_city(country.capital_city_id) if country.capital_city_id != "" else null
	if capital_city: capital = capital_city.center
	# 按 x 相对首都分省：北方省（x<0）/ 中央省（x≈0）/ 南方省（x>0）
	var groups: Dictionary = {"north": [], "central": [], "south": []}
	for city_id in country.city_ids:
		var city = city_mgr.get_city(city_id)
		if city == null: continue
		var dx: float = city.center.x - capital.x
		if dx < -15.0:
			groups["north"].append(city_id)
		elif dx > 15.0:
			groups["south"].append(city_id)
		else:
			groups["central"].append(city_id)
	# 每省至少 1 城，空组吸收相邻组（防单城国家建省失败）
	if groups["north"].is_empty() and not groups["central"].is_empty():
		groups["north"].append(groups["central"].pop_back())
	if groups["south"].is_empty() and not groups["central"].is_empty():
		groups["south"].append(groups["central"].pop_back())
	var specs: Array = [
		{"key": "north", "name": "北方省", "id": "prov_north"},
		{"key": "central", "name": "中央省", "id": "prov_central"},
		{"key": "south", "name": "南方省", "id": "prov_south"},
	]
	for s in specs:
		var ids: Array = groups[s["key"]]
		if ids.is_empty(): continue
		var p = ProvinceScript.new(s["id"], s["name"], country.id)
		p.city_ids = ids
		_assign_governor(p, ids)
		provinces.append(p)
		# 每城建区
		for city_id in ids:
			var d = DistrictScript.new("dist_" + city_id, city_id, p.id, city_id)
			admin_districts[city_id] = d
		country.record("第%d年 行政建制：设立%s（%d 座城市）" % [_year(), s["name"], ids.size()])
	_hist("[行政]", "Eden 设立省级行政区（%d 个省）" % provinces.size())

func _assign_governor(province, city_ids: Array) -> void:
	var society = world.get("society") if world else null
	if society == null: return
	var residents: Array = society.population.residents
	var best: Node = null
	for r in residents:
		if r.get("age") == null or r.age < 30: continue
		if best == null or _governor_score(r) > _governor_score(best):
			best = r
	if best:
		province.governor_id = best.npc_name

func _governor_score(r) -> float:
	var s: float = float(r.age) * 0.4
	if r.get("education") != null: s += r.education * 0.5
	var rel = r.get("relationship")
	if rel and rel.relations: s += rel.relations.size() * 2.0
	var nd = r.get("needs")
	if nd: s += nd.happiness * 0.1
	return s

# ---------------- 月度：行政能力 + 腐败 + 省税收统计 ----------------
func monthly_tick() -> void:
	var country = eden_country()
	if country == null: return
	if provinces.is_empty(): ensure_provinces(country)
	var civ = world.get("civ")
	var gov = civ.get("government") if civ else null
	var city_mgr = world.get("city_mgr")
	var infra_mgr = world.get("infra_mgr") if world else null
	var capital_city = city_mgr.get_city(country.capital_city_id) if city_mgr and country.capital_city_id != "" else null
	var capital_pos: Vector3 = capital_city.center if capital_city else Vector3.ZERO
	# 国家本月收入（省税收统计口径：分摊）
	var nation_income: float = country.income
	var total_pop: int = maxi(1, country.population)
	for p in provinces:
		# 省人口 = 城市人口聚合
		var pop: int = 0
		var infra_sum: float = 0.0
		for city_id in p.city_ids:
			var city = city_mgr.get_city(city_id) if city_mgr else null
			if city == null: continue
			pop += city.population
			infra_sum += city.infrastructure
		p.population = pop
		p.infrastructure_level = infra_sum / maxi(1, p.city_ids.size())
		# 行政能力 = 政府能力 + 道路 + 教育 + 官员 - 距离
		var admin: float = 30.0
		if gov: admin += gov.administrative_capacity if gov.get("administrative_capacity") != null else 20.0
		var edu_sys = world.get("education_sys")
		var society = world.get("society")
		var residents: Array = society.population.residents if society else []
		if edu_sys and not residents.is_empty(): admin += edu_sys.education_rate(residents) * 0.2
		if infra_mgr and infra_mgr.has_method("province_road_bonus"):
			admin += infra_mgr.province_road_bonus(p)
		if p.governor_id != "":
			for r in residents:
				if r.npc_name == p.governor_id:
					admin += _governor_score(r) * 0.3
					break
		# 距离惩罚：距首都越远行政效率越低
		var dist: float = 0.0
		for city_id in p.city_ids:
			var city = city_mgr.get_city(city_id) if city_mgr else null
			if city: dist = maxf(dist, city.center.distance_to(capital_pos))
		admin -= dist * 0.005
		p.admin_capacity = clampf(admin, 5.0, 100.0)
		# 腐败率：偏远 + 低能力
		p.corruption = clampf((100.0 - p.admin_capacity) * 0.01 + dist * 0.0002, 0.0, 0.6)
		# 省税收（统计口径：国家收入按省人口占比 × 行政效率）
		var share: float = float(pop) / float(total_pop)
		p.tax_income = nation_income * share * (1.0 - p.corruption)
		# 区级行政
		for city_id in p.city_ids:
			var d = admin_districts.get(city_id)
			if d == null: continue
			var city = city_mgr.get_city(city_id)
			d.distance_to_capital = city.center.distance_to(capital_pos) if city else 0.0
			d.admin_capacity = clampf(p.admin_capacity * 0.9, 5.0, 100.0)
			d.corruption = p.corruption

# ---------------- 面板 ----------------
func panel_data(country) -> Dictionary:
	var out: Array = []
	for p in provinces:
		out.append({
			"name": p.name, "governor": p.governor_id, "population": p.population,
			"cities": p.city_ids.size(), "admin": int(p.admin_capacity),
			"corruption": int(p.corruption * 100.0), "tax": int(p.tax_income),
			"infra": int(p.infrastructure_level), "development": int(p.development),
		})
	return {"provinces": out, "count": provinces.size()}

func _hist(kind: String, text: String) -> void:
	var civ = world.get("civ") if world else null
	var hist = civ.get("history") if civ else null
	if hist: hist.record("第%d年[%s] %s" % [_year(), kind, text])

func _year() -> int:
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"):
		return eco.season_sys.year
	return 1
