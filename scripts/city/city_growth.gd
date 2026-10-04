extends Node
## 城市等级评估（0.15）：按真实条件判定 1-5 级，绝不按年份。
## 否决条件：粮食不足 / 幸福过低 / 基础设施过低 时城市不能升级。

## 评估城市应达到的等级（只升不降，降级会造成世界收缩，本阶段不做）
func evaluate(city) -> int:
	if city == null: return 1
	# 否决条件：食物 < 20、幸福 < 25、基础设施 < 15 → 保持现级
	if city.food_supply < 20.0 or city.happiness < 25.0 or city.infrastructure < 15.0:
		return max(1, city.level)
	var target: int = city.level
	if can_reach_level_5(city): target = 5
	elif can_reach_level_4(city): target = 4
	elif can_reach_level_3(city): target = 3
	elif can_reach_level_2(city): target = 2
	else: target = 1
	return maxi(target, city.level)   # 只升不降

func can_reach_level_2(city) -> bool:
	return city.population >= 25 and city.housing_capacity >= 20 and city.infrastructure >= 20

func can_reach_level_3(city) -> bool:
	return (city.population >= 60 and city.housing_capacity >= 50
		and city.employment_capacity >= 40 and city.infrastructure >= 35
		and city.commercial_buildings >= 2)

func can_reach_level_4(city) -> bool:
	return (city.population >= 150 and city.housing_capacity >= 120
		and city.employment_capacity >= 100 and city.infrastructure >= 60
		and city.commercial_buildings >= 5 and city.public_buildings >= 3)

func can_reach_level_5(city) -> bool:
	return (city.population >= 500 and city.housing_capacity >= 400
		and city.employment_capacity >= 350 and city.infrastructure >= 80
		and city.commercial_buildings >= 10 and city.public_buildings >= 8)
