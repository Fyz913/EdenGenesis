extends RefCounted
class_name PeaceTreaty
## 和平条约：停战后签订，恢复贸易，关系缓慢恢复

var civilization_a: String = ""
var civilization_b: String = ""
var year_signed: int = 0
var duration: int = 10
var active: bool = true

func is_expired(current_year: int) -> bool:
	return current_year - year_signed >= duration
