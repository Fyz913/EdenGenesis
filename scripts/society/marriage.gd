extends Node
## 婚姻规则（静态工具方法）

static func can_marry(npc1: Node, npc2: Node) -> bool:
	if npc1.get("age") == null or npc2.get("age") == null: return false
	if npc1.age < 18 or npc2.age < 18: return false
	if npc1.get("spouse") != null or npc2.get("spouse") != null: return false
	if npc1 == npc2: return false
	return true

static func marry(npc1: Node, npc2: Node) -> bool:
	if can_marry(npc1, npc2):
		npc1.spouse = npc2
		npc2.spouse = npc1
		return true
	return false
