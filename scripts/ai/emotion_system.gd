extends Node
## 情绪系统：幸福 / 压力 / 恐惧 / 愤怒 / 希望（0-100）

var emotions: Dictionary = {
	"幸福": 60.0, "压力": 10.0, "恐惧": 5.0, "愤怒": 0.0, "希望": 50.0,
}

func adjust(key: String, amount: float) -> void:
	if emotions.has(key):
		emotions[key] = clampf(emotions[key] + amount, 0.0, 100.0)

func mood() -> String:
	if emotions["恐惧"] > 60: return "恐惧"
	if emotions["愤怒"] > 60: return "愤怒"
	if emotions["压力"] > 60: return "焦虑"
	if emotions["幸福"] > 75: return "愉悦"
	if emotions["希望"] > 70: return "充满希望"
	return "平静"

# 事件对情绪的影响
func on_event(kind: String) -> void:
	match kind:
		"结婚", "出生":
			adjust("幸福", 25); adjust("希望", 15); adjust("压力", -10)
		"获得财富", "发现资源":
			adjust("幸福", 15); adjust("希望", 10)
		"食物短缺":
			adjust("幸福", -20); adjust("压力", 30); adjust("恐惧", 10)
		"灾害":
			adjust("恐惧", 40); adjust("压力", 30); adjust("幸福", -20)
		"亲友死亡":
			adjust("幸福", -40); adjust("愤怒", 20); adjust("恐惧", 15)
		"好天气":
			adjust("幸福", 5); adjust("压力", -5)

func daily_decay() -> void:
	# 极端情绪随时间平复
	emotions["愤怒"] = move_toward(emotions["愤怒"], 0.0, 5.0)
	emotions["恐惧"] = move_toward(emotions["恐惧"], 5.0, 3.0)
	emotions["压力"] = move_toward(emotions["压力"], 10.0, 2.0)

func to_dict() -> Dictionary:
	return emotions.duplicate()
