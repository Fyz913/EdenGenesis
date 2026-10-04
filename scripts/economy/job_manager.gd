extends Node
## 职业与工资表：定义各职业日薪基准与就业率统计
## 实际工资来自把当天产品卖给市场的收入（见 economy_manager），
## 市场没钱或没干活就不会发工资——杜绝“不工作也领钱”。

const JOB_SALARY := {
	"农民": 8.0, "农夫": 8.0, "渔夫": 8.0, "面包师": 9.0,
	"伐木工": 10.0, "织布工": 10.0, "矿工": 12.0,
	"商人": 15.0, "铁匠": 18.0,
}

const WORKING_AGES := true

func base_salary(job: String) -> float:
	return JOB_SALARY.get(job, 5.0)

func is_worker(npc) -> bool:
	return npc.get("age") >= 18 and npc.get("job") != "孩子"

## 就业率：有劳动能力且有职业的人口 / 成年人口
func employment_rate(residents: Array) -> float:
	var adults: int = 0
	var workers: int = 0
	for n in residents:
		if n.get("age") >= 18:
			adults += 1
			if is_worker(n): workers += 1
	if adults == 0: return 0.0
	return workers * 100.0 / adults
