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


func open(success: bool, items: Array, total_value: int, elapsed_sec := -1.0,
		seed_id := -1, fail_reason := "") -> void:
	visible = true
	for c in _list_box.get_children():
		c.queue_free()
	var time_text := ""
	if elapsed_sec >= 0.0:
		time_text = "（用时 %d分%02d秒" % [int(elapsed_sec) / 60, int(elapsed_sec) % 60]
		if seed_id >= 0:
			time_text += " · 海况 #%d" % seed_id
		time_text += "）"
	if success:
		_title.text = "撤离成功"
		_title.add_theme_color_override("font_color", UICommon.GOLD)
		_subtitle.text = "战利品已安全运回荒岛，可在神秘商人处出售。" + time_text
		_total_label.text = "本次总估值：%d" % total_value
		_total_label.add_theme_color_override("font_color", UICommon.GOLD)
	else:
		_title.text = "潜水失败"
		_title.add_theme_color_override("font_color", UICommon.DANGER)
		var drop_hint := ""
		if not items.is_empty():
			drop_hint = "本次携带的宝物散落在海床，下次下潜可以尝试找回。"
		_subtitle.text = "%s。%s已储存的额度、材料与造船进度不受影响。%s" \
			% [fail_reason if fail_reason != "" else "体力耗尽或生命归零", drop_hint, time_text]
		_total_label.text = "散落估值：%d" % total_value
		_total_label.add_theme_color_override("font_color", UICommon.DANGER)

	if items.is_empty():
		_list_box.add_child(UICommon.label("（没有携带任何宝物）", 17, UICommon.DIM))
		return
	var groups: Dictionary = GameState.group_entries(items)
	for key in groups:
		var g: Dictionary = groups[key]
		var q: Dictionary = ItemDBRes.QUALITIES[g["quality"]]
		var info: Dictionary = ItemDBRes.TREASURES[g["id"]]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UICommon.quality_icon(g["id"], q["color"], 40.0))
		var name_label := UICommon.label("%s·%s ×%d" % [q["name"], info["name"], g["count"]],
			19, q["color"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UICommon.label("估值 %d" % (g["value"] * g["count"]), 18, UICommon.DIM))
		_list_box.add_child(row)


func _go_island() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/island.tscn")
