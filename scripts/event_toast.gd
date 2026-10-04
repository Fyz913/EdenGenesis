extends CanvasLayer
## 世界事件弹窗（屏幕中央上方）

@onready var toast_label: Label = %ToastLabel
var _queue: Array = []
var _visible_time: float = 0.0

func _ready() -> void:
	toast_label.visible = false

func show_event(icon: String, text: String) -> void:
	_queue.append({"icon": icon, "text": text, "time": 3.5})

func _process(delta: float) -> void:
	if _visible_time > 0:
		_visible_time -= delta
		if _visible_time <= 0:
			toast_label.visible = false
	elif not _queue.is_empty():
		var e = _queue.pop_front()
		toast_label.text = e.icon + "  " + e.text
		toast_label.visible = true
		_visible_time = e.time
