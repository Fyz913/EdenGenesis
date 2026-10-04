extends RefCounted
class_name EdenSoldier
## 士兵：绑定居民（military_service=true 的 Human），战死时写人生记忆

var human: Node = null          # 居民引用（null 表示未绑定个体，纯数字兵）
var human_id: String = ""
var civilian_job: String = ""   # 参军前职业（退役后恢复）
var alive: bool = true
