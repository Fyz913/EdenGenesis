extends RefCounted
## 城区数据（0.15）：城市内部的区域划分。
## 类型：residential / commercial / industrial / agricultural / government / military

var id: String = ""
var city_id: String = ""
var district_type: String = "residential"
var center: Vector3 = Vector3.ZERO
var radius: float = 15.0
var buildings: Array = []
var population: int = 0
var jobs: int = 0

func type_name() -> String:
	match district_type:
		"residential": return "住宅区"
		"commercial": return "商业区"
		"industrial": return "工业区"
		"agricultural": return "农业区"
		"government": return "行政区"
		"military": return "军事区"
	return district_type
