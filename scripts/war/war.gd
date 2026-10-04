extends RefCounted
class_name EdenWar
## 战争对象：交战双方、目标、伤亡、疲劳

var id: String = ""
var attacker: String = ""
var defender: String = ""
var start_year: int = 0
var active: bool = true
var goal_type: String = "边境争议"
var attacker_casualties: int = 0
var defender_casualties: int = 0
var war_exhaustion: float = 0.0
var battle_count: int = 0

func process_day() -> void:
	war_exhaustion += 1.0
