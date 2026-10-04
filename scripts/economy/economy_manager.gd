extends Node
## 经济总管：编排每日经济循环（分层模拟中"每天"这一层）
## 顺序：生产供货(=发工资) → 家庭/个人购买食物 → 消费 → 价格更新 → 外贸 → 阶层统计
## 铁律：商品只来自生产/进口，工资只来自市场收购，没钱/没货就买不到东西。

const MarketScript: Script = preload("res://scripts/economy/market.gd")
const JobScript: Script = preload("res://scripts/economy/job_manager.gd")
const TradeScript: Script = preload("res://scripts/economy/trade_system.gd")
const ProductionScript: Script = preload("res://scripts/economy/production.gd")
const ClassScript: Script = preload("res://scripts/society/social_class.gd")

var market: Node
var jobs: Node
var trade: Node
var production: Node
var social_class: Node

var total_production: Dictionary = {}
var total_consumption: Dictionary = {}
var last_fed_ratio: float = 1.0

func _ready() -> void:
	market = MarketScript.new(); add_child(market)
	jobs = JobScript.new(); add_child(jobs)
	trade = TradeScript.new(); add_child(trade)
	production = ProductionScript.new(); add_child(production)
	social_class = ClassScript.new(); add_child(social_class)

# 每天一次完整结算
func daily_tick(residents: Array, families: Array, weather_mult: float, world) -> void:
	total_production = {}
	total_consumption = {}
	market.reset_quota(residents.size())
	var gov = null
	if world and world.get("civ"):
		gov = world.civ.get("government")
	_phase_production(residents, weather_mult, gov, world)
	var fed: int = _phase_consumption(residents, families)
	last_fed_ratio = float(fed) / max(1, residents.size())
	_phase_living_cost(residents)
	market.spoil()
	market.update_prices()
	trade.process_day(market, residents, true, world)
	market.siphon_surplus()

# 生活消费（衣物/工具/服务）：货币回笼到市场，防止财富无限堆积
func _phase_living_cost(residents: Array) -> void:
	for npc in residents:
		if not jobs.is_worker(npc): continue
		var cost: float = 2.0
		if npc.money >= cost:
			npc.money -= cost
			market.cash += cost
		else:
			var nd = npc.get("needs")
			if nd: nd.happiness = max(0.0, nd.happiness - 5.0)
			npc.poverty += 0.5

# 1) 居民工作 → 产出商品按配额入市场 → 市场发放岗位日薪（有钱才发）
#    发薪同时按税率扣缴进国库（0.13 政治），高税率直接伤居民幸福
func _phase_production(residents: Array, weather_mult: float, gov, world) -> void:
	var rate: float = gov.tax_rate if gov else 0.0
	# 0.17 文明知识 + 发明加成：产出资源 ← 对应知识领域（每点 +0.4%，封顶 +30%）+ 发明加成
	var know_mult: Dictionary = {"food": 0.0, "wood": 0.0, "stone": 0.0, "iron": 0.0, "cloth": 0.0}
	var inv_bonus: Dictionary = {"food": 0.0, "wood": 0.0, "stone": 0.0, "iron": 0.0, "cloth": 0.0}
	var tech_mgr = world.get("tech_mgr") if world else null
	if tech_mgr:
		var knowledge = tech_mgr.knowledge
		know_mult["food"] = clamp(knowledge.get_value("agriculture") * 0.004, 0.0, 0.3)
		know_mult["wood"] = clamp(knowledge.get_value("construction") * 0.004, 0.0, 0.3)
		know_mult["stone"] = clamp(knowledge.get_value("construction") * 0.004, 0.0, 0.3)
		know_mult["iron"] = clamp(knowledge.get_value("metallurgy") * 0.004, 0.0, 0.3)
		know_mult["cloth"] = clamp(knowledge.get_value("engineering") * 0.004, 0.0, 0.3)
		for r in know_mult.keys():
			inv_bonus[r] = tech_mgr.invention.field_bonus(_res_field(r))
	for npc in residents:
		if not jobs.is_worker(npc): continue
		# 0.16 效率：教育加成（每 100 点 +10% 产出）、生病减产（sickness>30 减 30%）
		var eff: float = 1.0
		if npc.get("education") != null:
			eff += npc.education * 0.001
		if npc.get("sickness") != null and npc.sickness > 30.0:
			eff *= 0.7
		# 0.17 个人技能效率（0.8~1.6）
		if npc.get("skills") != null and npc.skill_sys:
			eff *= npc.skill_sys.efficiency(npc.skills, npc.job)
		var out: Dictionary = production.work(npc.job)
		for item in out:
			var qty: float = out[item] * eff
			qty *= 1.0 + know_mult.get(item, 0.0) + inv_bonus.get(item, 0.0)
			if item == "food": qty *= weather_mult
			if not market.stock.has(item):
				market.stock[item] = 0.0
			var accepted: float = market.deposit(item, qty)
			total_production[item] = total_production.get(item, 0.0) + accepted
		# 岗位日薪：有产出岗位即发，市场现金不足则少发
		var wage: float = market.pay_salary(jobs.base_salary(npc.job))
		var tax: float = wage * rate
		var net: float = wage - tax
		if gov: gov.treasury += tax
		npc.money += net
		# 高税率惩罚：居民负担感
		if rate > 0.05 and npc.get("needs"):
			npc.needs.happiness = max(0.0, npc.needs.happiness - (rate - 0.05) * 150.0)
		# 已婚者把一半净收入上交家庭
		if npc.family and net > 0.0:
			npc.money -= net * 0.5
			npc.family.family_money += net * 0.5

# 产出资源 → 知识领域（发明加成映射）
func _res_field(r: String) -> String:
	match r:
		"food": return "agriculture"
		"wood", "stone": return "construction"
		"iron": return "metallurgy"
		"cloth": return "engineering"
	return "engineering"

# 2) 购买并消费食物：家庭统一采购，单身个人采购；返回吃饱的人数
func _phase_consumption(residents: Array, families: Array) -> int:
	var fed: Array = []
	# 家庭
	for fam in families:
		var members: Array = fam.get_members().filter(func(m): return residents.has(m))
		var need: int = members.size()
		if need == 0: continue
		var ok: bool = market.purchase_family(fam, "food", float(need))
		for m in members:
			if ok:
				fam.family_inventory.remove_item("food", 1.0)
				_feed(m)
				fed.append(m)
			else:
				_starve(m)
	# 单身 / 未被家庭覆盖者
	for npc in residents:
		if npc in fed: continue
		if npc.family: continue   # 已在家庭阶段处理
		if market.purchase(npc, "food", 1.0):
			npc.inventory.remove_item("food", 1.0)
			_feed(npc)
			fed.append(npc)
		else:
			_starve(npc)
	total_consumption["food"] = fed.size()
	return fed.size()

func _feed(npc) -> void:
	var nd = npc.get("needs")
	if nd:
		nd.eat()
		nd.happiness = min(100.0, nd.happiness + 1.0)
	if npc.get("emotion_sys"): npc.emotion_sys.adjust("幸福", 1.0)
	npc.poverty = max(0.0, npc.poverty - 1.0)
	if npc.get("starve_days") != null:
		npc.starve_days = 0

func _starve(npc) -> void:
	var nd = npc.get("needs")
	if nd:
		nd.hunger = min(nd.hunger, 15.0)
		nd.happiness = max(0.0, nd.happiness - 12.0)
	if npc.get("emotion_sys"):
		npc.emotion_sys.on_event("食物短缺")
	npc.poverty += 1.0
	if npc.get("starve_days") != null:
		npc.starve_days += 1

## 当前连续挨饿 >= 天数的居民名单（供饥荒处理）
func starving_list(residents: Array, threshold: int = 5) -> Array:
	var out: Array = []
	for n in residents:
		if n.get("starve_days") != null and n.starve_days >= threshold:
			out.append(n)
	return out

func money_supply(residents: Array) -> float:
	var s: float = market.cash
	for n in residents:
		s += n.get("money") if n.get("money") != null else 0.0
	for f in _families(residents):
		s += f.family_money
	return s

func _families(residents: Array) -> Array:
	var seen: Array = []
	for n in residents:
		if n.family and n.family not in seen:
			seen.append(n.family)
	return seen

func wealth_stats(residents: Array) -> Dictionary:
	return social_class.wealth_stats(residents)

func employment_rate(residents: Array) -> float:
	return jobs.employment_rate(residents)
