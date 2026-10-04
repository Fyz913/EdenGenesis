extends Node
## 目标系统：人生梦想（长期）+ 今日目标（短期）

var life_dream: String = "好好生活"
var daily_goal: String = ""

func setup(job: String, age: int, archetype: String) -> void:
	life_dream = _dream_for(job)
	if age < 18:
		life_dream = "快快长大，了解这个世界"
	daily_goal = _daily_for(job, age)

func _dream_for(job: String) -> String:
	match job:
		"铁匠": return "打造出村里最好的铁器，开一间自己的铁匠铺"
		"农夫", "农民": return "拥有一片丰收的农场"
		"渔夫": return "在河边安稳度日，养大孩子"
		"商人": return "把商路通到沙漠城邦，成为最富有的人"
		"面包师": return "让全村都吃上我的热面包"
		"织布工": return "织出整个 Eden 最漂亮的布"
	return "守护家人，平静生活"

func _daily_for(job: String, age: int) -> String:
	if age < 18: return ["在村里玩耍", "跟在父母身边学习", "和小伙伴探索村庄"].pick_random()
	match job:
		"铁匠": return ["打好今天的农具", "修缮铁匠铺的炉子", "攒铁料"].pick_random()
		"农夫", "农民": return ["照顾农田", "给作物浇水", "收割成熟的庄稼"].pick_random()
		"渔夫": return ["去河边捕鱼", "修补渔网", "晾晒鱼干"].pick_random()
		"商人": return ["去市场做生意", "和外来商队交易", "清点货物"].pick_random()
		"面包师": return ["烤今天的面包", "准备面粉", "给大家送面包"].pick_random()
		"织布工": return ["织布", "染线", "给家人做新衣"].pick_random()
	return "帮村里干活"

func new_day(job: String, age: int) -> void:
	daily_goal = _daily_for(job, age)
