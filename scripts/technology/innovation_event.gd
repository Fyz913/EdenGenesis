extends RefCounted
class_name InnovationEvent
## 0.17 发明记录：谁、何时、哪个领域、带来什么影响

var invention_name: String = ""
var field: String = ""
var creator: String = ""
var year: int = 0
var effect_text: String = ""
var era_bonus: float = 0.0   # 该领域产出加成（0~1）

func _init(n: String = "", f: String = "", c: String = "", y: int = 0, e: String = "", bonus: float = 0.0) -> void:
	invention_name = n
	field = f
	creator = c
	year = y
	effect_text = e
	era_bonus = bonus

func serialize() -> Dictionary:
	return {
		"name": invention_name, "field": field, "creator": creator,
		"year": year, "effect": effect_text, "bonus": era_bonus,
	}
