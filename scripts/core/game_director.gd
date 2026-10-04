extends Node
## 游戏总指挥（核心循环）
## 统一驱动一天的节奏：黎明 → 工作 → 正午 → 黄昏 → 夜晚 → 结算新的一天
## 所有系统不再各自计时，由 Director 在对应阶段调用。

signal phase_changed(phase: String)
signal day_ended(day: int)

const ProductionScript: Script = preload("res://scripts/economy/production.gd")

var production: Node
var world: Node
var day_count: int = 1
var _last_hour: int = -1
var _last_phase: String = ""
var _last_city_year: int = 0   # 城市年度评估标记（0.15）
var _last_social_year: int = 0 # 社会年度评估标记（0.16）
var _last_country_year: int = 0 # 国家年度评估标记（0.18）
var _last_infra_year: int = 0 # 基建年度评估标记（0.19）
var _last_econ_year: int = 0   # 经济年度评估标记（0.20）
var _last_econ_day: int = 0    # 经济月度阈值（0.20，兼容高流速天跳变）

# 一天的阶段时刻表（小时）
var PHASES := {
	6: "黎明",
	8: "工作",
	12: "正午",
	18: "黄昏",
	22: "夜晚",
}

func _ready() -> void:
	production = ProductionScript.new()
	add_child(production)

func bind(w: Node) -> void:
	world = w

var _day_source: Node = null   # 季节日信号源（0.19.1：天结算统一由 season_sys 驱动）

func _process(_delta: float) -> void:
	# 延迟连接季节日信号（保证 ecosystem 已挂载）
	if _day_source == null and world != null:
		var clock = get_node_or_null("/root/Main/WorldTime")
		if clock:
			_day_source = clock
			if not _day_source.day_changed.is_connected(_on_season_day):
				_day_source.day_changed.connect(_on_season_day)
			day_count = _day_source.day
			if not clock.hour_changed.is_connected(_on_econ_hour):
				clock.hour_changed.connect(_on_econ_hour)
	var clock = get_node_or_null("/root/Main/WorldTime")
	if clock == null: return
	var h: int = clock.get_hour()
	if h == _last_hour: return
	_last_hour = h
	if PHASES.has(h):
		_enter_phase(PHASES[h], h)

## 季节日推进 → 新的一天（统一时钟，月度 = 10 天）
func _on_season_day(d: int) -> void:
	if d == day_count: return
	day_count = d
	_new_day()

func _enter_phase(phase: String, hour: int) -> void:
	if phase == _last_phase: return
	_last_phase = phase
	phase_changed.emit(phase)
	match phase:
		"黎明": _dawn()
		"工作": _work_begins()
		"正午": _noon()
		"黄昏": _dusk()
		"夜晚": _night()

# ---------- 各阶段 ----------
func _dawn() -> void:
	_toast("🌅", "黎明，居民离开家门开始工作")

func _work_begins() -> void:
	# NPC 大脑按小时自行前往工作点
	pass

func _noon() -> void:
	pass

func _dusk() -> void:
	_toast("🌆", "黄昏，居民返回家中")

func _night() -> void:
	pass

func _new_day() -> void:
	day_count += 1
	_refresh_residents()
	_run_daily_economy()
	_run_econ_020_daily()
	_run_politics()
	_run_military()
	_run_city()
	_handle_society()
	_run_social()
	_run_country()
	_run_infra()
	# 0.20 经济帝国：每月=企业分红+区域贸易+银行+家庭储蓄+GDP；每年=产业升级
	if day_count >= _last_econ_day + 10:
		_last_econ_day = day_count
		_run_econ_020_monthly()
	var eco_now = world.get("ecosystem") if world else null
	if eco_now and eco_now.get("season_sys"):
		var ynow: int = eco_now.season_sys.year
		if ynow != _last_econ_year:
			_last_econ_year = ynow
			_run_econ_020_yearly()
	_record_history()
	day_ended.emit(day_count)

## 行政/基建/交通（0.19）：每月=行政+基建维护+物流迁移贸易线；每年=道路/铁路/港口升级
func _run_infra() -> void:
	if world == null: return
	if day_count % 10 == 0:
		var am = world.get("admin_mgr")
		if am and am.has_method("monthly_tick"): am.monthly_tick()
		var im = world.get("infra_mgr")
		if im and im.has_method("monthly_tick"): im.monthly_tick()
		var tm = world.get("transport_mgr")
		if tm and tm.has_method("monthly_tick"): tm.monthly_tick()
	var eco = world.get("ecosystem")
	if eco and eco.get("season_sys"):
		var yr: int = eco.season_sys.year
		if yr != _last_infra_year:
			_last_infra_year = yr
			var im = world.get("infra_mgr")
			if im and im.has_method("yearly_tick"):
				im.yearly_tick()

## 国家层（0.18）：每月=财政/税收/政治压力；每年=形成/稳定/危机/转型/继承
func _run_country() -> void:
	if world == null: return
	var cm = world.get("country_mgr")
	if cm == null: return
	if day_count % 10 == 0 and cm.has_method("monthly_tick"):
		cm.monthly_tick()
	var eco = world.get("ecosystem")
	if eco and eco.get("season_sys"):
		var yr: int = eco.season_sys.year
		if yr != _last_country_year:
			_last_country_year = yr
			if cm.has_method("yearly_tick"):
				cm.yearly_tick()

## 城市层（每天统计 + 每年升级评估，0.15）
func _run_city() -> void:
	if world == null: return
	var city_mgr = world.get("city_mgr")
	if city_mgr == null: return
	if city_mgr.has_method("daily_tick"):
		city_mgr.daily_tick(world)
	# 年度评估（跟随生态年）
	var eco = world.get("ecosystem")
	if eco and eco.get("season_sys"):
		var yr: int = eco.season_sys.year
		if yr != _last_city_year:
			_last_city_year = yr
			if city_mgr.has_method("yearly_tick"):
				city_mgr.yearly_tick(world)

## 军事/战争层（每天）：后勤、边境摩擦、宣战、战斗、停战重建
func _run_military() -> void:
	if world == null: return
	var war_mgr = world.get("war_mgr")
	if war_mgr and war_mgr.has_method("daily_tick"):
		war_mgr.daily_tick(world)

## 政治/外交层（每天）：制度升级、支持率、军事、决策、外交漂移
func _run_politics() -> void:
	if world == null: return
	var pol = world.get("politics")
	if pol and pol.has_method("daily_tick"):
		pol.daily_tick()
	var dpl = world.get("diplomacy")
	if dpl and dpl.has_method("daily_tick"):
		dpl.daily_tick()

## 社会层（0.16）：每天=健康/不满/互动；每月=阶层/教育/犯罪/稳定度→政治压力；每年=文化/节日
func _run_social() -> void:
	if world == null: return
	var sim = world.get("social_sim")
	if sim == null: return
	var society = world.get("society")
	var city_mgr = world.get("city_mgr")
	if society == null or city_mgr == null: return
	var city = city_mgr.eden_city() if city_mgr.has_method("eden_city") else null
	var gov = null
	var civ = world.get("civ")
	if civ and civ.get("government"): gov = civ.government
	var residents: Array = society.population.residents
	if sim.has_method("daily_tick"):
		sim.daily_tick(residents, city, gov)
	# 0.17 技术层：每天=个人技能积累；每月=知识汇总/发明
	var tech_mgr = world.get("tech_mgr")
	if tech_mgr and tech_mgr.has_method("daily_tick"):
		tech_mgr.daily_tick(residents)
	if day_count % 10 == 0:
		if sim.has_method("monthly_tick"):
			sim.monthly_tick(residents, city, gov)
		if tech_mgr and tech_mgr.has_method("monthly_tick"):
			tech_mgr.monthly_tick(residents, city)
	# 每年（跟随生态年）：文化/节日 + 0.17 技术演化（时代/传播/衰减）
	var eco = world.get("ecosystem")
	if eco and eco.get("season_sys"):
		var yr: int = eco.season_sys.year
		if yr != _last_social_year:
			_last_social_year = yr
			if sim.has_method("yearly_tick"):
				sim.yearly_tick(residents, city)
			if tech_mgr and tech_mgr.has_method("yearly_tick"):
				tech_mgr.yearly_tick(city, residents)

## 社会层（每天）：贫困者转行寻找新工作；连续挨饿者因饥荒离世
func _handle_society() -> void:
	if world == null: return
	var society = world.get("society")
	if society == null: return
	society.handle_social_mobility()
	society.handle_famine()

func _refresh_residents() -> void:
	if world == null: return
	var society = world.get("society")
	if society == null: return
	for npc in society.population.residents:
		if npc.get("goal_sys"):
			npc.goal_sys.new_day(npc.job, npc.age)
		if npc.get("life_memory") and day_count % 4 == 0:
			npc.life_memory.yearly_decay()

# ---------- 每日经济结算（真实闭环：生产→市场→工资→购买→消费→外贸） ----------
func _run_daily_economy() -> void:
	if world == null: return
	var _econ_t0: int = Time.get_ticks_usec()
	var society = world.get("society")
	var economy_mgr = world.get("economy")
	var civ_mgr = world.get("civ")
	if society == null or economy_mgr == null: return
	# 天气影响粮食产量
	var eco = world.get("ecosystem")
	var mult: float = 1.0
	if eco and eco.get("weather_sys"):
		mult = eco.weather_sys.crop_yield_multiplier()
	economy_mgr.daily_tick(society.population.residents, society.families, mult, world)
	# 把市场库存同步到旧资源面板，保持显示一致
	if civ_mgr:
		var resource = civ_mgr.get("resource")
		if resource:
			for item in economy_mgr.market.stock:
				resource.resources[item] = economy_mgr.market.stock[item]
	# 有人挨饿 → 预警
	if economy_mgr.last_fed_ratio < 0.999:
		var hungry: int = int(round(society.population.count() * (1.0 - economy_mgr.last_fed_ratio)))
		_toast("⚠️", "%d 位居民今天没吃上饭，粮价上涨" % hungry)
	# 0.19.6 耗时打点
	var sched = world.get_node_or_null("Scheduler")
	if sched and sched.has_method("note_economy_ms"):
		sched.note_economy_ms(float(Time.get_ticks_usec() - _econ_t0) / 1000.0)

# ---------- 0.20 经济帝国层：小时=工厂生产；每天=供需/区域物流；每月=企业分红+贸易+银行+GDP；每年=产业升级 ----------
func _on_econ_hour(_h: int) -> void:
	if world == null: return
	var econ_sim = world.get("econ_sim")
	if econ_sim and econ_sim.has_method("hourly_tick"):
		econ_sim.hourly_tick(world)

func _run_econ_020_daily() -> void:
	if world == null: return
	var society = world.get("society")
	var economy_mgr = world.get("economy")
	if society == null or economy_mgr == null: return
	var econ_sim = world.get("econ_sim")
	if econ_sim and econ_sim.has_method("daily_tick"):
		econ_sim.daily_tick(world, economy_mgr.market, society.population.residents)
	var trade_mgr = world.get("trade_mgr")
	if trade_mgr and trade_mgr.has_method("daily_tick"):
		trade_mgr.daily_tick(world)

func _run_econ_020_monthly() -> void:
	if world == null: return
	var society = world.get("society")
	var economy_mgr = world.get("economy")
	if society == null or economy_mgr == null: return
	var econ_sim = world.get("econ_sim")
	if econ_sim and econ_sim.has_method("monthly_tick"):
		econ_sim.monthly_tick(world, economy_mgr.market, society.population.residents)

func _run_econ_020_yearly() -> void:
	if world == null: return
	var econ_sim = world.get("econ_sim")
	if econ_sim and econ_sim.has_method("yearly_tick"):
		econ_sim.yearly_tick(world)

func _record_history() -> void:
	var civ_mgr = world.get("civ") if world else null
	if civ_mgr == null: return
	var hist = civ_mgr.get("history")
	var pop = world.get("society").population.count()
	if hist:
		hist.record("第%d天：人口%d，日常结算" % [day_count, pop])

func _toast(icon: String, text: String) -> void:
	var toast = get_node_or_null("/root/Main/EventToast")
	if toast and toast.has_method("show_event"):
		toast.show_event(icon, text)
