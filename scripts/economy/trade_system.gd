extends Node
## 外贸系统：Eden 与北境部落 / 沙漠城邦之间的商品交换。
## 不凭空贸易：必须有 商人、连通道路、且本地有富余库存才会成交。
## 出口原材料 → 现金流入市场（发工资的根本来源）；灾年可花现金进口粮食。

var trade_log: Array = []

## 每天结算一次。has_merchant/has_road 由世界情况传入（布尔门槛）。
## 外交影响：关系冷淡 → 贸易路线停用 → 该商品停止出口（堆积压价，市场现金承压）
## 政策影响：森林保护 → 木材出口配额减半
func process_day(market, residents: Array, has_road: bool, world) -> void:
	var has_merchant: bool = false
	for n in residents:
		if n.get("job") == "商人":
			has_merchant = true
			break
	if not has_merchant or not has_road:
		return
	var diplomacy = world.get("diplomacy") if world else null
	var policy = world.get("politics").policy if world and world.get("politics") else null
	# 富余阈值：超过储备线才允许出口
	var reserves := {"wood": 40.0, "stone": 20.0, "iron": 8.0, "cloth": 8.0}
	for item in reserves:
		# 外交：无活跃贸易路线则不外销
		if diplomacy and diplomacy.active_routes_for(item) == 0:
			continue
		var surplus: float = market.stock.get(item, 0.0) - reserves[item]
		if surplus >= 5.0:
			var batch: float = min(surplus, 6.0)
			# 森林保护政策：木材出口减半
			if item == "wood" and policy and policy.get_val("forest_protection", false):
				batch *= 0.5
			var income: float = market.export_goods(item, batch)
			if income > 0.0:
				trade_log.append("出口 %s x%d，收入 %d 铜币" % [item, int(batch), int(income)])
	# 粮食危机时进口粮食（花市场现金）
	if market.stock.get("food", 0.0) < residents.size() * 2.0 and market.cash > 150.0:
		if market.import_goods("food", 20.0):
			trade_log.append("粮食紧张，从商队进口粮食")
