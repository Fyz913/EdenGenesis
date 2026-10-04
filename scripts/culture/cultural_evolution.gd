extends Node
class_name CulturalEvolution
## 0.17 文化演化总指挥：传统沉淀 + 语言分化 + 价值观漂移，每年一次。

var world: Node = null
var tradition_sys: Node
var language_sys: Node
var belief_sys: Node

func _init() -> void:
	tradition_sys = load("res://scripts/culture/tradition_system.gd").new()
	language_sys = load("res://scripts/culture/language_system.gd").new()
	belief_sys = load("res://scripts/culture/belief_system.gd").new()
	add_child(tradition_sys)
	add_child(language_sys)
	add_child(belief_sys)

func bind(w: Node) -> void:
	world = w
	tradition_sys.bind(w)
	language_sys.bind(w)
	belief_sys.bind(w)

func yearly_tick(civ, diplomacy) -> void:
	if civ == null: return
	tradition_sys.yearly_tick(civ.culture, civ.history)
	language_sys.yearly_tick(civ.culture, diplomacy)
	belief_sys.yearly_tick(civ.culture, civ.history)
