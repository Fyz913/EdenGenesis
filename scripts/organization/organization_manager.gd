extends Node
## 组织管理器：创建并维护村庄内各组织（村庄/议事会/商会/职业协会）

const OrganizationScript: Script = preload("res://scripts/organization/organization.gd")

var organizations: Dictionary = {}

## 创建组织；若已存在直接返回
func create_organization(id: String, name: String):
	if organizations.has(id):
		return organizations[id]
	var org = OrganizationScript.new(id, name)
	organizations[id] = org
	print("[Org] 成立组织：", name)
	return org

func get_organization(id: String):
	return organizations.get(id, null)

func org_member_count(id: String) -> int:
	var org = organizations.get(id, null)
	return org.member_count() if org else 0

## 把居民加入组织（幂等）
func join(org_id: String, member_name: String) -> void:
	var org = organizations.get(org_id, null)
	if org:
		org.add_member(member_name)

## 村社成立后创建议事会组织
func establish_council(member_names: Array) -> void:
	var council = create_organization("council", "议事会")
	for n in member_names:
		council.add_member(n)
