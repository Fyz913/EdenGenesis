extends RefCounted
class_name EdenCouncil
## 议事会：成员 + 待决事项 + 投票（第一阶段：简单多数）

var members: Array = []
var pending_decisions: Array = []

func add_member(human_id: String) -> void:
	if not members.has(human_id):
		members.append(human_id)

func propose_decision(decision) -> void:
	pending_decisions.append(decision)

func vote(supporters: int, opponents: int) -> bool:
	return supporters > opponents
