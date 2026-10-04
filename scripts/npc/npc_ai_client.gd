extends Node
## Godot -> Python AI 服务器

signal reply_ready(text: String)

const URL := "http://127.0.0.1:5000/chat"

func ask(message: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 15.0
	http.request_completed.connect(_done.bind(http))
	var body := JSON.stringify({"message": message})
	http.request(URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)

func _done(_r, _code, _h, body, http: HTTPRequest) -> void:
	http.queue_free()
	if body.is_empty():
		reply_ready.emit("(AI服务器无响应)")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data and "reply" in data:
		reply_ready.emit(str(data["reply"]))
	else:
		reply_ready.emit("(AI返回异常)")
