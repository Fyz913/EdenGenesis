extends Node
## 文化（0.16 扩展：传统 / 节日 / 价值观；0.17：语言 / 信念）

var values: Array = []
var traditions: Array = []   # 习俗传统
var festivals: Array = []    # 节日列表 {name, season}
var language: String = "Eden语"   # 0.17 语言
var beliefs: Dictionary = {"war": 10.0, "trade": 30.0, "knowledge": 40.0}   # 0.17 价值观三轴 0-100

func create_value(text: String) -> void:
	if text not in values:
		values.append(text)

func add_tradition(text: String) -> void:
	if text not in traditions:
		traditions.append(text)

func add_festival(name: String, season: String) -> void:
	for f in festivals:
		if f.get("name") == name: return
	festivals.append({"name": name, "season": season})

func has_value(text: String) -> bool:
	return text in values

func adjust_belief(key: String, amount: float) -> void:
	if beliefs.has(key):
		beliefs[key] = clamp(beliefs[key] + amount, 0.0, 100.0)
