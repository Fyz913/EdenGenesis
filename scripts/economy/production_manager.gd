extends Node
## 0.20 工厂生产管理器：工厂（Factory）消耗输入资源 → 产出商品。
## 铁律：产出必须消耗输入；输入不足则减产/停产，禁止凭空产出。
## 工厂按职业归属企业（company_manager），每小时运行一次（低频模拟）。

const MAX_FACTORIES := 200

var factories: Dictionary = {}   # id -> {id,name,company_id,type,inputs,output,output_qty,workers,level,built_year}
var factory_counter: int = 0

## 工厂配方（type -> {inputs, output, qty}）
const RECIPES := {
	"farm": {"inputs": {"water": 0.2}, "output": "food", "qty": 3.0},
	"wood_camp": {"inputs": {}, "output": "wood", "qty": 2.0},
	"stone_quarry": {"inputs": {}, "output": "stone", "qty": 1.5},
	"iron_mine": {"inputs": {}, "output": "iron", "qty": 1.0},
	"coal_mine": {"inputs": {}, "output": "coal", "qty": 1.2},
	"smithy": {"inputs": {"iron": 1.0, "coal": 0.5}, "output": "steel", "qty": 0.6},
	"tool_shop": {"inputs": {"iron": 1.0, "wood": 1.0}, "output": "tools", "qty": 0.8},
	"machine_shop": {"inputs": {"steel": 2.0, "iron": 1.0}, "output": "machine", "qty": 0.4},
	"electronics_lab": {"inputs": {"machine": 1.0, "steel": 1.0}, "output": "electronics", "qty": 0.2},
}

func create_factory(factory_name: String, company_id: String, ftype: String) -> Dictionary:
	factory_counter += 1
	var fid: String = "factory_%d" % factory_counter
	var recipe: Dictionary = RECIPES.get(ftype, {})
	var factory: Dictionary = {
		"id": fid, "name": factory_name, "company_id": company_id,
		"type": ftype, "inputs": recipe.get("inputs", {}).duplicate(),
		"output": recipe.get("output", ""), "output_qty": recipe.get("qty", 0.0),
		"workers": [], "level": 1, "built_year": _current_year(),
	}
	factories[fid] = factory
	return factory

func factory_count() -> int:
	return factories.size()

## 每小时运行一座工厂：消耗输入（资源池），产出写入资源池。
## 返回实际产出字典（可入市场）；输入不足则按短缺比例减产。
func run_factory(factory: Dictionary, resource_mgr) -> Dictionary:
	if factory.is_empty(): return {}
	var recipe: Dictionary = RECIPES.get(factory["type"], {})
	var inputs: Dictionary = recipe.get("inputs", {})
	var shortage: float = 1.0
	for res in inputs:
		var need: float = inputs[res] * factory.get("level", 1)
		var have: float = resource_mgr.amount(res) if resource_mgr else 0.0
		if need > 0.0:
			shortage = min(shortage, have / need)
	if shortage <= 0.0: return {}
	# 按短缺比例减产，并实际扣消耗
	var mult: float = shortage * factory.get("level", 1)
	for res in inputs:
		var need: float = inputs[res] * factory.get("level", 1) * shortage
		if resource_mgr:
			resource_mgr.consume(res, need)
	# 工人数量加成：每名工人 +5% 产出（封顶 +100%）
	var labor_mult: float = 1.0 + min(1.0, factory["workers"].size() * 0.05)
	var qty: float = factory["output_qty"] * mult * labor_mult
	if qty <= 0.0: return {}
	if resource_mgr:
		resource_mgr.add(factory["output"], qty)
	return {factory["output"]: qty}

func run_all(resource_mgr) -> Dictionary:
	var total: Dictionary = {}
	for fid in factories:
		var out: Dictionary = run_factory(factories[fid], resource_mgr)
		for k in out:
			total[k] = total.get(k, 0.0) + out[k]
	return total

func factories_of_company(company_id: String) -> Array:
	var out: Array = []
	for fid in factories:
		if factories[fid]["company_id"] == company_id:
			out.append(factories[fid])
	return out

func upgrade(factory: Dictionary) -> void:
	factory["level"] = min(5, factory.get("level", 1) + 1)

func serialize() -> Array:
	var out: Array = []
	for fid in factories:
		var f: Dictionary = factories[fid]
		out.append({
			"id": f["id"], "name": f["name"], "company_id": f["company_id"],
			"type": f["type"], "level": f["level"], "built_year": f["built_year"],
			"workers": f["workers"].duplicate(),
		})
	return out

func restore(data: Array) -> void:
	factories.clear(); factory_counter = 0
	for item in data:
		if not (item is Dictionary): continue
		var recipe: Dictionary = RECIPES.get(item.get("type", ""), {})
		var fid: String = str(item.get("id", "factory_%d" % (factory_counter + 1)))
		factories[fid] = {
			"id": fid, "name": item.get("name", ""), "company_id": item.get("company_id", ""),
			"type": item.get("type", ""), "inputs": recipe.get("inputs", {}).duplicate(),
			"output": recipe.get("output", ""), "output_qty": recipe.get("qty", 0.0),
			"workers": (item.get("workers", []) as Array).duplicate(),
			"level": int(item.get("level", 1)), "built_year": int(item.get("built_year", 1)),
		}
		factory_counter += 1

func _current_year() -> int:
	var w = get_node_or_null("/root/Main/World")
	if w:
		var e = w.get("ecosystem")
		if e and e.get("season_sys"):
			return e.season_sys.year
	return 1
