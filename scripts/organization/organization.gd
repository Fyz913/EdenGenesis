extends RefCounted
class_name EdenOrganization
## 组织：村庄 / 议事会 / 商会 / 职业协会（数据模型）

var id: String = ""
var org_name: String = ""
var members: Array = []
var leader_id: String = ""
var treasury: float = 0.0
var influence: float = 0.0
var goals: Array = []
var founded_year: int = 1

func _init(o_id: String = "", o_name: String = "") -> void:
	id = o_id
	org_name = o_name

func add_member(human_id: String) -> void:
	if not members.has(human_id):
		members.append(human_id)

func remove_member(human_id: String) -> void:
	members.erase(human_id)

func member_count() -> int:
	return members.size()
