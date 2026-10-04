extends Node
class_name EducationSystem
## 0.16 教育系统：学校设施 → 儿童入学 → 教育值 → 更高效率/工资
## 学校不是装饰：每月消耗财政（教师工资+维护），教师支出进入国库账本

var world: Node = null

func bind(w: Node) -> void:
	world = w

## 每月结算
func monthly_tick(residents: Array, city, gov) -> Dictionary:
	var schools: int = city.schools if city else 0
	var enrolled: int = 0
	for n in residents:
		if n.age < 15 and n.job == "孩子":
			if schools > 0 and n.school_years < 12:
				n.school_years += 1
				enrolled += 1
			n.education = clamp(n.school_years * 8.0, 0.0, 100.0)
	# 学校财政支出（教师工资+维护费）：进入真实财政账本
	var cost: float = 0.0
	if gov and schools > 0:
		cost = schools * 5.0
		if gov.treasury >= cost:
			gov.treasury -= cost
	return {"enrolled": enrolled, "school_cost": cost}

## 教育率（面板用）：成年居民中 education > 30 的比例
func education_rate(residents: Array) -> float:
	var adults: int = 0
	var edu: int = 0
	for n in residents:
		if n.age < 18: continue
		adults += 1
		if n.education > 30.0: edu += 1
	if adults == 0: return 0.0
	return edu * 100.0 / adults
