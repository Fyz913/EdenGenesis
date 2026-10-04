extends RefCounted
class_name Law
## 0.18 法律数据：类别 + 启用状态 + 真实效果表
## （labor→幸福/稳定、tax→税率上限、property/trade→倍率、military→征兵比例）

var id: String = ""
var name: String = ""
var category: String = ""
var enabled: bool = true
var effects: Dictionary = {}

func _init(i: String = "", n: String = "", cat: String = "", on: bool = true, ef: Dictionary = {}) -> void:
	id = i
	name = n
	category = cat
	enabled = on
	effects = ef

func serialize() -> Dictionary:
	return {"id": id, "name": name, "category": category, "enabled": enabled, "effects": effects.duplicate()}
