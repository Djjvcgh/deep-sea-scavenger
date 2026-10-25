extends CanvasLayer
## 下潜结算界面：撤离成功（宝物入库存）/ 潜水失败（丢失临时宝物）。

const ItemDBRes := preload("res://scripts/item_db.gd")

var _title: Label
var _subtitle: Label
var _list_box: VBoxContainer
var _total_label: Label
var _back_btn: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	var overlay := UICommon.dim_overlay()
	overlay.color = Color(0, 0, 0, 0.7)
	add_child(overlay)

	var popup := UICommon.popup_panel(600.0)
	add_child(popup)
	var panel: PanelContainer = popup.get_meta("panel")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_title = UICommon.label("", 34)
	box.add_child(_title)
	_subtitle = UICommon.label("", 17, UICommon.DIM)
	box.add_child(_subtitle)
	box.add_child(UICommon.vspace(6))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	box.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 5)
	scroll.add_child(_list_box)

	box.add_child(UICommon.vspace(4))
	_total_label = UICommon.label("", 24)
	box.add_child(_total_label)

	_back_btn = UICommon.button("返回荒岛", 22)
	_back_btn.pressed.connect(_go_island)
	box.add_child(_back_btn)


func open(success: bool, items: Array, total_value: int, elapsed_sec := -1.0) -> void:
	visible = true
	for c in _list_box.get_children():
		c.queue_free()
	var time_text := ""
	if elapsed_sec >= 0.0:
		time_text = "（用时 %d分%02d秒）" % [int(elapsed_sec) / 60, int(elapsed_sec) % 60]
	if success:
		_title.text = "撤离成功"
		_title.add_theme_color_override("font_color", UICommon.GOLD)
		_subtitle.text = "战利品已安全运回荒岛，可在神秘商人处出售。" + time_text
		_total_label.text = "本次总估值：%d" % total_value
		_total_label.add_theme_color_override("font_color", UICommon.GOLD)
	else:
		_title.text = "潜水失败"
		_title.add_theme_color_override("font_color", UICommon.DANGER)
		_subtitle.text = "体力耗尽或生命归零，失去了本次携带的全部宝物。已储存的额度、材料与造船进度不受影响。" + time_text
		_total_label.text = "损失估值：%d" % total_value
		_total_label.add_theme_color_override("font_color", UICommon.DANGER)

	if items.is_empty():
		_list_box.add_child(UICommon.label("（没有携带任何宝物）", 17, UICommon.DIM))
		return
	var counted := {}
	for id in items:
		counted[id] = counted.get(id, 0) + 1
	for id in counted:
		var info: Dictionary = ItemDBRes.TREASURES[id]
		var n: int = counted[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := UICommon.label("%s ×%d" % [info["name"], n], 19)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UICommon.label("估值 %d" % (info["value"] * n), 18, UICommon.DIM))
		_list_box.add_child(row)


func _go_island() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/island.tscn")
