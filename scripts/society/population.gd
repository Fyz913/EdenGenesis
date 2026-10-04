extends Node
class_name Population
## 全村人口

var residents: Array = []

func add(npc: Node) -> void:
	residents.append(npc)

func remove(npc: Node) -> void:
	residents.erase(npc)

func count() -> int:
	return residents.size()
