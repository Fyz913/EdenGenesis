extends Node
## 记忆系统：带年份与重要度的记忆；普通记忆会被遗忘，重要/人生记忆永久保留

# 每条：{event, importance(1-100), year, kind}
var memories: Array = []
const FORGET_BELOW := 20   # 重要度低于此且为普通记忆会随时间遗忘

func record(event_text: String, importance: int = 10, year: int = 1, kind: String = "普通") -> void:
	memories.append({
		"event": event_text, "importance": importance, "year": year, "kind": kind
	})
	# 控制记忆数量，遗忘最不重要的普通记忆
	if memories.size() > 40:
		_prune()

func _prune() -> void:
	# 按重要度升序，删除普通且低分的
	var trivial: Array = []
	for i in range(memories.size()):
		if memories[i].kind == "普通" and memories[i].importance < FORGET_BELOW:
			trivial.append(i)
	trivial.reverse()
	for i in trivial:
		memories.remove_at(i)
		if memories.size() <= 30: break

## 每年：普通记忆重要度衰减（逐渐遗忘）
func yearly_decay() -> void:
	for m in memories:
		if m.kind == "普通":
			m.importance = max(0, m.importance - 2)
	_prune()

## 最重要的若干条记忆（人生记忆优先）
func top(n: int = 3) -> Array:
	var sorted := memories.duplicate()
	sorted.sort_custom(func(a, b): return a.importance > b.importance)
	var out: Array = []
	for i in range(mini(n, sorted.size())):
		out.append(sorted[i])
	return out

func recall_about(keyword: String) -> Dictionary:
	for m in memories:
		if keyword in m.event:
			return m
	return {}

func count() -> int:
	return memories.size()
