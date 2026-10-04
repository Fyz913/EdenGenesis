extends Node
class_name Relationship
## 记录 NPC 对他人的好感度

var relations: Dictionary = {}

func set_relation(person: String, value: int) -> void:
	relations[person] = value

func add_relation(person: String, value: int) -> void:
	relations[person] = relations.get(person, 0) + value

func get_relation(person: String) -> int:
	return relations.get(person, 0)

func get_level(person: String) -> String:
	var v: int = get_relation(person)
	if v >= 80: return "亲密"
	elif v >= 40: return "朋友"
	elif v <= -30: return "敌对"
	return "陌生"
