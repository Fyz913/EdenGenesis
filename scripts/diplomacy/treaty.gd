extends RefCounted
class_name EdenTreaty
## 条约：贸易协定 / 和平协定 / 互助协定 / 边境协定

var treaty_type: String = ""
var civilization_a: String = ""
var civilization_b: String = ""
var start_year: int = 0
var duration: int = 10
var active: bool = true

func _init(t: String, a: String, b: String, yr: int) -> void:
	treaty_type = t
	civilization_a = a
	civilization_b = b
	start_year = yr

func is_expired(current_year: int) -> bool:
	return current_year - start_year >= duration
