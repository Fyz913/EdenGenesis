extends Node
## 人生事件系统：在重要时刻为居民生成记忆并改变情绪
## 事件分：普通 / 重要 / 人生 三级

signal life_event_occurred(human_name: String, text: String, level: String)

## 记录一个人生事件到记忆，并作用于情绪
func log_event(memory_sys: Node, emotion_sys: Node, text: String, importance: int, year: int, kind: String) -> void:
	if memory_sys:
		memory_sys.record(text, importance, year, kind)
	if emotion_sys:
		match kind:
			"结婚", "出生":
				emotion_sys.on_event(kind)
			"获得财富", "发现资源":
				emotion_sys.on_event("获得财富")
			"灾害":
				emotion_sys.on_event("灾害")
			"亲友死亡":
				emotion_sys.on_event("亲友死亡")
	emit_signal("life_event_occurred", "", text, kind)

# 预置事件模板
static func birth_event(year: int) -> Dictionary:
	return {"text": "我出生在 Eden 村", "importance": 90, "year": year, "kind": "人生"}

static func marriage_event(spouse_name: String, year: int) -> Dictionary:
	return {"text": "我与%s结为夫妻" % spouse_name, "importance": 85, "year": year, "kind": "人生"}

static func child_birth_event(child_name: String, year: int) -> Dictionary:
	return {"text": "我的孩子%s出生了" % child_name, "importance": 80, "year": year, "kind": "人生"}

static func disaster_event(name: String, year: int) -> Dictionary:
	return {"text": "第%d年的%s，我至今记得" % [year, name], "importance": 75, "year": year, "kind": "灾害"}

static func discovery_event(thing: String, year: int) -> Dictionary:
	return {"text": "我参与了%s" % thing, "importance": 60, "year": year, "kind": "发现资源"}

static func work_event(desc: String, year: int) -> Dictionary:
	return {"text": desc, "importance": 8, "year": year, "kind": "普通"}
