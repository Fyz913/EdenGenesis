extends Node
## 政府：制度类型、领袖、议事会、政策、合法性、财政、军事
## 0.13 扩展：制度由文明条件触发升级（见 politics_system），领袖/议事会由声望推举

var type: String = "部落"
var leader_id: String = ""
var council_members: Array = []
var policies: Array = []
var legitimacy: float = 50.0

var treasury: float = 300.0
var tax_rate: float = 0.05

var soldiers: int = 0
var military_power: float = 5.0
var military_budget: float = 0.0

var political_events: Array = []   # PoliticalEvent 数据类列表

func add_council_member(human_id: String) -> void:
	if not council_members.has(human_id):
		council_members.append(human_id)

## 税收：按收入征税进国库（税率由政策控制）
func collect_tax(income: float) -> float:
	var tax: float = income * tax_rate
	treasury += tax
	return tax
