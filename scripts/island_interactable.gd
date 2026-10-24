extends Area2D
## 荒岛交互点（商人 / 工作台 / 船坞 / 下潜点）。
## 视觉由荒岛场景搭建，这里只提供交互接口；回调由场景注入。

var prompt_text := ""
var callback: Callable = Callable()


func setup(text: String, cb: Callable) -> void:
	prompt_text = text
	callback = cb


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	add_to_group("interactables")


func is_available() -> bool:
	return callback.is_valid()


func interact_prompt() -> String:
	return prompt_text


## 视觉：木牌 + 名称标签（供玩家识别交互点）。
func setup_visual(text: String) -> void:
	z_index = 4
	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(3, 46), Vector2(-3, 46)])
	post.color = Color(0.4, 0.28, 0.16)
	add_child(post)
	var board := Polygon2D.new()
	board.polygon = PackedVector2Array([Vector2(-22, -12), Vector2(22, -12), Vector2(22, 8), Vector2(-22, 8)])
	board.color = Color(0.55, 0.4, 0.22)
	add_child(board)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	label.position = Vector2(-21, -10)
	add_child(label)


func interact(_player: Node) -> void:
	if callback.is_valid():
		callback.call()
