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


## 视觉：像素木牌贴图 + 名称标签（功能区本体由主题模块表达，木牌只是辅助定位）。
func setup_visual(text: String) -> void:
	z_index = 4
	var sign := Sprite2D.new()
	sign.texture = load("res://assets/scenery/blacktide/signpost.png")
	sign.position = Vector2(0, 22)
	sign.scale = Vector2.ONE * 2.0
	sign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sign)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04, 0.9))
	label.position = Vector2(-24, 10)
	add_child(label)


func interact(_player: Node) -> void:
	if callback.is_valid():
		callback.call()
