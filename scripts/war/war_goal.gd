extends RefCounted
class_name EdenWarGoal
## 战争目标（第一阶段四类）

var goal_type: String = "边境争议"

func _init(t: String = "边境争议") -> void:
	goal_type = t

static func all_types() -> Array:
	return ["边境争议", "资源争夺", "防御战争", "领土争夺"]
