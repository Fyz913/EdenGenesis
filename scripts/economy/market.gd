extends Node
class_name EdenMarket
## 市场：全村庄唯一的商品交易中心。有库存、有现金、价格随供需浮动。
## 商品不会凭空产生：只能由居民生产后供货（supply），或由外贸进口。
## 现金不会凭空产生：初始备用金 + 外贸出口收入 + 居民买东西回流。

var stock: Dictionary = {"food": 120.0, "wood": 60.0, "stone": 30.0, "iron": 10.0, "cloth": 10.0}
var cash: float = 1000.0   # 市场备用金，用于收购居民产品（发工资的来源）

# 每日收购配额（由 EconomyManager 按需求设定）：市场只买“卖得掉”的货
var accept_quota: Dictionary = {}
var accept_used: Dictionary = {}

# 基准价与动态价
var base_prices: Dictionary = {"food": 5.0, "wood": 8.0, "stone": 10.0, "iron": 20.0, "cloth": 12.0}
var prices: Dictionary = {"food": 5.0, "wood": 8.0, "stone": 10.0, "iron": 20.0, "cloth": 12.0}

func reset_quota(pop: int) -> void:
	accept_used = {}
	# 粮食按人口需求 + 少量缓冲收购；其余商品受外贸需求限制，每天只收 3 件
	accept_quota = {"food": float(pop) + 6.0, "wood": 3.0, "stone": 3.0, "iron": 3.0, "cloth": 3.0}

# 供居民生产后把货卖给市场；超过当日需求/配额的货市场不收（不发工资），防止生产无限膨胀
func supply(item: String, qty: float) -> float:
	var accepted: float = deposit(item, qty)
	if accepted <= 0.0: return 0.0
	var pay: float = accepted * prices.get(item, base_prices.get(item, 1.0)) * 0.6  # 收购价=售价60%
	pay = min(pay, cash)
	cash -= pay
	return pay

# 只按配额收货、不付款（工资走岗位日薪，见 EconomyManager）
func deposit(item: String, qty: float) -> float:
	if qty <= 0.0: return 0.0
	var room: float = max(0.0, accept_quota.get(item, 0.0) - accept_used.get(item, 0.0))
	var accepted: float = min(qty, room)
	if accepted <= 0.0: return 0.0
	accept_used[item] = accept_used.get(item, 0.0) + accepted
	stock[item] = stock.get(item, 0.0) + accepted
	return accepted

# 市场支付岗位日薪（现金不足则不发，杜绝凭空发钱）
func pay_salary(amount: float) -> float:
	var paid: float = min(amount, cash)
	cash -= paid
	return paid

# 粮食易腐坏：每天损耗 15%，杜绝粮食无限囤积
func spoil() -> void:
	stock["food"] = stock.get("food", 0.0) * 0.85

# 居民按市价购买，返回是否成功（同时扣库存、收现金）
func purchase(buyer, item: String, qty: float) -> bool:
	var cost: float = qty * prices.get(item, base_prices.get(item, 1.0))
	if stock.get(item, 0.0) < qty: return false
	if buyer.money < cost: return false
	stock[item] -= qty
	buyer.money -= cost
	cash += cost
	if buyer.get("inventory") and buyer.inventory:
		buyer.inventory.add_item(item, qty)
	return true

# 家庭用共同钱包购买
func purchase_family(family_node, item: String, qty: float) -> bool:
	var cost: float = qty * prices.get(item, base_prices.get(item, 1.0))
	if stock.get(item, 0.0) < qty: return false
	if family_node.family_money < cost: return false
	stock[item] -= qty
	family_node.family_money -= cost
	cash += cost
	family_node.family_inventory.add_item(item, qty)
	return true

# 外贸出口：把富余原材料卖给外商换现金（钱的合法来源之一）
func export_goods(item: String, qty: float) -> float:
	if stock.get(item, 0.0) < qty: return 0.0
	stock[item] -= qty
	var income: float = qty * prices.get(item, 1.0)
	cash += income
	return income

# 外贸进口：花现金买入粮食（灾年）
func import_goods(item: String, qty: float) -> bool:
	var cost: float = qty * prices.get(item, 1.0) * 1.3
	if cash < cost: return false
	cash -= cost
	stock[item] = stock.get(item, 0.0) + qty
	return true

## 每天按库存更新价格：缺货涨价、积压降价、供需平衡时向基准价回归，限制区间防爆
func update_prices() -> void:
	for item in base_prices:
		var amount: float = stock.get(item, 0.0)
		if amount < 10.0:
			prices[item] = clampf(prices[item] * 1.08, 1.0, 100.0)
		elif amount > 120.0:
			prices[item] = clampf(prices[item] * 0.92, 1.0, 100.0)
		else:
			# 供需健康：向基准价缓慢回归，避免价格长期失真
			prices[item] = lerpf(prices[item], base_prices[item], 0.2)

var treasury: float = 0.0   # 外贸顺差沉淀的国库（退出流通，供未来公共建设）
## 市场现金封顶，超额贸易顺差进入国库，防止货币无限膨胀
func siphon_surplus(limit: float = 2000.0) -> void:
	if cash > limit:
		treasury += cash - limit
		cash = limit

func status_text() -> String:
	if stock.get("food", 0.0) < 30.0: return "粮食紧张"
	if cash < 100.0: return "银根紧缩"
	return "正常"
