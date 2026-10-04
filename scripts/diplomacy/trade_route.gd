extends RefCounted
class_name EdenTradeRoute
## 贸易路线：文明之间固定商品流通。外交恶化会停用（active=false）

var from_civilization: String = ""
var to_civilization: String = ""
var resource: String = ""
var amount_per_day: int = 0
var active: bool = true
var speed_mult: float = 1.0   # 0.19 基础设施：道路/铁路/港口 运输速度倍率

func _init(f: String, t: String, r: String, amt: int) -> void:
	from_civilization = f
	to_civilization = t
	resource = r
	amount_per_day = amt
