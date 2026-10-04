extends Node
## 政治系统总指挥：领袖/议事会推举、制度升级（条件触发）、支持率、
## 军事数据、每日决策。每天结算一次（政治在 Day 层，绝不每帧运行）。

const LeadershipScript: Script = preload("res://scripts/organization/leadership_system.gd")
const CouncilScript: Script = preload("res://scripts/politics/council.gd")
const DecisionScript: Script = preload("res://scripts/politics/decision_system.gd")
const PolicyScript: Script = preload("res://scripts/politics/policy.gd")
const PoliticalEventScript: Script = preload("res://scripts/history/political_event.gd")

var leadership: Node
var council
var decision_sys: Node
var policy

var leader: Node = null
var support_rate: float = 50.0
var world: Node = null

func _ready() -> void:
	leadership = LeadershipScript.new(); add_child(leadership)
	decision_sys = DecisionScript.new(); add_child(decision_sys)
	policy = PolicyScript.new()
	council = CouncilScript.new()

func bind(w: Node) -> void:
	world = w
	var gov = _gov()
	if gov == null: return
	# 推举领袖（声望最高；0.13 不自动换人，仅在此初始确立）
	if leader == null:
		leader = leadership.pick_leader(world.society.population.residents)
		if leader and gov.get("leader_id") == "":
			gov.leader_id = leader.npc_name
			_record("选举", leader.npc_name + " 被推举为村长")
	# 议事会：声望前 5
	if council.members.is_empty():
		var elders: Array = leadership.top_elders(world.society.population.residents, 5)
		for e in elders:
			council.add_member(e.npc_name)
			gov.add_council_member(e.npc_name)
		world.get("org_mgr").establish_council(council.members) if world.get("org_mgr") else null
		_record("议事会", "Eden 议事会成立，共 %d 人" % council.members.size())

func _gov():
	if world == null: return null
	var civ = world.get("civ")
	return civ.get("government") if civ else null

## 每日结算
func daily_tick() -> void:
	var gov = _gov()
	if gov == null: return
	_check_upgrade(gov)
	_update_approval(gov)
	_update_military(gov)
	if world and world.get("director") and world.director.day_count % 4 == 0:
		_run_decision()

# ---------- 制度升级：必须条件触发，不按年份 ----------
func _check_upgrade(gov) -> void:
	var n: int = world.society.population.count()
	var econ = world.get("economy")
	var food_ok: bool = econ and econ.market.stock.get("food", 0.0) >= n * 3.0
	var st = world.get("settlement")
	var house_ok: bool = st and st.capacity() >= n
	if gov.type == "部落" and n >= 20 and food_ok and house_ok:
		gov.type = "村社"
		# 视觉：广场北侧建议事厅
		if st and st.has_method("add_townhall"):
			st.add_townhall(st.districts.civic)
		_record("制度", "Eden 建立村社制度（人口、粮食、住房达标）")
		_fire_toast("🏛", "Eden 从部落升级为村社！")
	elif gov.type == "村社" and n >= 50 and food_ok and house_ok:
		gov.type = "城镇议会"
		_record("制度", "Eden 成立城镇议会")
		_fire_toast("🏛", "Eden 升级为城镇议会！")

func _update_approval(gov) -> void:
	var econ = world.get("economy")
	var fed: float = econ.last_fed_ratio if econ else 1.0
	support_rate = leadership.approval(world.society.population.residents, gov, fed)

func _update_military(gov) -> void:
	# 士兵受人口约束：约 10%
	gov.soldiers = int(world.society.population.count() * 0.1)
	gov.military_power = 5.0 + gov.soldiers * 3.0
	gov.military_budget = gov.treasury * 0.02

# ---------- 决策流程 ----------
func _run_decision() -> void:
	var result: Dictionary = decision_sys.check_and_decide(world, _gov(), policy, world.society.population.residents)
	if result.is_empty(): return
	var title: String = result.get("title", "")
	var passed: bool = result.get("passed", false)
	var desc: String = result.get("desc", "")
	if passed:
		_record("政策", "通过「" + title + "」：" + desc)
		_fire_toast("📜", "议事会通过「" + title + "」")
	else:
		_record("政策", "否决「" + title + "」提案")
		_fire_toast("🗳", "议事会否决「" + title + "」")

# ---------- 记录 ----------
func _record(kind: String, text: String) -> void:
	var civ = world.get("civ")
	var hist = civ.get("history") if civ else null
	var yr: int = 1
	var eco = world.get("ecosystem")
	if eco and eco.get("season_sys"): yr = eco.season_sys.year
	if hist: hist.record("第%d年[%s] %s" % [yr, kind, text])
	# 同步到结构化政治事件（数据类）
	var gov = _gov()
	if gov:
		gov.political_events.append(PoliticalEventScript.new(yr, kind, text))
		if gov.political_events.size() > 200:
			gov.political_events.pop_front()

func _fire_toast(icon: String, text: String) -> void:
	var toast = get_node_or_null("/root/Main/EventToast")
	if toast and toast.has_method("show_event"):
		toast.show_event(icon, text)
