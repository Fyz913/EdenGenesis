extends Node
## 0.19.7 历史分层：Recent（≤MAX_EVENTS 高频查询）→ 溢出进入 Archive/Summary。
## 普通事件压缩为年度统计；重大事件（国家成立/战争/重大科技等）保留原文。
## 供 TAB 历史面板与长期稳定性（不再无限增长）。

signal history_recorded(text: String)

var events: Array = []           # Recent
var archive: Array = []          # 重大事件原文（有上限）
var summaries: Dictionary = {}   # year -> {count, types:{kind:count}}

const MAX_EVENTS: int = 500
const MAX_ARCHIVE: int = 2000

func record(event: String) -> void:
	events.append(event)
	if events.size() > MAX_EVENTS:
		var dropped: String = events.pop_front()
		_archive_event(dropped)
	history_recorded.emit(event)
	print("[History] ", event)

func _archive_event(text: String) -> void:
	var yr: int = _extract_year(text)
	if yr > 0:
		if not summaries.has(yr):
			summaries[yr] = {"count": 0, "types": {}}
		var s: Dictionary = summaries[yr]
		s["count"] = int(s["count"]) + 1
		var kind: String = _classify(text)
		if not s["types"].has(kind):
			s["types"][kind] = 0
		s["types"][kind] = int(s["types"][kind]) + 1
	if _is_major(text):
		archive.append({"year": yr, "text": text})
		if archive.size() > MAX_ARCHIVE:
			archive.pop_front()

func _extract_year(text: String) -> int:
	var m: RegExMatch = RegEx.create_from_string("第(\\d+)年").search(text)
	if m:
		return int(m.get_string(1))
	return -1

func _classify(text: String) -> String:
	for kw in [["战争", "战斗", "宣战", "军队"], ["饥荒", "挨饿", "粮食危机"], ["迁移", "迁入", "迁出"],
		["城市", "聚落", "城镇", "城区"], ["国家", "王国", "帝国"], ["发明", "科技", "技术", "铁制", "水车"],
		["结婚", "出生", "死亡", "成年"], ["洪水", "灾害", "暴雪", "干旱"], ["议事会", "政策", "法律", "改革", "革命"],
		["贸易", "市场", "商会"], ["学校", "教育", "学院"], ["教堂", "节日", "文化"]]:
		if text.contains(kw[0]):
			return kw[1]
	return "其他"

func _is_major(text: String) -> bool:
	for kw in ["国家成立", "王国建立", "首都", "大战", "战争结束", "重要人物", "重大科技", "发明",
		"文明分裂", "革命", "改革", "饥荒", "洪灾", "洪水", "帝国", "迁移", "发现铁矿"]:
		if text.contains(kw):
			return true
	return false

## 年度统计文本（用户面板要求：Year N 人口增长/战争/饥荒…）
func summary_text() -> Array:
	var out: Array = []
	var years: Array = summaries.keys()
	years.sort()
	for yr in years:
		var s: Dictionary = summaries[yr]
		var parts: Array = ["第%d年" % yr]
		for kind in s["types"]:
			parts.append("%s×%d" % [kind, s["types"][kind]])
		out.append("  ".join(parts))
	return out

func recent_text(count: int = 30) -> Array:
	var out: Array = []
	var start: int = maxi(0, events.size() - count)
	for i in range(start, events.size()):
		out.append(events[i])
	return out

## 存档：recent + archive + summaries
func snapshot() -> Dictionary:
	return {
		"recent": events.duplicate(),
		"archive": archive.duplicate(),
		"summaries": summaries.duplicate(true),
	}

func restore(data: Dictionary) -> void:
	events.clear(); archive.clear(); summaries.clear()
	if data.has("recent") and data["recent"] is Array:
		events = (data["recent"] as Array).slice(0, MAX_EVENTS)
	if data.has("archive") and data["archive"] is Array:
		archive = (data["archive"] as Array).slice(0, MAX_ARCHIVE)
	if data.has("summaries") and data["summaries"] is Dictionary:
		summaries = data["summaries"]
