extends RefCounted
class_name WarEvent
## 战争历史事件（0.11 生命记忆 / 0.13 文明历史 共用）

var year: int = 0
var title: String = ""
var description: String = ""
var casualties: int = 0

func line() -> String:
	return "第%d年 %s：%s" % [year, title, description]
