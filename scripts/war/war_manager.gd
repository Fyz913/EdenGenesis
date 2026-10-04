extends Node
## 战争总指挥：宣战 → 战争 → 战斗 → 伤亡 → 疲劳 → 和平 → 重建
## 战争必须通过外交关系恶化触发，并影响经济/政治/居民记忆

const WarScript: Script = preload("res://scripts/war/war.gd")
const BattleScript: Script = preload("res://scripts/war/battle.gd")
const PeaceTreatyScript: Script = preload("res://scripts/war/peace_treaty.gd")
const WarEventScript: Script = preload("res://scripts/history/war_event.gd")
const CombatScript: Script = preload("res://scripts/military/combat_system.gd")

var wars: Array = []
var peace_treaties: Array = []
var war_history: Array = []       # WarEvent
var combat: Node
var _friction_timer: int = 0

func _ready() -> void:
	combat = CombatScript.new()
	add_child(combat)

func get_active_war_for(civ_id: String):
	for w in wars:
		if w.active and (w.attacker == civ_id or w.defender == civ_id):
			return w
	return null

func get_war_between(a: String, b: String):
	for w in wars:
		if w.active and ((w.attacker == a and w.defender == b) or (w.attacker == b and w.defender == a)):
			return w
	return null

# ---------- 宣战流程：外交恶化 → 冲突事件 → 政府决定 → 宣战 ----------
func check_casus_belli(world) -> void:
	var dpl = world.get("diplomacy")
	if dpl == null: return
	var pol = world.get("politics")
	var eco = world.get("ecosystem")
	var yr: int = eco.season_sys.year if eco and eco.get("season_sys") else 1
	for pair in [["Eden", "北境部落"], ["Eden", "沙漠城邦"], ["北境部落", "沙漠城邦"]]:
		var a: String = pair[0]; var b: String = pair[1]
		if get_war_between(a, b): continue
		# 和平条约有效期内禁止再战
		if _has_active_treaty(a, b, yr): continue
		# 严格低于 -60（停战设定为 -60，避免宣战-停战死循环）
		if dpl.relation_value(a, b) < -60.0:
			# 政府决定：支持率高于 30 才宣战（政治系统参与决策）
			var support: float = pol.support_rate if pol else 50.0
			if support < 30.0:
				continue
			_declare_war(world, a, b)

func _has_active_treaty(a: String, b: String, current_year: int) -> bool:
	for t in peace_treaties:
		if not t.active: continue
		var matched: bool = (t.civilization_a == a and t.civilization_b == b) or (t.civilization_a == b and t.civilization_b == a)
		if matched and not t.is_expired(current_year):
			return true
	return false

func _declare_war(world, attacker: String, defender: String) -> void:
	var war = WarScript.new()
	war.id = "war_%d" % (wars.size() + 1)
	war.attacker = attacker
	war.defender = defender
	war.goal_type = ["边境争议", "资源争夺"].pick_random()
	var eco = world.get("ecosystem")
	war.start_year = eco.season_sys.year if eco and eco.get("season_sys") else 1
	wars.append(war)
	# 动员：宣战当天本土军队按人口满额（常备军→战时满编）
	var army_mgr = world.get("army_mgr")
	if army_mgr:
		var army = army_mgr.get_army(attacker)
		var society = world.get("society")
		if army and society:
			var max_n: int = army.max_soldiers(int(society.population.count()))
			while army.soldiers < max_n:
				army_mgr.enlist_from_population(world, attacker, max_n - army.soldiers)
				if army.soldiers >= max_n or not army_mgr.armies.has(attacker): break
			army.soldiers = maxi(army.soldiers, mini(max_n, army.soldiers))
			army.recompute_strength()
	# 外交：宣战 → 关系 -100
	var dpl = world.get("diplomacy")
	if dpl: dpl.apply_event(attacker, defender, "攻击")
	# 历史与事件
	_record_war_event(world, war, "宣战", "%s 对 %s 宣战（目标：%s）" % [attacker, defender, war.goal_type], 0)
	var hist = _history(world)
	if hist: hist.record("第%d年：%s 与 %s 爆发战争" % [war.start_year, attacker, defender])
	_toast(world, "⚔️", "%s 对 %s 宣战！" % [attacker, defender])

# ---------- 每日结算 ----------
func daily_tick(world) -> void:
	# 条约到期 → 失效
	var eco = world.get("ecosystem")
	var yr: int = eco.season_sys.year if eco and eco.get("season_sys") else 1
	for t in peace_treaties:
		if t.active and t.is_expired(yr):
			t.active = false
	var army_mgr = world.get("army_mgr")
	if army_mgr == null: return
	army_mgr.daily_tick(world)
	# 边境摩擦：关系中立以下才可能恶化（外交恶化渠道）
	_friction_timer += 1
	if _friction_timer >= 4:
		_friction_timer = 0
		_try_friction(world)
	check_casus_belli(world)
	# 战争进行中的结算
	var ended: Array = []
	for war in wars:
		if not war.active: continue
		war.process_day()
		_apply_war_economy(world, war)
		_try_battle(world, war)
		if _check_war_end(world, war):
			ended.append(war)
	for war in ended:
		_end_war(world, war)

func _try_friction(world) -> void:
	var dpl = world.get("diplomacy")
	if dpl == null: return
	for pair in [["Eden", "北境部落"], ["Eden", "沙漠城邦"], ["北境部落", "沙漠城邦"]]:
		var a: String = pair[0]; var b: String = pair[1]
		if get_war_between(a, b): continue
		if dpl.relation_value(a, b) <= 10.0 and randf() < 0.4:
			dpl.apply_event(a, b, "边境冲突")
			var hist = _history(world)
			if hist: hist.record("边境摩擦：%s 与 %s 关系紧张" % [a, b])
			_toast(world, "🗡", "%s 与 %s 发生边境冲突" % [a, b])

# ---------- 战争经济 ----------
func _apply_war_economy(world, war) -> void:
	# 军费：从国库每日支出
	var gov = world.get("civ").get("government") if world and world.get("civ") else null
	if gov:
		var budget: float = 5.0 + war.attacker_casualties * 0.5
		gov.military_budget += budget
		gov.treasury = maxf(0.0, gov.treasury - budget)
	# 战争物资需求：铁/木材/食物价格上行压力
	var economy = world.get("economy")
	if economy and economy.get("market"):
		for item in ["iron", "wood", "food"]:
			if economy.market.prices.has(item):
				economy.market.prices[item] = clampf(economy.market.prices[item] * 1.01, 1.0, 100.0)
	# 居民迁移压力
	var society = world.get("society")
	if society:
		for npc in society.population.residents:
			if npc.get("migration_pressure") != null:
				npc.migration_pressure += 2.0

# ---------- 战斗 ----------
func _try_battle(world, war) -> void:
	var army_mgr = world.get("army_mgr")
	if army_mgr == null: return
	var atk = army_mgr.get_army(war.attacker)
	var def = army_mgr.get_army(war.defender)
	if atk == null or def == null: return
	if atk.soldiers <= 0 or def.soldiers <= 0: return
	# 每 3 天左右打一场
	if war.battle_count % 3 != 0:
		war.battle_count += 1
		return
	war.battle_count += 1
	var result: Dictionary = combat.resolve_battle(atk, def)
	atk.casualties(result["attacker_casualties"])
	def.casualties(result["defender_casualties"])
	war.attacker_casualties += result["attacker_casualties"]
	war.defender_casualties += result["defender_casualties"]
	# 伤亡落到居民（0.11 生命系统连接）
	_kill_soldiers(world, atk, result["attacker_casualties"])
	_kill_soldiers(world, def, result["defender_casualties"])
	# 记录战斗
	var eco = world.get("ecosystem")
	var yr: int = eco.season_sys.year if eco and eco.get("season_sys") else 1
	var b = BattleScript.new()
	b.year = yr
	b.title = "%s-%s 战斗" % [war.attacker, war.defender]
	b.description = "%s 军与 %s 军交战，%s 获胜；%s 伤亡%d，%s 伤亡%d" % [
		war.attacker, war.defender,
		war.attacker if result["attacker_won"] else war.defender,
		war.attacker, result["attacker_casualties"],
		war.defender, result["defender_casualties"]]
	b.attacker_casualties = result["attacker_casualties"]
	b.defender_casualties = result["defender_casualties"]
	b.attacker_won = result["attacker_won"]
	war.set("last_battle", b)
	_record_war_event(world, war, "战斗", b.description, result["attacker_casualties"] + result["defender_casualties"])
	_toast(world, "⚔️", b.description)

## 战斗伤亡映射到参战居民：幸存者记忆 + 阵亡者家属记忆 + 移除
func _kill_soldiers(world, army, n: int) -> void:
	if n <= 0: return
	var society = world.get("society")
	var killed: int = 0
	for i in range(army.soldier_refs.size() - 1, -1, -1):
		if killed >= n: break
		var s = army.soldier_refs[i]
		if not is_instance_valid(s.human):
			army.soldier_refs.remove_at(i)
			continue
		army.soldier_refs.remove_at(i)
		killed += 1
		# 家属获得战争记忆
		var npc = s.human
		var eco = world.get("ecosystem")
		var yr: int = eco.season_sys.year if eco and eco.get("season_sys") else 1
		if npc.spouse and is_instance_valid(npc.spouse) and npc.spouse.has_method("experience"):
			npc.spouse.experience({"text": "我的%s死于战争" % ("丈夫" if npc.gender == "男" else "妻子"), "importance": 90, "year": yr, "kind": "战争"})
		if npc.family:
			for kid in npc.family.children:
				if is_instance_valid(kid) and kid.has_method("experience"):
					kid.experience({"text": "战争夺走了我的亲人", "importance": 75, "year": yr, "kind": "战争"})
		if society and society.has_method("remove_resident"):
			society.remove_resident(npc, "战死沙场")

# ---------- 战争结束 / 和平 / 重建 ----------
func _check_war_end(world, war) -> bool:
	var army_mgr = world.get("army_mgr")
	if army_mgr == null: return false
	var atk = army_mgr.get_army(war.attacker)
	var def = army_mgr.get_army(war.defender)
	var one_gone: bool = (atk and atk.soldiers <= 0) or (def and def.soldiers <= 0)
	if one_gone: return true
	# 战争疲劳：持续过久 → 停战
	if war.war_exhaustion >= 40.0 and randf() < 0.3:
		return true
	return false

func _end_war(world, war) -> void:
	war.active = false
	# 和平条约
	var treaty = PeaceTreatyScript.new()
	treaty.civilization_a = war.attacker
	treaty.civilization_b = war.defender
	var eco = world.get("ecosystem")
	treaty.year_signed = eco.season_sys.year if eco and eco.get("season_sys") else 1
	treaty.duration = 10
	peace_treaties.append(treaty)
	# 外交：结束 → -60，随后缓慢恢复
	var dpl = world.get("diplomacy")
	if dpl:
		var r = dpl.get_relation(war.attacker, war.defender)
		if r:
			r.value = -60.0
			r._update_flags()
	# 退役：释放参战居民
	var army_mgr = world.get("army_mgr")
	if army_mgr:
		army_mgr.release_soldiers(world, war.attacker)
		army_mgr.release_soldiers(world, war.defender)
	# 战后重建：建筑健康度恢复 + 历史
	var st = world.get("settlement")
	if st:
		for b in st.buildings:
			if typeof(b) == TYPE_DICTIONARY:
				b["health"] = minf(100.0, b.get("health", 100.0) + 20.0)
	var hist = _history(world)
	if hist: hist.record("第%d年：%s 与 %s 停战，签订和平条约（持续%d年）" % [treaty.year_signed, war.attacker, war.defender, treaty.duration])
	_record_war_event(world, war, "停战", "%s 与 %s 签订和平条约，进入重建期" % [war.attacker, war.defender], war.attacker_casualties + war.defender_casualties)
	_toast(world, "🕊", "%s 与 %s 停战，开始战后重建" % [war.attacker, war.defender])

func _record_war_event(world, war, title: String, desc: String, casualties: int) -> void:
	var eco = world.get("ecosystem")
	var yr: int = eco.season_sys.year if eco and eco.get("season_sys") else 1
	var ev = WarEventScript.new()
	ev.year = yr
	ev.title = title
	ev.description = desc
	ev.casualties = casualties
	war_history.append(ev)
	if war_history.size() > 500:
		war_history.pop_front()

func _history(world):
	if world == null: return null
	var civ = world.get("civ")
	return civ.get("history") if civ else null

func _toast(world, icon: String, text: String) -> void:
	var toast = world.get_node_or_null("/root/Main/EventToast")
	if toast and toast.has_method("show_event"):
		toast.show_event(icon, text)
