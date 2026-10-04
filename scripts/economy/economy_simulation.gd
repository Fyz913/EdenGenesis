extends Node
## 0.20 经济总循环编排 + 经济统计（GDP / 城市经济 / 家庭储蓄）。
## 分层模拟（低频，绝不每帧）：
##   小时 → 企业工厂生产（production_manager.run_all）
##   每天 → 供需采集 + 价格调整（market_manager）
##   每月 → 企业月结（分红）+ 区域贸易 + 银行结算
##   每年 → 产业升级（按文明时代解锁工厂类型）
## 铁律：GDP 等统计全部来自真实系统（工资 + 企业收入 + 贸易额），禁止造假。

var gdp: float = 0.0
var last_gdp: float = 0.0
var city_economy: Dictionary = {}   # city_id -> {gdp, jobs, industry, wealth, avg_salary, food_supply}
var family_savings: Dictionary = {} # family_id -> {savings, monthly_income, monthly_expense}
var industry_level: float = 10.0    # 工业指数（0~100）
var agriculture_level: float = 20.0 # 农业指数
var _unlock_log: Array = []         # 已解锁工厂类型（防每年重复建厂）

## 小时：工厂生产（世界正常速度下 1 小时 ≈ 1.5 现实秒，频率低）
func hourly_tick(world) -> void:
	var prod_mgr = world.get("production_mgr") if world else null
	var resource_mgr = world.get("resource_mgr") if world else null
	if prod_mgr and resource_mgr:
		prod_mgr.run_all(resource_mgr)

## 每天：供需采集 + 价格调整（在市场原价逻辑之上叠加供需指数）
func daily_tick(world, market, residents: Array) -> void:
	var market_mgr = world.get("market_mgr") if world else null
	if market_mgr:
		market_mgr.daily_update(market, residents, world)
		market_mgr.apply_price_adjust(market)

## 每月：企业分红结算 + 区域贸易统计 + 银行结算 + 家庭储蓄沉淀
func monthly_tick(world, market, residents: Array) -> void:
	var company_mgr = world.get("company_mgr") if world else null
	var trade_mgr = world.get("trade_mgr") if world else null
	var finance_mgr = world.get("finance_mgr") if world else null
	if company_mgr:
		company_mgr.monthly_settle(world, market, residents)
	if trade_mgr:
		trade_mgr.daily_tick(world)   # 区域物流每日推进，月度只做统计入口
	if finance_mgr:
		finance_mgr.monthly_tick()
	_save_family_savings(world)
	_compute_gdp(world, residents)

## 每年：产业升级（按时代解锁工厂）+ 经济指数演化
func yearly_tick(world) -> void:
	var tech_mgr = world.get("tech_mgr") if world else null
	var era: String = tech_mgr.current_era if tech_mgr else "原始时代"
	var prod_mgr = world.get("production_mgr") if world else null
	var company_mgr = world.get("company_mgr") if world else null
	if prod_mgr == null or company_mgr == null: return
	# 铁器时代（冶金知识达标）：解锁铁坊 → 可建炼钢厂
	if (era.contains("农业") or era.contains("铁器")) and "smithy" not in _unlock_log:
		_build_for_company(prod_mgr, company_mgr, "Eden铁坊炼钢厂", "eden_iron", "smithy")
	# 工业时代：机器工坊
	if era.contains("工业") and "machine_shop" not in _unlock_log:
		_build_for_company(prod_mgr, company_mgr, "Eden机器工坊", "eden_iron", "machine_shop")
	# 信息时代：电子实验室
	if era.contains("信息") and "electronics_lab" not in _unlock_log:
		_build_for_company(prod_mgr, company_mgr, "Eden电子实验室", "eden_trade", "electronics_lab")
	# 指数演化：工业 = 工厂数驱动的真实值
	if prod_mgr:
		industry_level = min(100.0, 10.0 + prod_mgr.factory_count() * 6.0)

func _build_for_company(prod_mgr, company_mgr, fname: String, cid: String, ftype: String) -> void:
	var factory: Dictionary = prod_mgr.create_factory(fname, cid, ftype)
	var comp: Dictionary = company_mgr.get_company(cid)
	if not comp.is_empty():
		comp["factories"].append(factory["id"])
	_unlock_log.append(ftype)

## 家庭储蓄：每月收入-支出的结余沉淀（家庭经济 0.20）
func _save_family_savings(world, residents: Array = []) -> void:
	var society = world.get("society") if world else null
	if society == null or society.get("families") == null: return
	var fams: Array = society.families
	for fam in fams:
		var fid: String = fam.family_id if fam.get("family_id") != null else "fam"
		var cur: Dictionary = family_savings.get(fid, {"savings": 0.0, "monthly_income": 0.0, "monthly_expense": 0.0})
		# 家庭月收入估算 = 成员日薪基准 × 工作 10 天
		var income: float = fam.calculate_income(func(job): return _base_salary_fallback(world, job)) * 10.0
		var expense: float = 40.0 + float(fam.get_members().size()) * 8.0
		var surplus: float = income - expense
		cur["monthly_income"] = income
		cur["monthly_expense"] = expense
		cur["savings"] = max(0.0, cur["savings"] + surplus * 0.3)
		family_savings[fid] = cur

func _base_salary_fallback(world, job: String) -> float:
	var e = world.get("economy") if world else null
	if e and e.get("jobs"):
		return e.jobs.base_salary(job)
	return 5.0

## GDP 估算（月口径）：工资池（居民总收入）+ 企业月收入 + 贸易额
func _compute_gdp(world, residents: Array) -> void:
	last_gdp = gdp
	var wages: float = 0.0
	for n in residents:
		if is_instance_valid(n):
			wages += n.money * 0.05   # 存量财富的月流转估算
	var company_mgr = world.get("company_mgr") if world else null
	var company_income: float = 0.0
	if company_mgr:
		for cid in company_mgr.companies:
			company_income += company_mgr.companies[cid]["monthly_revenue"]
	var trade_mgr = world.get("trade_mgr") if world else null
	var trade_vol: float = trade_mgr.stats()["volume_per_month"] * 8.0 if trade_mgr else 0.0
	gdp = max(0.0, wages + company_income + trade_vol)

## 城市经济统计（真实聚合）
func compute_city_stats(world, city_mgr, market, residents: Array) -> Dictionary:
	var out: Dictionary = {}
	if city_mgr == null or residents.size() == 0:
		return out
	var city = city_mgr.eden_city() if city_mgr.has_method("eden_city") else null
	if city == null: return out
	var workers: int = 0
	var wages_total: float = 0.0
	var wealth_total: float = 0.0
	for n in residents:
		if not is_instance_valid(n): continue
		if n.get("age") >= 18 and n.get("job") != "孩子":
			workers += 1
		wages_total += n.money
		wealth_total += n.money
		if n.get("family") and n.family:
			wealth_total += n.family.family_money
	var avg_salary: float = wages_total / max(1, workers)
	var food_ok: float = 100.0
	if market:
		var need: float = float(residents.size())
		food_ok = clampf(100.0 * market.stock.get("food", 0.0) / max(1.0, need), 0.0, 100.0)
	var jobs_ratio: float = clampf(100.0 * float(workers) / float(residents.size()), 0.0, 100.0)
	out = {
		"city_id": city.id, "population": city.population,
		"gdp": gdp, "jobs": workers, "industry": industry_level,
		"wealth": wealth_total, "avg_salary": avg_salary,
		"food_supply": food_ok, "employment": jobs_ratio,
	}
	city_economy[city.id] = out
	return out

func stats(world, city_mgr, market, residents: Array) -> Dictionary:
	var company_mgr = world.get("company_mgr") if world else null
	var trade_mgr = world.get("trade_mgr") if world else null
	var finance_mgr = world.get("finance_mgr") if world else null
	var prod_mgr = world.get("production_mgr") if world else null
	compute_city_stats(world, city_mgr, market, residents)
	return {
		"gdp": gdp,
		"companies": company_mgr.company_count() if company_mgr else 0,
		"employees": company_mgr.total_employee_count() if company_mgr else 0,
		"factories": prod_mgr.factory_count() if prod_mgr else 0,
		"trade_volume": trade_mgr.trade_volume if trade_mgr else 0.0,
		"routes": trade_mgr.active_routes_count() if trade_mgr else 0,
		"bank_cash": finance_mgr.bank_cash if finance_mgr else 0.0,
		"loans": finance_mgr.loans.size() if finance_mgr else 0,
		"industry": industry_level, "agriculture": agriculture_level,
		"families_saved": family_savings.size(),
		"city": city_economy.get("city_1", {}),
	}
