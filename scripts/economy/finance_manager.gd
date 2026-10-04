extends Node
## 0.20 银行初版（Eden 钱庄）：存款 / 贷款 / 利息。
## 铁律：钱庄自有资金有限（初始 200），贷款不能凭空印钞——受银行资金约束；
## 企业贷款建厂 → 生产 → 还款，形成真实信贷循环。

var bank_cash: float = 200.0
var deposits: Dictionary = {}   # entity_id -> amount（家庭/企业存款）
var loans: Array = []           # {id, borrower, amount, rate, remain, months, months_left}
var interest_rate: float = 0.02   # 月利率（存款同率）
var loan_counter: int = 0

func deposit(entity_id: String, amt: float) -> void:
	if amt <= 0.0: return
	deposits[entity_id] = deposits.get(entity_id, 0.0) + amt
	bank_cash += amt

func withdraw(entity_id: String, amt: float) -> bool:
	if amt <= 0.0: return true
	if deposits.get(entity_id, 0.0) < amt: return false
	deposits[entity_id] -= amt
	bank_cash -= amt
	return true

func savings(entity_id: String) -> float:
	return deposits.get(entity_id, 0.0)

## 贷款：银行资金约束 + 借款人存款担保（可贷上限 = 存款×3 且 ≤ 银行资金）
func take_loan(entity_id: String, amt: float, months: int = 6) -> bool:
	if amt <= 0.0: return false
	var guaranty: float = deposits.get(entity_id, 0.0) * 3.0
	if amt > guaranty: return false
	if amt > bank_cash: return false
	loan_counter += 1
	loans.append({
		"id": "loan_%d" % loan_counter, "borrower": entity_id, "amount": amt,
		"rate": interest_rate, "remain": amt * (1.0 + interest_rate * float(months)),
		"months": months, "months_left": months,
	})
	bank_cash -= amt
	deposits[entity_id] = deposits.get(entity_id, 0.0) + amt   # 贷款入账即存款
	return true

## 月度结算：存款利息 + 贷款还款（借款人存款足够才还，不够则拖欠）
func monthly_tick() -> void:
	# 存款利息
	for eid in deposits:
		deposits[eid] = deposits[eid] * (1.0 + interest_rate)
		bank_cash += deposits[eid] * interest_rate
	# 贷款还款
	var settled: Array = []
	for loan in loans:
		if loan["months_left"] <= 0:
			settled.append(loan)
			continue
		loan["months_left"] = int(loan["months_left"]) - 1
		var payment: float = loan["remain"] / float(loan["months"])
		var borrower_dep: float = deposits.get(loan["borrower"], 0.0)
		if borrower_dep >= payment:
			deposits[loan["borrower"]] -= payment
			bank_cash += payment
			loan["remain"] -= payment
		else:
			# 存款不足：从银行自有资金中核销（坏账，银行资金减少）
			bank_cash = max(0.0, bank_cash - payment)
			loan["remain"] -= payment
		if loan["remain"] <= 0.0:
			settled.append(loan)
	for loan in settled:
		loans.erase(loan)

func stats() -> Dictionary:
	var total_loans: float = 0.0
	for l in loans:
		total_loans += l["remain"]
	return {"bank_cash": bank_cash, "deposits": deposits.size(),
		"total_deposits": _sum_deposits(), "loans": loans.size(), "outstanding": total_loans}

func serialize() -> Dictionary:
	return {"bank_cash": bank_cash, "deposits": deposits.duplicate(),
		"loans": loans.duplicate(true), "interest_rate": interest_rate}

func restore(data: Dictionary) -> void:
	if not (data is Dictionary): return
	bank_cash = float(data.get("bank_cash", 200.0))
	deposits = data.get("deposits", {}).duplicate()
	loans = data.get("loans", []).duplicate(true)
	interest_rate = float(data.get("interest_rate", 0.02))

func _sum_deposits() -> float:
	var s: float = 0.0
	for eid in deposits:
		s += deposits[eid]
	return s
