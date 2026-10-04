extends Node
class_name Family
## 一个家庭：父亲 + 母亲 + 孩子；拥有共同资金与家庭库存

const InventoryScript: Script = preload("res://scripts/economy/inventory.gd")

var family_id: String = ""
var father: Node = null
var mother: Node = null
var children: Array = []

# 0.16 社会：家庭绑定真实住房与城市
var home_id: String = ""
var city_id: String = "eden"

var family_money: float = 60.0
var savings: float = 0.0        # 0.20 家庭储蓄（月度结余沉淀）
var family_inventory

func _init() -> void:
	family_inventory = InventoryScript.new()

func create(f: Node, m: Node, fid: String = "") -> void:
	father = f
	mother = m
	family_id = fid

func add_kid(child: Node) -> void:
	children.append(child)

func get_members() -> Array:
	var list: Array = []
	if father: list.append(father)
	if mother: list.append(mother)
	for c in children:
		list.append(c)
	return list

## 家庭月收入估算：成员日薪基准汇总（复用 job_manager 工资表，不造第二套）
func calculate_income(salary_lookup: Callable) -> float:
	var total: float = 0.0
	for m in get_members():
		if m == null: continue
		if m.job == "孩子": continue
		if m.age < 18: continue
		total += salary_lookup.call(m.job)
	return total
