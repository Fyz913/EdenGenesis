extends RefCounted
class_name EdenRelation
## 外交关系：-100（敌对）～ +100（盟友）

var civilization_a: String = ""
var civilization_b: String = ""
var value: float = 0.0
var trade_allowed: bool = false
var alliance: bool = false
var war: bool = false

func _init(a: String, b: String, v: float) -> void:
	civilization_a = a
	civilization_b = b
	value = clampf(v, -100.0, 100.0)
	_update_flags()

func adjust(delta: float) -> void:
	value = clampf(value + delta, -100.0, 100.0)
	_update_flags()

func _update_flags() -> void:
	trade_allowed = value >= -30.0
	alliance = value >= 60.0
	war = value <= -60.0

func level_label() -> String:
	if value <= -60: return "敌对"
	if value <= -30: return "紧张"
	if value <= 10: return "冷淡"
	if value <= 30: return "中立"
	if value <= 60: return "友好"
	return "盟友"
