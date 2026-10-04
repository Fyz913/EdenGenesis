extends RefCounted
class_name AdminDistrict
## 0.19 行政区数据：省级以下的治理单元（一个城市一个区）。
## 行政能力 = 政府能力 + 道路 + 教育 + 官员能力 - 距离（真实计算）。

var id: String = ""
var name: String = ""
var province_id: String = ""
var city_id: String = ""
var admin_capacity: float = 50.0    # 行政能力 0~100
var corruption: float = 0.0         # 腐败率 0~1
var distance_to_capital: float = 0.0 # 距首都距离（米）
var governor_id: String = ""

func _init(i: String = "", n: String = "", pid: String = "", cid: String = "") -> void:
	id = i
	name = n
	province_id = pid
	city_id = cid

func serialize() -> Dictionary:
	return {
		"id": id, "name": name, "province_id": province_id, "city_id": city_id,
		"admin_capacity": admin_capacity, "corruption": corruption,
		"distance_to_capital": distance_to_capital, "governor_id": governor_id,
	}
