extends Node
## NPC 大脑：需求优先，其次按日程时刻表决定行为
## 06 起床 / 07-18 工作 / 12 吃饭 / 18 回家 / 22 睡觉

func decide(needs: Node, hour: int) -> String:
	# 深夜：睡觉
	if hour >= 22 or hour < 6:
		return "睡觉"
	# 生理需求优先
	if needs.tired():
		return "睡觉"
	if needs.hungry():
		return "吃饭"
	# 工作时段
	if hour >= 7 and hour < 18:
		return "工作"
	# 傍晚到睡前：回家休息
	return "休息"
