extends Node
class_name KnowledgeSystem
## 0.17 文明知识池：不是科技点，而是文明在八领域的真实知识积累。
## 来源：工作经验（个人技能汇总）+ 教育 + 研究组织 + 实验；去向：发明/时代/产出加成。
## 知识会因战争/专家流失而衰减——文明不是永远进步。

const FIELDS := ["agriculture", "construction", "metallurgy", "medicine",
	"mathematics", "engineering", "astronomy", "navigation"]

var knowledge: Dictionary = {}

func _init() -> void:
	for f in FIELDS:
		knowledge[f] = 0.0

func reset() -> void:
	for f in FIELDS:
		knowledge[f] = 0.0

func gain(field: String, amount: float) -> void:
	if not knowledge.has(field): return
	knowledge[field] = clamp(knowledge[field] + amount, 0.0, 100.0)

func get_value(field: String) -> float:
	return knowledge.get(field, 0.0)

## 战争 / 文明崩溃时知识流失（专家死亡、无人继承）
func decay(field: String, amount: float) -> void:
	if not knowledge.has(field): return
	knowledge[field] = clamp(knowledge[field] - amount, 0.0, 100.0)

## 时代判定：不按年份，按真实知识 + 城市条件
func evaluate_era(city, population: int) -> String:
	if knowledge["engineering"] >= 95.0 and knowledge["astronomy"] >= 90.0 and population >= 1000:
		return "星际时代"
	if knowledge["mathematics"] >= 70.0 and population >= 300:
		return "信息时代"
	if knowledge["metallurgy"] >= 60.0 and knowledge["engineering"] >= 40.0 and population >= 100:
		return "工业时代"
	if knowledge["agriculture"] >= 50.0 and city != null:
		return "农业时代"
	return "原始时代"

## 面板摘要：按领域降序
func summary() -> Array:
	var out: Array = []
	for f in FIELDS:
		out.append({"field": f, "value": knowledge[f]})
	out.sort_custom(func(a, b): return a.value > b.value)
	return out
