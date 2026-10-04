extends Node
## 军事后勤：战争不能只有攻击力，必须有粮草/装备/士气消耗
## 粮食不足 → 士气下降 → 战力下降

func daily_supply(army, world) -> void:
	if army == null: return
	if army.soldiers <= 0:
		return
	var food_needed: float = army.soldiers * 1.0
	# 先吃军队自带粮草
	if army.food_supply >= food_needed:
		army.food_supply -= food_needed
		return
	# 粮草不足：向国库/市场征用
	var short: float = food_needed - army.food_supply
	army.food_supply = 0.0
	var gov = world.get("civ").get("government") if world and world.get("civ") else null
	if gov and gov.treasury >= short * 2.0:
		gov.treasury -= short * 2.0
		return
	# 征用失败 → 士气下降
	army.morale = maxf(0.0, army.morale - 10.0)
	# 装备每日轻微损耗
	army.equipment = maxf(0.1, army.equipment - 0.002)
	army.recompute_strength()

func recruit_food(army, amount: float) -> void:
	army.food_supply += amount
