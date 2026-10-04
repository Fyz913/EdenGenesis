extends RefCounted
class_name MilitaryUnit
## 军事单位：一支军队的组成单元（训练等级、所属士兵）
## 第一阶段：每军一个单位，后续可拆分

var unit_id: String = ""
var army_id: String = ""
var training_level: int = 1
var capacity: int = 10
var soldier_ids: Array = []

func add_soldier(sid: String) -> void:
	if not soldier_ids.has(sid):
		soldier_ids.append(sid)

func count() -> int:
	return soldier_ids.size()
