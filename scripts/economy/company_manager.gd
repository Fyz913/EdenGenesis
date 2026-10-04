extends Node
## 0.20 企业管理器：企业（Company）拥有员工 / 资金 / 工厂 / 产能。
## 铁律：企业不凭空发钱——月分红来自工厂产出出售的真实收入；
## NPC 归属企业（company_id），但个体日工资仍走 0.12 市场闭环（本系统只加企业层月度结算）。

const ProductionScript: Script = preload("res://scripts/economy/production_manager.gd")

var companies: Dictionary = {}   # id -> {id,name,employees:[npc_id],factories:[factory_id],money,created_year,monthly_revenue}
var company_counter: int = 0

func _ready() -> void:
	pass

func create_company(cname: String, initial_money: float = 100.0) -> String:
	company_counter += 1
	var cid: String = "company_%d" % company_counter
	companies[cid] = {
		"id": cid, "name": cname, "employees": [], "factories": [],
		"money": initial_money, "created_year": _current_year(), "monthly_revenue": 0.0,
	}
	return cid

func get_company(cid: String) -> Dictionary:
	return companies.get(cid, {})

func company_count() -> int:
	return companies.size()

## 企业雇佣居民（按职业归属；不重复）
func hire(npc, cid: String) -> void:
	if npc == null or not companies.has(cid): return
	var comp: Dictionary = companies[cid]
	var npc_id: String = _npc_id(npc)
	if npc_id == "": return
	if npc_id not in comp["employees"]:
		comp["employees"].append(npc_id)
	if npc.get("company_id") == null:
		npc.set("company_id", cid)
	else:
		npc.company_id = cid

## 按职业把居民自动分配到初始企业（world 建村时调用）
func auto_assign(residents: Array, production_mgr) -> void:
	var by_job: Dictionary = {
		"农民": "eden_farm", "农夫": "eden_farm", "渔夫": "eden_farm", "面包师": "eden_farm",
		"伐木工": "eden_wood", "矿工": "eden_stone",
		"铁匠": "eden_iron", "织布工": "eden_farm",
		"商人": "eden_trade",
	}
	# 确保 4 家初始企业存在（world._ready 已建，兜底再建）
	if not companies.has("eden_farm"):
		companies["eden_farm"] = {"id": "eden_farm", "name": "Eden农庄", "employees": [], "factories": [],
			"money": 120.0, "created_year": _current_year(), "monthly_revenue": 0.0}
	if not companies.has("eden_wood"):
		companies["eden_wood"] = {"id": "eden_wood", "name": "Eden林场", "employees": [], "factories": [],
			"money": 90.0, "created_year": _current_year(), "monthly_revenue": 0.0}
	if not companies.has("eden_stone"):
		companies["eden_stone"] = {"id": "eden_stone", "name": "Eden采石场", "employees": [], "factories": [],
			"money": 80.0, "created_year": _current_year(), "monthly_revenue": 0.0}
	if not companies.has("eden_iron"):
		companies["eden_iron"] = {"id": "eden_iron", "name": "Eden铁坊", "employees": [], "factories": [],
			"money": 150.0, "created_year": _current_year(), "monthly_revenue": 0.0}
	if not companies.has("eden_trade"):
		companies["eden_trade"] = {"id": "eden_trade", "name": "Eden商行", "employees": [], "factories": [],
			"money": 200.0, "created_year": _current_year(), "monthly_revenue": 0.0}
	for n in residents:
		if n == null or not is_instance_valid(n): continue
		var job: String = n.get("job") if n.get("job") != null else ""
		var cid: String = str(by_job.get(job, "eden_trade"))
		hire(n, cid)

## 月度结算：工厂产出出售 → 企业收入 → 员工分红。
## 产出按市场价格售出（现金进企业），分红按动态工资发放（现金从企业出）。
## 企业没钱就不分红——杜绝凭空发钱。
func monthly_settle(world, market, residents: Array) -> void:
	var prod_mgr = world.get("production_mgr") if world else null
	var resource_mgr = world.get("resource_mgr") if world else null
	for cid in companies:
		var comp: Dictionary = companies[cid]
		comp["monthly_revenue"] = 0.0
		var factories_of: Array = prod_mgr.factories_of_company(cid) if prod_mgr else []
		# 工厂本月产出（估算）已由 hourly 生产写入资源池；此处按市场价格折算企业收入（会计口径）
		var est_value: float = 0.0
		for f in factories_of:
			var out: String = f["output"]
			var price: float = resource_mgr.base_prices.get(out, 10.0) if resource_mgr else 10.0
			var workers_n: int = f["workers"].size()
			est_value += f["output_qty"] * 6.0 * price * 0.01 * (1.0 + min(1.0, workers_n * 0.05))
		# 收入上限=企业现金池可承受（防止无限膨胀）：实际入账 = 估计值×0.3（保守），并受市场现金约束
		var revenue: float = est_value * 0.3
		if market:
			revenue = min(revenue, market.cash * 0.1)
		comp["monthly_revenue"] = revenue
		# 员工分红：按动态工资 × 工作天数（10 天/月）发放，企业现金不足则少发
		var wage_pool: float = comp["money"] * 0.2
		var total_wage: float = 0.0
		var wages: Dictionary = {}
		for npc in residents:
			if not is_instance_valid(npc): continue
			if npc.get("company_id") != cid: continue
			var w: float = dynamic_wage(npc, market)
			wages[_npc_id(npc)] = w
			total_wage += w
		if total_wage > 0.0:
			var ratio: float = min(1.0, wage_pool / total_wage)
			for npc in residents:
				if not is_instance_valid(npc): continue
				if npc.get("company_id") != cid: continue
				var w: float = wages.get(_npc_id(npc), 0.0) * ratio
				if w > 0.0:
					comp["money"] -= w
					npc.money = npc.money + w
			comp["money"] += revenue

## 动态工资（月度分红基数）：技能效率 × 岗位稀缺 × 企业盈利 × 城市繁荣
func dynamic_wage(npc, market) -> float:
	var base: float = 5.0
	var job: String = npc.get("job") if npc.get("job") != null else ""
	# 与 0.12 工资表对齐（不造第二套基准）
	var job_mgr = get_node_or_null("/root/Main/World")
	if job_mgr and job_mgr.get("economy") and job_mgr.economy.get("jobs"):
		base = job_mgr.economy.jobs.base_salary(job)
	# 技能效率（0.8~1.6）
	var skill_mult: float = 1.0
	if npc.get("skills") != null and npc.get("skill_sys"):
		skill_mult = npc.skill_sys.efficiency(npc.skills, job)
	# 岗位稀缺：市场现金充裕 → 分红溢价；现金紧张 → 压缩
	var market_mult: float = 1.0
	if market:
		market_mult = clampf(market.cash / 1000.0, 0.5, 1.5)
	return base * skill_mult * market_mult

func top_companies(limit: int = 5) -> Array:
	var list: Array = []
	for cid in companies:
		var c: Dictionary = companies[cid]
		list.append({"id": cid, "name": c["name"], "employees": c["employees"].size(),
			"money": c["money"], "factories": c["factories"].size(), "revenue": c["monthly_revenue"]})
	list.sort_custom(func(a, b): return a["money"] > b["money"])
	return list.slice(0, limit)

func total_employee_count() -> int:
	var n: int = 0
	for cid in companies:
		n += companies[cid]["employees"].size()
	return n

func serialize() -> Array:
	var out: Array = []
	for cid in companies:
		var c: Dictionary = companies[cid]
		out.append({
			"id": cid, "name": c["name"], "employees": c["employees"].duplicate(),
			"factories": c["factories"].duplicate(), "money": c["money"],
			"created_year": c["created_year"], "monthly_revenue": c["monthly_revenue"],
		})
	return out

func restore(data: Array) -> void:
	companies.clear(); company_counter = 0
	for item in data:
		if not (item is Dictionary): continue
		var cid: String = str(item.get("id", "company_%d" % (company_counter + 1)))
		companies[cid] = {
			"id": cid, "name": item.get("name", ""),
			"employees": (item.get("employees", []) as Array).duplicate(),
			"factories": (item.get("factories", []) as Array).duplicate(),
			"money": float(item.get("money", 0.0)),
			"created_year": int(item.get("created_year", 1)),
			"monthly_revenue": float(item.get("monthly_revenue", 0.0)),
		}
		company_counter += 1

func _npc_id(npc) -> String:
	if npc == null: return ""
	var v = npc.get("npc_name")
	if v == null: v = npc.get("id")
	return str(v)

func _current_year() -> int:
	var w = get_node_or_null("/root/Main/World")
	if w:
		var e = w.get("ecosystem")
		if e and e.get("season_sys"):
			return e.season_sys.year
	return 1
