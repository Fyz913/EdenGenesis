extends RefCounted
class_name PersonModel
## 居民统一数据模型：一个居民的完整身份信息
## 与表现层（npc.gd 的 3D 身体）分离，数据可独立存档/读取。

var person_name: String = ""
var age: int = 0
var birthday_day: int = 1
var gender: String = "男"
var job: String = "村民"
var personality: String = "平和"
var goal: String = "好好生活"
var home_id: String = ""
var workplace_id: String = ""

# 关系引用（运行时）
var spouse_name: String = ""
var family_id: String = ""
var children_names: Array = []
var father_name: String = ""
var mother_name: String = ""

# 状态
var hunger: float = 100.0
var energy: float = 100.0
var happiness: float = 70.0

func _init(data: Dictionary = {}) -> void:
	for k in data:
		if get(k) != null:
			set(k, data[k])

func grow_one_year() -> void:
	age += 1

func is_adult() -> bool:
	return age >= 18

func is_child() -> bool:
	return age < 18

func summary() -> String:
	var rel: String = "未婚" if spouse_name == "" else ("配偶:" + spouse_name)
	return "%s | %d岁 | %s | %s | %s\n目标: %s" % [
		person_name, age, job, personality, rel, goal
	]

func to_dict() -> Dictionary:
	return {
		"name": person_name, "age": age, "birthday": birthday_day,
		"gender": gender, "job": job, "personality": personality,
		"goal": goal, "home": home_id, "work": workplace_id,
		"spouse": spouse_name, "family": family_id,
		"children": children_names, "father": father_name, "mother": mother_name,
	}
