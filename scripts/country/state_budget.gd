extends Node
class_name StateBudget
## 0.18 国家财政：五类预算（教育/医疗/军事/基建/行政）。
## 铁律：支出=预算真实从国库（gov.treasury）扣款；收入=月度真实税收增量。
## 赤字不破产：连续赤字 → 财政危机 → 削减支出。

var budget: Dictionary = {
	"education": 0.0, "health": 0.0, "military": 0.0,
	"infrastructure": 0.0, "administration": 0.0,
}
var education_fund: float = 0.0    # 教育预算累计（达标建校）
var health_fund: float = 0.0       # 医疗预算累计（达标建诊所）
var infra_fund: float = 0.0        # 基建累计（转城市基建分）
var _last_treasury: float = 0.0    # 上月国库值（算真实收入）
var _last_cash: float = 0.0

## 月度结算：收入（本月国库真实增量）→ 预算分配支出（实扣）→ 赤字判断
func monthly_settle(world, country, gov) -> void:
	var econ = world.get("economy") if world else null
	var income: float = gov.treasury - _last_treasury
	if income < 0.0: income = 0.0
	# 预算按比例分配本月收入（财政纪律：支出 ≤ 收入×1.2，超出即赤字）
	var cap: float = income * 1.2
	var total_budget: float = 0.0
	for k in budget:
		total_budget += budget[k]
	var spend: float = min(total_budget, cap)
	if total_budget > 0.0:
		for k in budget:
			var share: float = budget[k] / total_budget
			var cost: float = spend * share
			_apply_spend(world, country, gov, k, cost)
	# 行政固定支出（即使无收入也要付）
	var admin_cost: float = 20.0
	if gov.treasury >= admin_cost:
		gov.treasury -= admin_cost
		country.expenses += admin_cost
	else:
		gov.treasury = 0.0
	# 记录
	country.income = income
	country.expenses = spend + admin_cost
	_check_deficit(country, income, spend + admin_cost, world)
	_last_treasury = gov.treasury

func _apply_spend(world, country, gov, kind: String, cost: float) -> void:
	if cost <= 0.0: return
	if gov.treasury >= cost:
		gov.treasury -= cost
	else:
		cost = gov.treasury
		gov.treasury = 0.0
	country.expenses += cost
	match kind:
		"education":
			education_fund += cost
			# 每累计 800 → 真实建 1 所学校（城市设施 + 视觉）
			while education_fund >= 800.0:
				education_fund -= 800.0
				_build_facility(world, country, "school")
		"health":
			health_fund += cost
			while health_fund >= 1200.0:
				health_fund -= 1200.0
				_build_facility(world, country, "clinic")
		"military":
			gov.military_budget += cost   # 直接进军费（0.14 后勤使用）
		"infrastructure":
			infra_fund += cost
			var city_mgr = world.get("city_mgr") if world else null
			if city_mgr:
				var city = city_mgr.eden_city()
				if city:
					city.infrastructure = min(100.0, city.infrastructure + cost * 0.01)
		"administration":
			gov.legitimacy = min(100.0, gov.legitimacy + cost * 0.002)

## 公共服务设施：真实写入城市（0.15 设施字段 + 0.16 教育/健康系统消费）
func _build_facility(world, country, kind: String) -> void:
	var city_mgr = world.get("city_mgr") if world else null
	if city_mgr == null: return
	var city = city_mgr.eden_city()
	if city == null: return
	var name: String = ""
	if kind == "school":
		city.schools += 1; name = "学校"
		var expansion = city_mgr.expansion
		if expansion and expansion.has_method("add_era_buildings"):
			expansion.add_era_buildings("school", 1)
	elif kind == "clinic":
		city.clinics += 1; name = "诊所"
		var expansion = city_mgr.expansion
		if expansion and expansion.has_method("add_era_buildings"):
			expansion.add_era_buildings("clinic", 1)
	country.record("第%d年 国家拨款建成%s（教育/医疗预算）" % [_year(world), name])
	_hist(world, "[财政]", "拨款建成" + name + "，公共服务提升")

## 连续赤字 → 财政危机（不破产，逐步削减支出）
func _check_deficit(country, income: float, spend: float, w) -> void:
	if spend > income:
		country.deficit_months += 1
		if country.deficit_months >= 12:
			# 削减 25% 预算
			for k in budget:
				budget[k] *= 0.75
			country.record("第%d年 财政危机：持续赤字，政府削减公共支出 25%%" % [_year(w)])
			_hist(w, "[财政]", "财政危机，削减公共支出")
			country.deficit_months = 0
	else:
		country.deficit_months = maxi(0, country.deficit_months - 1)

## 面板摘要
func summary(country) -> Dictionary:
	return {
		"budget": budget.duplicate(),
		"education_fund": education_fund, "health_fund": health_fund,
		"infra_fund": infra_fund, "deficit_months": country.deficit_months,
	}

func _year(world) -> int:
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"):
		return eco.season_sys.year
	return 1

func _hist(world, kind: String, text: String) -> void:
	var civ = world.get("civ") if world else null
	var hist = civ.get("history") if civ else null
	if hist: hist.record("第%d年[%s] %s" % [_year(world), kind, text])
