extends Node
class_name SkillSystem
## 0.17 个人技能：不是等级，是重复行为 + 教育 + 导师传授的积累。
## 技能 → 个人产出效率；技能汇总 → 文明知识池；高龄高技者传授下一代（传承）。

## 职业 → 主技能领域
const JOB_FIELD := {
	"农民": "farming", "农夫": "farming", "渔夫": "farming",
	"伐木工": "building", "矿工": "mining", "铁匠": "smithing",
	"织布工": "crafting", "面包师": "crafting", "商人": "trade",
	"孩子": "learning",
}

## 主技能领域 → 对应文明知识池字段
const FIELD_TO_KNOWLEDGE := {
	"farming": "agriculture", "building": "construction",
	"smithing": "metallurgy", "mining": "construction",
	"crafting": "engineering", "medicine": "medicine",
	"trade": "navigation", "learning": "mathematics",
}

## 按职业初始化技能（个人差异随机）
func init_skills(job: String, age: int) -> Dictionary:
	var s: Dictionary = {}
	var field: String = JOB_FIELD.get(job, "learning")
	var base: float = 20.0 + randf() * 20.0
	if age >= 30: base += (age - 30) * 0.8   # 年长者经验更足
	s[field] = clamp(base, 0.0, 100.0)
	# 一两个次要技能
	for extra in ["farming", "building", "smithing", "crafting", "medicine"]:
		if extra == field: continue
		if randf() < 0.4:
			s[extra] = randf_range(5.0, 25.0)
	return s

## 每日经验：工作积累（教育加成 + 研究组织加成由技术总管处理）
func work_gain(skills: Dictionary, job: String, education: float) -> Dictionary:
	var field: String = JOB_FIELD.get(job, "learning")
	var gain: float = 0.02 + education * 0.0002
	if not skills.has(field):
		skills[field] = 0.0
	skills[field] = clamp(skills[field] + gain, 0.0, 100.0)
	return {"field": field, "gain": gain}

## 导师传授：master 技能转移 20% 给学生
func teach(master_skills: Dictionary, student_skills: Dictionary, field: String) -> float:
	if not master_skills.has(field): return 0.0
	var transfer: float = master_skills[field] * 0.2 * 0.05   # 单次传授为 5% 的 20%
	if not student_skills.has(field):
		student_skills[field] = 0.0
	student_skills[field] = clamp(student_skills[field] + transfer, 0.0, 100.0)
	return transfer

## 技能 → 个人产出效率倍率（0.8 ~ 1.6）
func efficiency(skills: Dictionary, job: String) -> float:
	var field: String = JOB_FIELD.get(job, "learning")
	var v: float = skills.get(field, 10.0)
	return clamp(0.8 + v * 0.008, 0.8, 1.6)

## 个人技能 → 文明知识池（文明层调用：汇总平均值）
## 0.19.1 系数 0.0005→0.004：百人规模下每月每域 +2~4，数十个月内可见时代跃迁（非造假，仍由工作真实产出）
func contribute_to_knowledge(skills: Dictionary, job: String) -> Dictionary:
	var field: String = JOB_FIELD.get(job, "learning")
	var know_field: String = FIELD_TO_KNOWLEDGE.get(field, "mathematics")
	var v: float = skills.get(field, 0.0)
	return {"field": know_field, "amount": v * 0.004}
