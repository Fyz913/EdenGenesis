extends Node
class_name TaxSystem
## 0.18 税收系统：三类税全部真实入国库（gov.treasury），有真实经济代价。
## 工资税：已在 0.13 经济中按 gov.tax_rate 从工资实扣（此处仅统计）。
## 贸易税：从市场现金按税率×0.5 实抽（伤市场流动性 → 工资发放能力下降）。
## 财产税：从家庭共同钱包按税率×0.3 实抽（伤家庭财富 → 消费能力下降）。
## 税率提高 → 国库增收，但居民可支配/市场流动下降 → 政府必须取舍。

var last_income_tax: float = 0.0
var last_trade_tax: float = 0.0
var last_property_tax: float = 0.0
var _last_treasury: float = 0.0

## 月度：结算三税（当月国库真实增量统计 + 贸易/财产税实抽）
func monthly_collect(world, country, gov) -> void:
	var econ = world.get("economy") if world else null
	var market = econ.market if econ else null
	var society = world.get("society") if world else null
	# 1) 工资税 = 本月国库增量（由 0.13 经济按税率实扣产生）
	var treasury_gain: float = gov.treasury - _last_treasury
	last_income_tax = treasury_gain if treasury_gain > 0.0 else 0.0
	# 2) 贸易税：从市场现金抽税率×0.5（上限 20% 现金，防止抽干市场）
	if market:
		var trade_tax: float = market.cash * gov.tax_rate * 0.5
		trade_tax = min(trade_tax, market.cash * 0.2)
		market.cash -= trade_tax
		gov.treasury += trade_tax
		last_trade_tax = trade_tax
	# 3) 财产税：从家庭共同钱包抽税率×0.3（每户）
	if society:
		var prop_tax: float = 0.0
		for fam in society.families:
			var t: float = fam.family_money * gov.tax_rate * 0.3
			t = min(t, fam.family_money * 0.15)
			fam.family_money -= t
			prop_tax += t
		gov.treasury += prop_tax
		last_property_tax = prop_tax
	var total: float = last_income_tax + last_trade_tax + last_property_tax
	country.record("第%d年 税收结算：工资税 %d + 贸易税 %d + 财产税 %d = %d" % [
		_year(world), int(last_income_tax), int(last_trade_tax), int(last_property_tax), int(total)])
	_last_treasury = gov.treasury

## 调整税率（政策入口，限幅防爆）
func set_tax_rate(gov, rate: float) -> void:
	gov.tax_rate = clampf(rate, 0.02, 0.25)

## 面板摘要
func summary() -> Dictionary:
	return {
		"income_tax": last_income_tax, "trade_tax": last_trade_tax,
		"property_tax": last_property_tax,
	}

func _year(world) -> int:
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"):
		return eco.season_sys.year
	return 1
