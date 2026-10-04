extends Node
class_name CivUnit
## 一个文明：独立的人口/科技/资源/历史

var civ_name: String = "Eden"
var population: int = 8
var technology_level: int = 1
var culture: String = "未知"
var resources: Dictionary = {"food": 500.0, "wood": 300.0, "stone": 200.0, "iron": 50.0}
var history: Array = []
var home_position: Vector3 = Vector3.ZERO
var npcs: Array = []
var knowledge = null   # 0.17 对手文明知识池（KnowledgeSystem）

func _init(n: String = "Eden", pos: Vector3 = Vector3.ZERO) -> void:
	civ_name = n
	home_position = pos
	history.append("建立聚落")

func grow(n: int = 1) -> void:
	population += n

const MAX_HISTORY: int = 500

func add_history(text: String) -> void:
	history.append(text)
	if history.size() > MAX_HISTORY:
		history.pop_front()
	print("[", civ_name, "] ", text)
