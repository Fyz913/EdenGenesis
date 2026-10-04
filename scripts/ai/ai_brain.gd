extends Node
## AI 决策大脑：行为优先级 生命需求 > 家庭 > 工作 > 社交 > 梦想/探索
## 返回动作字符串，兼容现有移动系统（工作/吃饭/睡觉/休息/社交/探索）

func decide(needs: Node, hour: int, personality_sys: Node, emotion_sys: Node) -> String:
	# 1) 生命需求最高优先
	if hour >= 22 or hour < 6:
		return "睡觉"
	if needs and needs.tired():
		return "睡觉"
	if needs and needs.hungry():
		return "吃饭"
	# 2) 情绪崩溃：恐惧/愤怒时回家
	if emotion_sys:
		if emotion_sys.emotions["恐惧"] > 70 or emotion_sys.emotions["愤怒"] > 70:
			return "睡觉"
	# 3) 工作时段
	if hour >= 7 and hour < 18:
		# 社交型人格偶尔去广场聊天
		if personality_sys and personality_sys.traits.get("社交", 50) > 70 and randf() < 0.12:
			return "社交"
		# 好奇型人格偶尔探索
		if personality_sys and personality_sys.traits.get("好奇", 50) > 75 and randf() < 0.08:
			return "探索"
		return "工作"
	# 4) 傍晚社交 / 休息
	if personality_sys and personality_sys.traits.get("社交", 50) > 60 and hour < 21:
		return "社交"
	return "休息"

## 生成一句符合当下状态的内心想法（供对话/UI）
func inner_thought(npc: Node) -> String:
	var hour: int = 12
	var clock = get_node_or_null("/root/Main/WorldTime")
	if clock: hour = clock.get_hour()
	if npc.needs.hungry(): return "肚子好饿，得去市场找点吃的。"
	if hour >= 22 or hour < 6: return "夜深了，该回家睡觉了。"
	if npc.emotion_sys.mood() == "恐惧": return "最近总觉得不太安心……"
	if npc.emotion_sys.emotions["幸福"] > 75: return "今天真是个好日子。"
	if npc.goal_sys and npc.goal_sys.daily_goal != "":
		return "今天打算：" + npc.goal_sys.daily_goal + "。"
	return "日子就这样一天天过着。"
