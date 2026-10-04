extends RefCounted
class_name PoliticalEvent
## 政治事件数据：年份 / 标题 / 描述

var year: int = 0
var title: String = ""
var description: String = ""

func _init(y: int, t: String, d: String) -> void:
	year = y
	title = t
	description = d

func line() -> String:
	return "第%d年 %s：%s" % [year, title, description]
