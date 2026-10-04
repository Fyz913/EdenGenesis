extends RefCounted
class_name Country
## 0.18 国家：文明的政治上层组织（数据层）。
## 铁律：国家不造假账——treasury/tax_rate/legitimacy/government_type 读真实系统
## （government），population 由城市聚合，income/expenses 由财政月度结算记录。

var id: String = ""
var name: String = ""
var civilization_id: String = ""
var capital_city_id: String = ""
var city_ids: Array = []
var founded_year: int = 0
var active: bool = true

# ---- 动态（monthly/yearly 同步真实系统） ----
var population: int = 0          # 由城市聚合
var income: float = 0.0          # 上月真实税收（工资税+贸易税+财产税）
var expenses: float = 0.0        # 上月真实支出（预算实扣）
var deficit_months: int = 0      # 连续赤字月数 → 财政危机
var tax_rate: float = 0.05
var stability: float = 70.0
var legitimacy: float = 50.0
var government_type: String = "部落"
var laws: Array = []             # Law 对象
var political_groups: Array = [] # {id,name,members,power,pressure,demand}
var territory_cells: Array = []  # region_id 列表（由 territory_system 认领）
var revolution_risk: float = 0.0
var history: Array = []          # String 国家历史
const MAX_HISTORY: int = 500

func record(text: String) -> void:
	history.append(text)
	if history.size() > MAX_HISTORY:
		history.pop_front()

## 面板摘要
func summary() -> Dictionary:
	return {
		"id": id, "name": name, "capital_city_id": capital_city_id,
		"city_ids": city_ids.duplicate(), "population": population,
		"income": income, "expenses": expenses, "tax_rate": tax_rate,
		"stability": stability, "legitimacy": legitimacy,
		"government_type": government_type,
		"laws": laws.size(), "groups": political_groups.size(),
		"territory": territory_cells.size(), "founded_year": founded_year,
		"revolution_risk": revolution_risk, "history": history.duplicate(),
	}
