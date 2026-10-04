extends Node
class_name TraditionSystem
## 0.17 传统系统：传统来自真实历史事件——洪水→纪念节、战争→和平纪念日、丰收→感恩节。

var world: Node = null

func bind(w: Node) -> void:
	world = w

## 每年检查历史，把重大事件沉淀为传统（只新增一次）
func yearly_tick(culture, history) -> void:
	if culture == null or history == null: return
	var combined: String = ""
	for ev in history.events:
		combined += " " + str(ev)
	if "洪水" in combined and not culture.traditions.has("纪念洪水节"):
		culture.add_tradition("纪念洪水节")
		culture.add_festival("洪水纪念日", "Spring")
		_record("文化", "Eden 的人们记住了那场洪水，从此有了纪念洪水节")
	if "战争" in combined or "停战" in combined:
		if not culture.traditions.has("和平纪念日"):
			culture.add_tradition("和平纪念日")
			culture.add_festival("和平纪念日", "Autumn")
			_record("文化", "战争远去后，Eden 把那天定为和平纪念日")
	if "丰收" in combined and not culture.traditions.has("秋收感恩"):
		culture.add_tradition("秋收感恩")
		_record("文化", "丰收的记忆化作秋收感恩的传统")

func _record(kind: String, text: String) -> void:
	var civ = world.get("civ") if world else null
	var hist = civ.get("history") if civ else null
	var yr: int = 1
	var eco = world.get("ecosystem") if world else null
	if eco and eco.get("season_sys"): yr = eco.season_sys.year
	if hist: hist.record("第%d年[%s] %s" % [yr, kind, text])
