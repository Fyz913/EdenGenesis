extends Node
## 多文明世界：管理多个独立文明 + 外交 + 贸易

const CivUnitClass = preload("res://scripts/civilization/civ_unit.gd")

var civs: Array = []
var relations: Dictionary = {}  # key: "A|B" -> -100..100
var _tick: float = 0.0

func _ready() -> void:
	var eden = CivUnitClass.new("Eden", Vector3(0, 0, 0))
	eden.culture = "探索"
	add_civ(eden)
	var north = CivUnitClass.new("北境部落", Vector3(-25, 0, -25))
	north.culture = "狩猎"
	north.resources = {"food": 200.0, "wood": 800.0, "stone": 100.0, "iron": 20.0}
	add_civ(north)
	var desert = CivUnitClass.new("沙漠城邦", Vector3(25, 0, 20))
	desert.culture = "贸易"
	desert.resources = {"food": 150.0, "wood": 50.0, "stone": 400.0, "iron": 150.0}
	add_civ(desert)

	set_relation("Eden", "北境部落", 30)
	set_relation("Eden", "沙漠城邦", 10)
	set_relation("北境部落", "沙漠城邦", -10)

	print("[World] 三个文明已建立")

func add_civ(c: Node) -> void:
	add_child(c)
	civs.append(c)

func set_relation(a: String, b: String, v: int) -> void:
	relations[a + "|" + b] = v
	relations[b + "|" + a] = v

func get_relation(a: String, b: String) -> int:
	return relations.get(a + "|" + b, 0)

func relation_label(a: String, b: String) -> String:
	var v: int = get_relation(a, b)
	if v >= 50: return "友好"
	if v >= 10: return "和睦"
	if v <= -50: return "敌对"
	if v <= -10: return "紧张"
	return "中立"

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 15.0:
		_tick = 0.0
		_yearly_tick()

func _yearly_tick() -> void:
	for c in civs:
		c.grow(1)
		if c.population > 20 and c.technology_level < 2:
			c.technology_level = 2
			c.add_history("进入农业时代")
		if c.population > 50 and c.technology_level < 3:
			c.technology_level = 3
			c.add_history("进入城邦时代")
	# 贸易：Eden 用 food 换 北境 wood，沙漠 stone 换 Eden iron
	_trade("Eden", "北境部落", "food", "wood", 20.0)
	_trade("Eden", "沙漠城邦", "food", "stone", 15.0)

func _trade(a_name: String, b_name: String, out_res: String, in_res: String, amount: float) -> void:
	var a = _find(a_name); var b = _find(b_name)
	if a == null or b == null: return
	if a.resources.get(out_res, 0) < amount: return
	a.resources[out_res] -= amount
	b.resources[out_res] = b.resources.get(out_res, 0) + amount
	b.resources[in_res] = b.resources.get(in_res, 0) - amount
	a.resources[in_res] = a.resources.get(in_res, 0) + amount

func _find(name: String) -> Node:
	for c in civs:
		if c.civ_name == name: return c
	return null
