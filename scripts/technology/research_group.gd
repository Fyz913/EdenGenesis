extends Node
class_name ResearchGroup
## 0.17 研究组织：把 0.13 的职业组织升级为"研究团体"——
## 成员是真实居民（来自 org_mgr），组织专注领域使文明知识获取 +20%。
## 早期对应：工匠协会 / 农民协会 / 商会（祭司/学者留待后世）。

var groups: Array = []   # [{org_id, org_name, field, bonus}]

func _init() -> void:
	groups = [
		{"org_id": "crafts_guild", "org_name": "工匠协会", "field": "metallurgy", "bonus": 0.2},
		{"org_id": "farmers_guild", "org_name": "农民协会", "field": "agriculture", "bonus": 0.2},
		{"org_id": "merchant_guild", "org_name": "商会", "field": "navigation", "bonus": 0.15},
	]

## 知识获取加成：若存在研究组织专注该领域（且成员>0）→ 1+bonus
func bonus_for(field: String, org_mgr) -> float:
	var mult: float = 1.0
	for g in groups:
		if g.field != field: continue
		var org = org_mgr.get_organization(g.org_id) if org_mgr and org_mgr.has_method("get_organization") else null
		var members: int = org.member_count() if org else 0
		if members > 0:
			mult += g.bonus
	return mult

## 面板摘要
func summary(org_mgr) -> Array:
	var out: Array = []
	for g in groups:
		var org = org_mgr.get_organization(g.org_id) if org_mgr and org_mgr.has_method("get_organization") else null
		out.append({
			"name": g.org_name, "field": g.field,
			"members": org.member_count() if org else 0,
			"bonus": int(g.bonus * 100),
		})
	return out
