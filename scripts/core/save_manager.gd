extends Node
## 存档管理器：把世界/居民/建筑/文明/生态存为 JSON
## 编辑器下 res:// 即 D:\EdenGenesis，存档落在 D:\EdenGenesis\saves

const SAVE_DIR := "res://saves"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func save_all(world: Node) -> void:
	_save_file("world.json", {
		"save_version": "0.19.7",
		"time": _time_data(world),
	})
	# 0.19.7：独立分文件 + 版本号
	_save_file("time.json", {"time": _time_data(world)})
	_save_file("regions.json", {"regions": _regions_data(world)})
	var hist = world.get("civ").get("history") if world.get("civ") else null
	if hist and hist.has_method("snapshot"):
		_save_file("history.json", {"history": hist.snapshot()})
	_save_file("humans.json", {"humans": _humans_data(world)})
	_save_file("buildings.json", {"buildings": _buildings_data(world)})
	_save_file("civilization.json", _civ_data(world))
	_save_file("ecology.json", _ecology_data(world))
	_save_file("military.json", _military_data(world))
	_save_file("armies.json", _armies_data(world))
	_save_file("wars.json", _wars_data(world))
	_save_file("treaties.json", _treaties_data(world))
	_save_file("war_history.json", _war_history_data(world))
	_save_file("cities.json", {"cities": _cities_data(world)})
	_save_file("districts.json", {"districts": _districts_data(world)})
	# 0.16 社会系统存档
	_save_file("families.json", {"families": _families_data(world)})
	_save_file("social.json", _social_data(world))
	_save_file("education.json", _education_data(world))
	_save_file("health.json", _health_data(world))
	_save_file("culture.json", _culture_data(world))
	print("[Save] 已自动保存世界")
	# 0.17 技术/文化演化存档
	_save_file("knowledge.json", {"knowledge": _knowledge_data(world), "era": _era_data(world)})
	_save_file("skills.json", {"skills": _skills_data(world)})
	_save_file("culture_evo.json", _culture_evo_data(world))
	# 0.18 国家系统存档
	_save_file("countries.json", {"countries": _countries_data(world)})
	_save_file("laws.json", {"laws": _laws_data(world)})
	_save_file("budgets.json", _budgets_data(world))
	_save_file("politics.json", _politics_data(world))
	_save_file("territories.json", {"territories": _territories_data(world)})
	# 0.19 行政/基建/交通存档
	_save_file("administration.json", _administration_data(world))
	_save_file("infrastructure.json", _infrastructure_data(world))
	# 0.20 经济帝国存档（资源池/企业/工厂/贸易/银行）
	_save_file("economy.json", _economy_data(world))

func _countries_data(world: Node) -> Array:
	var out: Array = []
	var cm = world.get("country_mgr") if world else null
	if cm == null: return out
	var country = cm.eden_country() if cm.has_method("eden_country") else null
	if country == null: return out
	out.append({
		"id": country.id, "name": country.name,
		"civilization_id": country.civilization_id,
		"capital_city_id": country.capital_city_id,
		"city_ids": country.city_ids.duplicate(),
		"founded_year": country.founded_year,
		"population": country.population, "income": country.income,
		"expenses": country.expenses, "deficit_months": country.deficit_months,
		"stability": country.stability, "legitimacy": country.legitimacy,
		"government_type": country.government_type,
		"revolution_risk": country.revolution_risk,
		"history": country.history.duplicate(),
	})
	return out

func _laws_data(world: Node) -> Array:
	var out: Array = []
	var cm = world.get("country_mgr") if world else null
	if cm == null: return out
	var country = cm.eden_country() if cm.has_method("eden_country") else null
	if country == null: return out
	for l in country.laws:
		out.append(l.serialize())
	return out

func _budgets_data(world: Node) -> Dictionary:
	var cm = world.get("country_mgr") if world else null
	if cm == null: return {}
	var country = cm.eden_country() if cm.has_method("eden_country") else null
	return cm.budget.summary(country) if country else {}

func _politics_data(world: Node) -> Dictionary:
	var cm = world.get("country_mgr") if world else null
	if cm == null: return {}
	var country = cm.eden_country() if cm.has_method("eden_country") else null
	if country == null: return {}
	return cm.political.summary(country)

func _territories_data(world: Node) -> Array:
	var cm = world.get("country_mgr") if world else null
	if cm == null: return []
	var out: Array = []
	if cm.get("territory") == null: return out
	for rid in cm.territory.cells:
		var cell: Dictionary = cm.territory.cells[rid]
		out.append({"id": rid, "x": cell.x, "z": cell.z, "city_id": cell.city_id, "owner": cell.owner})
	return out

func _administration_data(world: Node) -> Dictionary:
	var am = world.get("admin_mgr") if world else null
	if am == null: return {}
	var out: Dictionary = {"provinces": [], "districts": []}
	for p in am.provinces:
		out["provinces"].append(p.serialize())
	for city_id in am.admin_districts:
		out["districts"].append(am.admin_districts[city_id].serialize())
	return out

func _infrastructure_data(world: Node) -> Dictionary:
	var im = world.get("infra_mgr") if world else null
	if im == null: return {}
	var out: Dictionary = {"roads": [], "railways": [], "ports": [], "bridges": []}
	for r in im.road_sys.roads:
		out["roads"].append({"from": r.from_city, "to": r.to_city, "length": r.length,
			"level": r.level, "type": r.type_name, "quality": r.quality, "year": r.built_year})
	for r in im.railway.railways:
		out["railways"].append({"from": r.from_city, "to": r.to_city, "length": r.length, "year": r.built_year})
	for p in im.port_sys.ports:
		out["ports"].append({"city": p.city_id, "capacity": p.capacity, "year": p.built_year})
	for br in im.bridge.bridges:
		out["bridges"].append({"a": br.city_a, "b": br.city_b, "length": br.length, "year": br.built_year})
	return out

func _families_data(world: Node) -> Array:
	var out: Array = []
	var society = world.get("society")
	if society == null: return out
	for fam in society.families:
		out.append({
			"id": fam.family_id,
			"father": fam.father.npc_name if fam.father else "",
			"mother": fam.mother.npc_name if fam.mother else "",
			"children": (func() -> Array:
				var names: Array = []
				for c in fam.children:
					names.append(c.npc_name if c.get("npc_name") != null else "孩子")
				return names).call(),
			"home_id": fam.home_id,
			"city_id": fam.city_id,
			"family_money": fam.family_money,
		})
	return out

func _social_data(world: Node) -> Dictionary:
	var sim = world.get("social_sim")
	if sim == null: return {}
	var society = world.get("society")
	var out: Dictionary = {"stability": sim.social_stability}
	if society:
		var residents: Array = society.population.residents
		var diss: float = 0.0
		for n in residents:
			diss += n.political_dissatisfaction
		out["avg_dissatisfaction"] = (diss / residents.size()) if not residents.is_empty() else 0.0
		out["relations"] = _relations_sample(society.population.residents)
	return out

func _relations_sample(residents: Array) -> Array:
	var out: Array = []
	for n in residents:
		if n.get("relationship") == null: continue
		var rel: Dictionary = n.relationship.relations
		if rel.is_empty(): continue
		out.append({"who": n.npc_name, "relations": rel})
	return out

func _education_data(world: Node) -> Array:
	var out: Array = []
	var society = world.get("society")
	if society == null: return out
	for n in society.population.residents:
		out.append({"name": n.npc_name, "education": n.education, "school_years": n.school_years})
	return out

func _health_data(world: Node) -> Array:
	var out: Array = []
	var society = world.get("society")
	if society == null: return out
	for n in society.population.residents:
		out.append({"name": n.npc_name, "health": n.health, "sickness": n.sickness})
	return out

func _culture_data(world: Node) -> Dictionary:
	var c = world.get("civ")
	if c == null: return {}
	var culture = c.get("culture")
	if culture == null: return {}
	return {
		"values": culture.values,
		"traditions": culture.traditions,
		"festivals": culture.festivals,
	}

func _cities_data(world: Node) -> Array:
	var out: Array = []
	var cm = world.get("city_mgr")
	if cm == null: return out
	for city in cm.cities.values():
		out.append(city.serialize())
	return out

func _districts_data(world: Node) -> Array:
	var out: Array = []
	var dm = world.get("district_mgr")
	if dm == null: return out
	for d in dm.districts.values():
		out.append({
			"id": d.id, "city_id": d.city_id, "type": d.district_type,
			"x": d.center.x, "z": d.center.z, "radius": d.radius,
		})
	return out

func _military_data(world: Node) -> Dictionary:
	var gov = world.get("civ").get("government") if world and world.get("civ") else null
	if gov == null: return {}
	return {
		"soldiers": gov.get("soldiers") if gov.get("soldiers") != null else 0,
		"military_power": gov.get("military_power") if gov.get("military_power") != null else 5.0,
		"military_budget": gov.get("military_budget") if gov.get("military_budget") != null else 0.0,
	}

func _armies_data(world: Node) -> Array:
	var out: Array = []
	var am = world.get("army_mgr")
	if am == null: return out
	for army in am.armies.values():
		out.append({
			"civ": army.civilization_id,
			"soldiers": army.soldiers,
			"morale": army.morale,
			"food_supply": army.food_supply,
			"equipment": army.equipment,
			"active": army.active,
		})
	return out

func _wars_data(world: Node) -> Array:
	var out: Array = []
	var wm = world.get("war_mgr")
	if wm == null: return out
	for w in wm.wars:
		out.append({
			"attacker": w.attacker, "defender": w.defender,
			"start_year": w.start_year, "active": w.active,
			"goal": w.goal_type,
			"a_cas": w.attacker_casualties, "d_cas": w.defender_casualties,
			"exhaustion": w.war_exhaustion,
		})
	return out

func _treaties_data(world: Node) -> Array:
	var out: Array = []
	var wm = world.get("war_mgr")
	if wm == null: return out
	for t in wm.peace_treaties:
		out.append({"a": t.civilization_a, "b": t.civilization_b, "year": t.year_signed, "duration": t.duration, "active": t.active})
	return out

func _war_history_data(world: Node) -> Array:
	var out: Array = []
	var wm = world.get("war_mgr")
	if wm == null: return out
	for ev in wm.war_history:
		out.append({"year": ev.year, "title": ev.title, "desc": ev.description, "casualties": ev.casualties})
	return out

func _time_data(world: Node) -> Dictionary:
	## 0.19.7：时间统一从 WorldTime（唯一权威）读取
	var clock = get_node_or_null("/root/Main/WorldTime")
	if clock and clock.has_method("snapshot"):
		return clock.snapshot()
	var eco = world.get("ecosystem")
	var d := {"hour": 8.0, "day": 1, "month": 1, "year": 1}
	if eco and eco.get("season_sys"):
		d["day"] = eco.season_sys.day
		d["year"] = eco.season_sys.year
	return d

func _humans_data(world: Node) -> Array:
	var out: Array = []
	var society = world.get("society")
	if society == null: return out
	for npc in society.population.residents:
		var p = npc.get("person")
		if p:
			out.append(p.to_dict())
		else:
			out.append({"name": npc.npc_name, "age": npc.age, "job": npc.job})
	return out

func _buildings_data(world: Node) -> Array:
	var out: Array = []
	var st = world.get("settlement")
	if st == null: return out
	for b in st.buildings:
		if typeof(b) == TYPE_DICTIONARY:
			var pos: Vector3 = b.get("pos", Vector3.ZERO)
			out.append({"type": b.get("type","house"), "x": pos.x, "z": pos.z, "health": b.get("health",100.0)})
	return out

func _civ_data(world: Node) -> Dictionary:
	var c = world.get("civ")
	if c == null or c.get("civilization") == null: return {}
	return {
		"name": c.settlement.settlement_name,
		"population": c.civilization.population,
		"age": c.civilization.age,
		"tech": c.tech.technologies,
		"culture": c.culture.values,
		"resources": c.resource.resources,
	}

func _ecology_data(world: Node) -> Dictionary:
	var eco = world.get("ecosystem")
	if eco == null: return {}
	return {
		"forest": eco.forest_coverage,
		"animals": eco.animal_stability,
		"water": eco.water_status,
		"pollution": eco.pollution,
		"weather": eco.weather_sys.weather if eco.get("weather_sys") else "晴",
	}

## 0.19.7 SaveValidator：存档一致性检查（重复 ID / 断裂引用）
func validate_world(world: Node) -> Array:
	var issues: Array = []
	var registry = world.get_node_or_null("EntityRegistry")
	var society = world.get("society")
	if society == null or society.get("population") == null: return issues
	# Human 重复 ID
	var seen: Dictionary = {}
	for n in society.population.residents:
		if not is_instance_valid(n): continue
		var hid: String = str(n.get("id") if n.get("id") != null else "")
		if hid == "": continue
		if seen.has(hid):
			issues.append("重复 Human ID: " + hid)
		else:
			seen[hid] = true
	# home 引用存在
	var house_mgr = world.get("settlement") if world else null
	for n in society.population.residents:
		if not is_instance_valid(n): continue
		var home_ref = n.get("home") if n.get("home") != null else null
		if home_ref == null: continue
		var home_node = home_ref if home_ref is Node else null
		if home_node == null and house_mgr != null and house_mgr.has_method("get_house"):
			home_node = house_mgr.get_house(str(home_ref))
		if home_node == null:
			issues.append("断裂引用: %s 的 home 不存在" % str(n.get("npc_name")))
	# City 引用
	var city_mgr = world.get("city_mgr")
	for n in society.population.residents:
		if not is_instance_valid(n): continue
		var cid = n.get("city_id") if n.get("city_id") != null else ""
		if cid != "" and city_mgr:
			if city_mgr.get_city(cid) == null:
				issues.append("断裂引用: %s 的 city_id 不存在" % str(n.get("npc_name")))
	return issues

func _save_file(fname: String, data: Variant) -> void:
	var f := FileAccess.open(SAVE_DIR + "/" + fname, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()

func _economy_data(world: Node) -> Dictionary:
	var out: Dictionary = {}
	var resource_mgr = world.get("resource_mgr")
	if resource_mgr and resource_mgr.get("pool") != null:
		out["resources"] = resource_mgr.pool.duplicate()
	var company_mgr = world.get("company_mgr")
	if company_mgr and company_mgr.has_method("serialize"):
		out["companies"] = company_mgr.serialize()
	var prod_mgr = world.get("production_mgr")
	if prod_mgr and prod_mgr.has_method("serialize"):
		out["factories"] = prod_mgr.serialize()
	var trade_mgr = world.get("trade_mgr")
	if trade_mgr and trade_mgr.has_method("serialize"):
		out["trade"] = trade_mgr.serialize()
	var finance_mgr = world.get("finance_mgr")
	if finance_mgr and finance_mgr.has_method("serialize"):
		out["bank"] = finance_mgr.serialize()
	return out

func _regions_data(world: Node) -> Array:
	var out: Array = []
	var stream = world.get_node_or_null("Streaming") if world else null
	if stream and stream.get("regions") != null:
		for id in stream.regions:
			var r = stream.regions[id]
			out.append({
				"id": r.id, "name": r.name,
				"state": r.state, "active": r.active, "loaded": r.loaded,
				"center": [r.center.x, r.center.y, r.center.z],
			})
	return out

func _knowledge_data(world: Node) -> Dictionary:
	var out: Dictionary = {}
	var tech_mgr = world.get("tech_mgr")
	if tech_mgr:
		out["knowledge"] = tech_mgr.knowledge.knowledge.duplicate()
		out["inventions"] = tech_mgr.invention.inventions.map(func(ev): return ev.serialize())
	return out

func _era_data(world: Node) -> String:
	var tech_mgr = world.get("tech_mgr")
	return tech_mgr.current_era if tech_mgr else "原始时代"

func _skills_data(world: Node) -> Array:
	var out: Array = []
	var society = world.get("society")
	if society:
		for n in society.population.residents:
			out.append({"name": n.npc_name, "skills": n.skills, "exp": n.skill_exp})
	return out

func _culture_evo_data(world: Node) -> Dictionary:
	var civ = world.get("civ")
	var out: Dictionary = {"culture": {}}
	if civ and civ.get("culture"):
		var c = civ.culture
		out["culture"] = {
			"values": c.values, "traditions": c.traditions,
			"festivals": c.festivals, "language": c.language,
			"beliefs": c.beliefs,
		}
	return out
# ---------- 读档（0.19.1）：重启后世界与退出前一致 ----------
## 恢复核心可见状态：时间/季节、人口（按存档名单重建居民）、住宅、资源、科技、
## 时代与知识池、城市等级、生态覆盖。家庭/关系/国家/基建等深层系统后续逐步补读。
func load_core(world: Node) -> bool:
	if not FileAccess.file_exists(SAVE_DIR + "/world.json"):
		return false
	var wd: Dictionary = _read_json(SAVE_DIR + "/world.json")
	var cd: Dictionary = _read_json(SAVE_DIR + "/civilization.json")
	var hd: Dictionary = _read_json(SAVE_DIR + "/humans.json")
	var kd: Dictionary = _read_json(SAVE_DIR + "/knowledge.json")
	var ed: Dictionary = _read_json(SAVE_DIR + "/ecology.json")
	var ctd: Dictionary = _read_json(SAVE_DIR + "/cities.json")
	# 1) 时间（0.19.7 统一）：优先 time.json，回退旧档 world.json time；恢复 WorldTime 后季节镜像自动跟随
	var eco = world.get("ecosystem")
	var clock = get_node_or_null("/root/Main/WorldTime")
	var tdata: Dictionary = {}
	var td: Dictionary = _read_json(SAVE_DIR + "/time.json")
	if td.has("time") and td["time"] is Dictionary:
		tdata = td["time"]
	elif wd.has("time") and wd["time"] is Dictionary:
		tdata = wd["time"]
	if clock and clock.has_method("restore"):
		clock.restore(tdata)
		# 旧档只有 season 时映射回 month（春1 夏2 秋3 冬4）
		if not tdata.has("month") and tdata.has("season") and clock:
			var s: String = str(tdata["season"])
			match s:
				"夏": clock.month = 2
				"秋": clock.month = 3
				"冬": clock.month = 4
				_: clock.month = 1
			clock._last_month = clock.month
	if eco and eco.get("season_sys") and eco.season_sys.has_method("sync_from_clock"):
		eco.season_sys.sync_from_clock()
	# 2) 文明：资源 / 科技 / 聚落名
	var c = world.get("civ")
	if c:
		if cd.has("resources") and c.get("resource"):
			for k in cd["resources"]:
				c.resource.resources[k] = cd["resources"][k]
		if cd.has("tech") and c.get("tech"):
			for t in cd["tech"]:
				if not c.tech.has(t):
					c.tech.research(t)
		if cd.has("settlement_name") and c.get("settlement"):
			c.settlement.settlement_name = cd["settlement_name"]
	# 3) 时代与知识池（era_visual_done 同步，避免重复建时代建筑）
	var tm = world.get("tech_mgr")
	if tm:
		# 知识数值随月度结算重新积累（旧档知识结构已污染，跳过数值恢复）
		if kd.has("era"):
			tm.current_era = kd["era"]
			tm.era_visual_done = kd["era"]
	# 4) 人口重建：清默认居民，按存档名单生成
	var society = world.get("society")
	var st = world.get("settlement")
	if society and st and hd.has("humans") and hd["humans"].size() > 0:
		for npc in society.population.residents.duplicate():
			if is_instance_valid(npc):
				npc.queue_free()
		society.population.residents.clear()
		society.families.clear()
		var i: int = 0
		for h in hd["humans"]:
			var nm: String = h.get("name", "居民%d" % i)
			var ag: int = int(h.get("age", 20))
			var jb: String = h.get("job", "农民")
			var home: Vector3 = st.get_home_for(i)
			var work: Vector3 = st.get_work_for(jb)
			var food: Vector3 = st.get_food_position()
			world._spawn_one(nm, ag, jb, home, work, food)
			st.bind_owner(i, nm)
			i += 1
		st.ensure_housing(society.population.count())
		# 4.5) 家庭恢复：从 families.json 按名重建（父/母/孩子）
		var fmd: Dictionary = _read_json(SAVE_DIR + "/families.json")
		if fmd.has("families"):
			for fam_d in fmd["families"]:
				if not fam_d.has("father") or not fam_d.has("mother"): continue
				var f_npc = _find_npc(society, fam_d["father"])
				var m_npc = _find_npc(society, fam_d["mother"])
				if f_npc == null or m_npc == null: continue
				society.register_family(f_npc, m_npc)
				var fam = f_npc.family
				if fam and fam.has_method("add_kid"):
					for cname in fam_d.get("children", []):
						var kid = _find_npc(society, cname)
						if kid:
							fam.add_kid(kid)
							kid.family = fam
		if c: c.set_population(society.population.count())
	# 5) 生态覆盖
	if eco:
		if ed.has("forest"): eco.forest_coverage = ed["forest"]
		if ed.has("animals"): eco.animal_stability = ed["animals"]
		if ed.has("pollution"): eco.pollution = ed["pollution"]
		if ed.has("weather") and eco.get("weather_sys"):
			eco.weather_sys.weather = ed["weather"]
	# 6) 城市等级（状态字段；人口/住房等统计值由 _stats 按真实居民/建筑实时重算）
	var city_mgr = world.get("city_mgr")
	if city_mgr and ctd.has("cities") and not ctd["cities"].is_empty():
		var city = city_mgr.eden_city() if city_mgr.has_method("eden_city") else null
		if city:
			var cd0: Dictionary = ctd["cities"][0]
			if cd0.has("level"): city.level = cd0["level"]
			if city_mgr.has_method("_stats"):
				city_mgr._stats(world, city)
	# 7) 0.20 经济帝国恢复（资源池/企业/工厂/贸易/银行；region 地图与基准价保留 setup 默认）
	var ed20: Dictionary = _read_json(SAVE_DIR + "/economy.json")
	var resource_mgr = world.get("resource_mgr")
	if resource_mgr and ed20.has("resources") and ed20["resources"] is Dictionary:
		resource_mgr.pool = ed20["resources"]
	var company_mgr = world.get("company_mgr")
	if company_mgr and ed20.has("companies") and company_mgr.has_method("restore"):
		company_mgr.restore(ed20["companies"])
	var prod_mgr = world.get("production_mgr")
	if prod_mgr and ed20.has("factories") and prod_mgr.has_method("restore"):
		prod_mgr.restore(ed20["factories"])
	var trade_mgr = world.get("trade_mgr")
	if trade_mgr and ed20.has("trade") and trade_mgr.has_method("restore"):
		trade_mgr.restore(ed20["trade"])
	var finance_mgr = world.get("finance_mgr")
	if finance_mgr and ed20.has("bank") and finance_mgr.has_method("restore"):
		finance_mgr.restore(ed20["bank"])
	# 居民 company_id 与工厂工人：按公司员工名单重新绑定
	if company_mgr and society:
		for n in society.population.residents:
			if not is_instance_valid(n): continue
			for cid in company_mgr.companies:
				var comp: Dictionary = company_mgr.companies[cid]
				if str(n.get("npc_name")) in comp["employees"]:
					n.company_id = cid
					break
	if prod_mgr and company_mgr:
		for cid in company_mgr.companies:
			var comp: Dictionary = company_mgr.companies[cid]
			for fid in comp["factories"]:
				if prod_mgr.factories.has(fid):
					prod_mgr.factories[fid]["workers"] = comp["employees"].duplicate()
	print("[Save] 已从存档恢复：人口%d 住宅%d 第%d年%s" % [
		society.population.count() if society else 0,
		st.capacity() if st else 0,
		eco.season_sys.year if eco and eco.get("season_sys") else 1,
		eco.season_sys.season if eco and eco.get("season_sys") else ""])
	return true

func _read_json(fname: String) -> Variant:
	if not FileAccess.file_exists(fname): return {}
	var f = FileAccess.open(fname, FileAccess.READ)
	if f == null: return {}
	var txt: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed != null else {}
func _find_npc(society, nm: String):
	for n in society.population.residents:
		if n.get("npc_name") == nm: return n
	return null