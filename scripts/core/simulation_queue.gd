extends Node
## 0.19.7 模拟队列：批量处理基础设施（AI/城市/经济等低频任务分批执行）。
## 使用游标轮转（index cursor），避免在大数组上反复 pop_front() 的 O(n) 搬移。
## 用法：queue.add(item) → 每帧/每 tick 调用 process_batch(max_count)，
## 每次只处理最多 max_count 个，未处理完的下一批继续。

var _items: Array = []
var _cursor: int = 0

func add(item) -> void:
	if item != null and not _items.has(item):
		_items.append(item)

func remove(item) -> void:
	_items.erase(item)

func size() -> int:
	return _items.size()

func is_empty() -> bool:
	return _items.size() == 0

## 处理一批（环形游标）：返回本批实际处理数
func process_batch(max_count: int) -> int:
	if _items.is_empty() or max_count <= 0:
		return 0
	var done: int = 0
	while done < max_count and _items.size() > 0:
		if _cursor >= _items.size():
			_cursor = 0
			if _items.size() == 0:
				break
		var item = _items[_cursor]
		_cursor += 1
		done += 1
		if is_instance_valid(item) and item.has_method("simulate"):
			item.simulate()
	return done

func clear() -> void:
	_items.clear()
	_cursor = 0
