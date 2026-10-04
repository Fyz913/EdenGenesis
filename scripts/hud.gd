extends CanvasLayer

@onready var time_label: Label = %TimeLabel
@onready var civ_label: Label = %CivLabel
@onready var side_panel: RichTextLabel = %SidePanelRT
@onready var hint_label: Label = %HintLabel
var _panel_open: bool = false
var _panel_refresh: float = 0.0

func _ready() -> void:
	# 文明管理面板默认隐藏，按 Tab 打开
	var panel = side_panel.get_parent()
	if panel: panel.visible = false
	if hint_label: hint_label.text = "[Tab] 文明面板"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_panel_open = not _panel_open
		var panel = side_panel.get_parent()
		if panel: panel.visible = _panel_open
		if hint_label: hint_label.visible = not _panel_open
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var clock = get_node_or_null("/root/Main/WorldTime")
	var world = get_node_or_null("/root/Main/World")
	if clock:
		time_label.text = clock.get_time_string()
		if clock.get("time_scale") != null and clock.time_scale > 1.0:
			time_label.text += "  ⏩x%d" % int(clock.time_scale)
	if world == null: return
	var c = world.get("civ")
	if c == null: return
	if c.get("civilization") == null or c.get("settlement") == null: return
	if side_panel == null: return
	# 顶部精简玩家 HUD：聚落 / 人口 / 季节年 / 天气
	var eco = world.get("ecosystem")
	var season_txt: String = ""
	var weather_txt: String = ""
	if eco and eco.get("season_sys"):
		season_txt = " | " + eco.season_sys.season + "季 第" + str(eco.season_sys.year) + "年"
	if eco and eco.get("weather_sys"):
		weather_txt = " | " + eco.weather_sys.weather
	civ_label.text = "%s | 人口:%d%s%s" % [
		c.settlement.settlement_name, c.civilization.population, season_txt, weather_txt
	]
	if _panel_open:
		_panel_refresh += _delta
		if _panel_refresh >= 1.0:
			_panel_refresh = 0.0
			var _ui_t0: int = Time.get_ticks_usec()
			_refresh_panel(c, world)
			var _sched_ui = world.get_node_or_null("Scheduler")
			if _sched_ui and _sched_ui.has_method("note_ui_ms"):
				_sched_ui.note_ui_ms(float(Time.get_ticks_usec() - _ui_t0) / 1000.0)

func _refresh_panel(c, world) -> void:
	var tech_list: Array = c.tech.technologies
	var culture_list: Array = c.culture.values
	var res: Dictionary = c.resource.resources
	var hist: Array = c.history.events
	var lines: Array = []
	lines.append("[b]Eden 文明[/b]")
	lines.append("")
	lines.append("聚落: " + c.settlement.settlement_name + " Lv" + str(c.settlement.level))
	lines.append("政体: " + c.government.type)
	lines.append("人口: " + str(c.civilization.population))
	lines.append("时代: 石器时代")
	# 民生指标
	lines.append("")
	lines.append("[b]民生[/b]")
	lines.append("  " + _livelihood(c, world))
	# 经济
	var em = world.get("economy")
	if em:
		lines.append("")
		lines.append("[b]经济[/b]")
		var residents: Array = world.society.population.residents
		var mk = em.market
		lines.append("  货币总量: %d" % int(em.money_supply(residents)))
		lines.append("  市场现金: %d" % int(mk.cash))
		lines.append("  市场: " + mk.status_text())
		lines.append("  就业: %d%%" % int(em.employment_rate(residents)))
		lines.append("  库存/单价:")
		for item in ["food", "wood", "stone", "iron", "cloth"]:
			lines.append("    %s: %d  @%d" % [item, int(mk.stock.get(item, 0.0)), int(mk.prices.get(item, 0.0))])
		var ws: Dictionary = em.wealth_stats(residents)
		var cc: Dictionary = ws["counts"]
		lines.append("  阶层: 贫%d 普%d 富%d 豪%d" % [cc["贫困"], cc["普通"], cc["富裕"], cc["富裕阶层"]])
		lines.append("  财富 均%d/中%d/低%d/高%d" % [int(ws["avg"]), int(ws["median"]), int(ws["min"]), int(ws["max"])])
	lines.append("")
	# 0.20 全球经济（GDP/企业/工厂/贸易/银行/城市经济，全部来自真实系统）
	var econ_sim = world.get("econ_sim")
	if econ_sim and econ_sim.has_method("stats"):
		var em0 = world.get("economy")
		var mk0 = em0.market if em0 and em0.get("market") != null else null
		var res0: Array = world.society.population.residents if world.get("society") else []
		var st: Dictionary = econ_sim.stats(world, world.get("city_mgr"), mk0, res0)
		lines.append("[b]全球经济[/b]")
		lines.append("  GDP: %d / 月" % int(st["gdp"]))
		lines.append("  企业: %d  员工: %d  工厂: %d" % [st["companies"], st["employees"], st["factories"]])
		lines.append("  工业: %d%%  农业: %d%%" % [int(st["industry"]), int(st["agriculture"])])
		lines.append("  贸易: %d 件(路线%d)  钱庄: %d 贷款%d" % [int(st["trade_volume"]), st["routes"], int(st["bank_cash"]), st["loans"]])
		var ce: Dictionary = st["city"]
		if not ce.is_empty():
			lines.append("  城市 GDP:%d 就业:%d 均薪:%d 粮供:%d%%" % [int(ce.get("gdp", 0)), int(ce.get("jobs", 0)), int(ce.get("avg_salary", 0)), int(ce.get("food_supply", 0))])
		var cmgr = world.get("company_mgr")
		if cmgr and cmgr.has_method("top_companies"):
			var tops: Array = cmgr.top_companies(4)
			if tops.size() > 0:
				lines.append("  企业榜:")
				for c0 in tops:
					lines.append("    " + str(c0["name"]) + " 员" + str(c0["employees"]) + " 资" + str(int(c0["money"])))
		lines.append("")
	lines.append("[b]科技[/b]")
	for t in tech_list: lines.append("  • " + t)
	lines.append("")
	lines.append("[b]文化[/b]")
	for v in culture_list: lines.append("  • " + v)
	lines.append("")
	lines.append("[b]资源[/b]")
	for k in res.keys():
		lines.append("  " + k + ": " + str(int(res[k])))
	lines.append("")
	# 多文明外交
	var mc = world.get("multiciv")
	if mc:
		lines.append("")
		lines.append("[b]世界文明[/b]")
		for civ_unit in mc.civs:
			lines.append("  " + civ_unit.civ_name + ": 人口" + str(civ_unit.population) + " Lv" + str(civ_unit.technology_level))
		lines.append("")
		lines.append("[b]外交[/b]")
		for other in mc.civs:
			if other.civ_name == "Eden": continue
			lines.append("  对" + other.civ_name + ": " + mc.relation_label("Eden", other.civ_name))
	lines.append("")
	# 政治（0.13）
	var gov = c.get("government")
	if gov:
		lines.append("[b]政治[/b]")
		lines.append("  制度: " + gov.type)
		var pol = world.get("politics")
		var sup: float = pol.support_rate if pol else 50.0
		lines.append("  领袖: " + (gov.leader_id if gov.leader_id != "" else "未定") + "（支持 " + str(int(sup)) + "%）")
		lines.append("  议事会: " + str(gov.council_members.size()) + " 人")
		lines.append("  财政: " + str(int(gov.treasury)) + "  税率: " + str(int(gov.tax_rate * 100)) + "%")
		lines.append("  军力: " + str(int(gov.military_power)) + "  士兵: " + str(gov.soldiers))
		var pl2: Array = []
		if pol and pol.policy:
			pl2 = pol.policy.summary()
		lines.append("  政策: " + ("、".join(pl2) if not pl2.is_empty() else "无"))
	# 外交（0.13）
	var dpl = world.get("diplomacy")
	if dpl:
		lines.append("")
		lines.append("[b]外交[/b]")
		for other in ["北境部落", "沙漠城邦"]:
			lines.append("  " + other + ": " + dpl.relation_label("Eden", other) + " (%d)" % int(dpl.relation_value("Eden", other)))
		lines.append("  条约: " + str(dpl.treaties.size()) + "  贸易线: " + str(dpl.trade_routes.size()))
	# 组织（0.13）
	var org_mgr = world.get("org_mgr")
	if org_mgr:
		lines.append("")
		lines.append("[b]组织[/b]")
		for oid in org_mgr.organizations:
			var o = org_mgr.organizations[oid]
			lines.append("  " + o.org_name + ": " + str(o.member_count()) + "人")
	# 军事（0.14）
	var am = world.get("army_mgr")
	if am:
		lines.append("")
		lines.append("[b]军事[/b]")
		for army in am.armies.values():
			var war_txt: String = "⚔ 战争中" if army.active else ""
			lines.append("  %s军：%d兵  士气%d%%  军粮%d %s" % [
				army.civilization_id, army.soldiers, int(army.morale), int(army.food_supply), war_txt])
	# 战争（0.14）
	var wm = world.get("war_mgr")
	if wm:
		for w in wm.wars:
			if not w.active: continue
			lines.append("")
			lines.append("[b]⚠ 战争状态[/b]")
			lines.append("  %s  VS  %s" % [w.attacker, w.defender])
			lines.append("  目标: " + w.goal_type)
			lines.append("  战争疲劳: " + str(int(w.war_exhaustion)) + "%")
			lines.append("  伤亡: %s%d / %s%d" % [w.attacker, w.attacker_casualties, w.defender, w.defender_casualties])
	# 生态
	var eco = world.get("ecosystem")
	if eco:
		lines.append("[b]Eden 生态[/b]")
		lines.append("  " + eco.get_ecology_text().replace("\n", "\n  "))
	# 城市（0.15）
	var city_mgr = world.get("city_mgr")
	if city_mgr and not city_mgr.cities.is_empty():
		var city = city_mgr.eden_city()
		if city:
			lines.append("")
			lines.append("[b]城市[/b]")
			lines.append("  %s · %s Lv.%d" % [city.city_name, city.level_name(), city.level])
			lines.append("  人口: %d" % city.population)
			lines.append("  住房: %d / %d" % [city.house_count, city.housing_capacity])
			lines.append("  就业: %d / %d  失业: %d" % [city.employment_capacity, maxi(city.population, city.employment_capacity), city.unemployed])
			lines.append("  幸福: %d%%  繁荣: %d%%  基建: %d%%" % [int(city.happiness), int(city.prosperity), int(city.infrastructure)])
			lines.append("  食物: %d" % int(city.food_supply))
			lines.append("  商业: %d  工业: %d  公共建筑: %d" % [city.commercial_buildings, city.industrial_buildings, city.public_buildings])
			var dm = world.get("district_mgr")
			if dm and dm.has_method("get_districts_for_city"):
				var d_list: Array = dm.get_districts_for_city(city.id)
				lines.append("  城区: %d" % d_list.size())
				for d in d_list:
					lines.append("    " + d.type_name())
			lines.append("  城市状态: 迁入+%d 迁出-%d 压力%d%%" % [city.migration_in, city.migration_out, int(city.migration_pressure)])
			# 社会（0.16）
			var sim = world.get("social_sim")
			var residents_all: Array = world.society.population.residents
			if sim:
				var fam_count: int = world.society.families.size()
				var ws2: Dictionary = em.wealth_stats(residents_all) if em else {"counts": {}}
				var cc2: Dictionary = ws2["counts"]
				var pop2: int = maxi(1, residents_all.size())
				var crime_sys = world.get("crime_sys")
				var edu_sys = world.get("education_sys")
				var health_sys = world.get("health_sys")
				var crime_rate: float = crime_sys.calculate_city_crime(city, residents_all) if crime_sys else 0.0
				var edu_rate: float = edu_sys.education_rate(residents_all) if edu_sys else 0.0
				var sick_rate: float = health_sys.sick_rate(residents_all) if health_sys else 0.0
				lines.append("")
				lines.append("[b]社会[/b]")
				lines.append("  家庭: %d" % fam_count)
				lines.append("  阶层: 贫%d%% 普%d%% 富%d%% 豪%d%%" % [
					int(cc2.get("贫困", 0) * 100.0 / pop2),
					int(cc2.get("普通", 0) * 100.0 / pop2),
					int(cc2.get("富裕", 0) * 100.0 / pop2),
					int(cc2.get("富裕阶层", 0) * 100.0 / pop2)])
				lines.append("  失业: %d%%  幸福: %d%%" % [
					(int(city.unemployed * 100.0 / pop2) if city.unemployed > 0 else 0), int(city.happiness)])
				lines.append("  教育率: %d%%  健康: %d%%  犯罪率: %d%%" % [int(edu_rate), int(100.0 - sick_rate), int(crime_rate)])
				lines.append("  社会稳定: %d%%" % int(sim.social_stability))
				lines.append("  设施: 学校%d 诊所%d 医院%d 治安站%d 警察局%d" % [
					city.schools, city.clinics, city.hospitals, city.guard_posts, city.police_stations])
	# 文明·知识（0.17）
	var tech_mgr = world.get("tech_mgr")
	if tech_mgr:
		var pd: Dictionary = tech_mgr.panel_data(c)
		lines.append("")
		lines.append("[b]文明·知识[/b]")
		lines.append("  时代: " + str(pd["era"]))
		for ks in pd["knowledge"]:
			lines.append("  %s: %d" % [ks.field, int(ks.value)])
		var invs: Array = pd["inventions"]
		if not invs.is_empty():
			lines.append("  最近发明:")
			for inv in invs.slice(maxi(0, invs.size() - 3), invs.size()):
				lines.append("    " + str(inv["name"]) + "（" + str(inv["creator"]) + "·" + str(inv["year"]) + "年）")
		lines.append("  语言: " + str(pd["language"]))
		var bl: Dictionary = pd["beliefs"]
		lines.append("  文化倾向: 战%d 贸%d 知%d" % [
			int(bl.get("war", 0)), int(bl.get("trade", 0)), int(bl.get("knowledge", 0))])
		var rgs: Array = pd["research_groups"]
		if not rgs.is_empty():
			var rg_txt: Array = []
			for g in rgs:
				rg_txt.append("%s(%d人 +%d%%)" % [g.name, g.members, g.bonus])
			lines.append("  研究组织: " + "、".join(rg_txt))
	# 国家（0.18）
	var country_mgr = world.get("country_mgr")
	if country_mgr and country_mgr.has_method("panel_data"):
		var nd: Dictionary = country_mgr.panel_data()
		lines.append("")
		lines.append("[b]国家[/b]")
		if nd.get("formed", false):
			lines.append("  %s · %s" % [nd["name"], nd["government_type"]])
			lines.append("  首都: " + nd["capital"])
			lines.append("  人口: %d  城市: %d  领土: %d 区域" % [nd["population"], nd["cities"], nd["territory"]])
			lines.append("  收入: +%d/月  支出: -%d/月  税率: %d%%" % [int(nd["income"]), int(nd["expenses"]), int(nd["tax_rate"] * 100)])
			lines.append("  合法性: %d%%  稳定: %d%%" % [int(nd["legitimacy"]), int(nd["stability"])])
			if nd["revolution_risk"] >= 50.0:
				lines.append("  ⚠ 革命风险: %d%%" % int(nd["revolution_risk"]))
			var law_lines: Array = []
			for lw in nd["laws"]:
				law_lines.append(("☑ " if lw["enabled"] else "☐ ") + lw["name"])
			if not law_lines.is_empty():
				lines.append("  法律: " + "、".join(law_lines))
			var grp_lines: Array = []
			for grp in nd["groups"]:
				grp_lines.append("%s(%d人 力%.0f)" % [grp["name"], grp["members"], grp["power"]])
			if not grp_lines.is_empty():
				lines.append("  政治集团: " + "、".join(grp_lines))
			var nhist: Array = nd["history"]
			if not nhist.is_empty():
				lines.append("  国家历史:")
				for e in nhist.slice(maxi(0, nhist.size() - 3), nhist.size()):
					lines.append("    " + e)
		else:
			lines.append("  未建立（" + str(nd.get("reason", "")) + "）")
		# 世界地图（TAB → WORLD）
		var cm = world.get("country_mgr")
		if cm and cm.get("territory") and cm.territory.has_method("world_map_text"):
			lines.append("")
			lines.append("[b]世界地图[/b]")
			lines.append(cm.territory.world_map_text(cm.eden_country(), world.get("city_mgr")))
	# 行政区（0.19）
	var admin_mgr = world.get("admin_mgr")
	if admin_mgr and admin_mgr.has_method("panel_data"):
		var ad: Dictionary = admin_mgr.panel_data(country_mgr.eden_country() if country_mgr else null)
		lines.append("")
		lines.append("[b]行政区[/b]")
		if ad["provinces"].is_empty():
			lines.append("  尚未设立省（国家建立后自动分省）")
		else:
			for p in ad["provinces"]:
				lines.append("  %s（%d城 %d人）" % [p["name"], p["cities"], p["population"]])
				lines.append("    省长: " + (p["governor"] if p["governor"] != "" else "未定") + "  行政%d%% 腐败%d%% 税收%d" % [p["admin"], p["corruption"], p["tax"]])
				lines.append("    基建%d 发展%d" % [p["infra"], p["development"]])
	# 基础设施（0.19）
	var infra_mgr = world.get("infra_mgr")
	if infra_mgr and infra_mgr.has_method("panel_data"):
		var id2: Dictionary = infra_mgr.panel_data(country_mgr.eden_country() if country_mgr else null)
		lines.append("")
		lines.append("[b]基础设施[/b]（" + str(id2["era"]) + "）")
		if id2["roads"].is_empty():
			lines.append("  无道路（国家建立后连接城市）")
		else:
			var rm: String = str(id2["road_map"]).replace("\n", " ")
			lines.append("  道路 %d 条：%s" % [id2["roads"].size(), rm.substr(0, 120)])
			if not id2["railways"].is_empty():
				lines.append("  铁路 %d 条" % id2["railways"].size())
			if not id2["ports"].is_empty():
				lines.append("  港口 %d 座" % id2["ports"].size())
			if not id2["bridges"].is_empty():
				lines.append("  桥梁 %d 座" % id2["bridges"].size())
	# 交通物流（0.19）
	var transport_mgr = world.get("transport_mgr")
	if transport_mgr and transport_mgr.has_method("panel_data"):
		var td: Dictionary = transport_mgr.panel_data(country_mgr.eden_country() if country_mgr else null)
		lines.append("")
		lines.append("[b]交通物流[/b]")
		lines.append("  本月货物批次: %d（%d 单位）" % [td["logistics"]["cargos"], td["logistics"]["total"]])
		lines.append("  本月迁移: %d 人" % td["migration"]["total"])
		var rlines: Array = td["routes"].split("\n") if td["routes"] != "" else []
		for rl in rlines:
			lines.append("  " + rl)
		# 性能（0.19.5）
	var sched = world.get_node_or_null("Scheduler")
	if sched and sched.get("perf") != null:
		var pf: Dictionary = sched.perf
		lines.append("")
		lines.append("[b]PERFORMANCE[/b]")
		lines.append("  FPS: %d   帧时间: %.1f ms" % [int(pf["fps"]), pf["frame_ms"]])
		lines.append("  人类: %d  (Active %d / Sim %d / Data %d)" % [pf["humans_total"], pf["humans_active"], pf["humans_sim"], pf["humans_data"]])
		lines.append("  建筑: %d   区域: 加载%d 激活%d   节点: %d" % [pf["buildings_total"], pf["regions_loaded"], pf["regions_active"], pf["nodes"]])
		lines.append("  AI %d/s   寻路 %d/s   导航 %d/s" % [pf["ai_ticks"], pf["pathfinds"], pf["nav_ticks"]])
		lines.append("  耗时: AI %.1fms  经济 %.1fms  UI %.1fms" % [pf["ai_ms"], pf["economy_ms"], pf["ui_ms"]])
		lines.append("  历史 %d 条   居民记忆 %d 条" % [pf["history_total"], pf["memory_total"]])
	lines.append("")
	lines.append("[b]最近历史[/b]")
	for e in hist.slice(max(0, hist.size()-3), hist.size()):
		lines.append("  " + e)
	side_panel.text = "\n".join(lines)

func _livelihood(c, world) -> String:
	var residents: Array = world.society.population.residents
	var pop: int = residents.size()
	# 幸福度
	var happy_sum: float = 0.0
	var workers: int = 0
	for n in residents:
		var nd = n.get("needs")
		if nd: happy_sum += nd.happiness
		if n.get("job") != "孩子": workers += 1
	var happy: float = (happy_sum / pop) if pop > 0 else 0.0
	# 食物
	var food: float = c.resource.resources.get("food", 0.0)
	var food_txt: String = "充足" if food > pop * 10.0 else ("紧张" if food > pop * 2.0 else "短缺")
	# 住房
	var houses: int = world.settlement.capacity()
	var house_txt: String = "正常" if houses >= pop else "拥挤"
	# 就业
	var employ: int = int(workers * 100.0 / pop) if pop > 0 else 0
	return "幸福: %d%%\n食物: %s (%d)\n住房: %s (%d/%d)\n就业: %d%%" % [
		int(happy), food_txt, int(food), house_txt, houses, pop, employ
	]
