extends CanvasLayer
## 对话界面

@onready var npc_name_label: Label = %NpcNameLabel
@onready var message_history: RichTextLabel = %MessageHistory
@onready var input_field: LineEdit = %InputField

var current_npc: CharacterBody3D = null
var _waiting: bool = false

func _ready() -> void:
	input_field.text_submitted.connect(_on_submit)
	visible = false

func open(npc: CharacterBody3D) -> void:
	current_npc = npc
	npc_name_label.text = npc.npc_name + " (" + npc.job + ")"
	message_history.clear()
	message_history.append_text(_profile(npc))
	message_history.append_text("【对话】输入消息后按回车，ESC 结束。\n\n")
	input_field.text = ""
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	input_field.grab_focus()

func _profile(npc) -> String:
	var lines: Array = ["═══════════════"]
	lines.append("姓名: " + npc.npc_name + "   年龄: " + str(npc.age) + "   职业: " + npc.job)
	if npc.get("personality_sys"):
		lines.append("性格: " + npc.personality_sys.archetype + "（最突出：" + npc.personality_sys.dominant_trait() + "）")
	if npc.get("emotion_sys"):
		lines.append("心情: " + npc.emotion_sys.mood())
	if npc.get("goal_sys"):
		lines.append("今日目标: " + npc.goal_sys.daily_goal)
		lines.append("人生梦想: " + npc.goal_sys.life_dream)
	# 家庭
	var fam: String = "无"
	if npc.spouse:
		fam = "配偶 " + npc.spouse.npc_name
	if npc.family and npc.family.children.size() > 0:
		fam += "，孩子 " + str(npc.family.children.size()) + " 个"
	lines.append("家庭: " + fam)
	# 最重要的记忆
	if npc.get("life_memory"):
		var tm: Array = npc.life_memory.top(2)
		lines.append("记忆:")
		for m in tm:
			lines.append("  · 第" + str(m.year) + "年 " + m.event)
	lines.append("═══════════════\n")
	return "\n".join(lines) + "\n"

func close() -> void:
	visible = false
	current_npc = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_submit(text: String) -> void:
	if _waiting or text.strip_edges() == "" or current_npc == null: return
	message_history.append_text("你: " + text + "\n")
	input_field.text = ""
	_waiting = true
	current_npc.reply_ready.connect(_on_reply, CONNECT_ONE_SHOT)
	current_npc.chat(text)

func _on_reply(reply: String) -> void:
	_waiting = false
	message_history.append_text(current_npc.npc_name + ": " + reply + "\n\n")
	input_field.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible: close()
