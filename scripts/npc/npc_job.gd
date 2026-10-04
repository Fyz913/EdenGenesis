extends Node
## NPC 职业：0.06 先占位，0.07 接经济系统

var job: String = "村民"
var home_position: Vector3 = Vector3.ZERO
var work_position: Vector3 = Vector3.ZERO
var food_position: Vector3 = Vector3.ZERO

func work_at() -> Vector3:
	return work_position

func home_at() -> Vector3:
	return home_position

func food_at() -> Vector3:
	return food_position
