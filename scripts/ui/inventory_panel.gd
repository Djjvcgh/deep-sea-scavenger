extends CanvasLayer
## 水下背包界面（Tab 开关）：查看携带宝物、丢弃以释放容量。

const ItemDBRes := preload("res://scripts/item_db.gd")

var _rows_box: VBoxContainer
var _usage_label: Label


func _ready() -> void:
	layer = 10
	visible = false
	_build()
	GameState.dive_bag_changed.connect(_refresh)


func _build() -> void:
	var overlay := UICommon.dim_overlay()
	add_child(overlay)

	var popup := UICommon.popup_panel(560.0)
	add_child(popup)
	var panel: PanelContainer = popup.get_meta("panel")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	box.add_child(UICommon.label("背包", 28, UICommon.GOLD))
	_usage_label = UICommon.label("", 18)
	box.add_child(_usage_label)
	box.add_child(UICommon.vspace(4))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	box.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows_box)

	box.add_child(UICommon.vspace(4))
	box.add_child(UICommon.label("丢弃宝物会立即释放容量；神像丢弃后鲨鱼危险加成解除。", 14, UICommon.DIM))

	var close_btn := UICommon.button("关闭（Tab）", 18)
	close_btn.pressed.connect(close)
	box.add_child(close_btn)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	visible = false


func _refresh() -> void:
	if _rows_box == null:
		return
	for c in _rows_box.get_children():
		c.queue_free()
	_usage_label.text = "占用 %d / %d 格 · 携带估值 %d" \
		% [GameState.bag_used_slots(), GameState.bag_capacity(), GameState.dive_total_value()]

	if GameState.dive_bag.is_empty():
		_rows_box.add_child(UICommon.label("（空）还没有携带任何宝物", 17, UICommon.DIM))
		return

	var counted := {}
	for id in GameState.dive_bag:
		counted[id] = counted.get(id, 0) + 1
	for id in counted:
		var info: Dictionary = ItemDBRes.TREASURES[id]
		var n: int = counted[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var color: Color = info["color"]
		var swatch := Panel.new()
		swatch.custom_minimum_size = Vector2(16, 16)
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(3)
		swatch.add_theme_stylebox_override("panel", sb)
		row.add_child(swatch)
		var name_label := UICommon.label("%s ×%d" % [info["name"], n], 19)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UICommon.label("%d格/件 · 共%d" % [info["slots"], info["value"] * n], 16, UICommon.DIM))
		var drop1 := UICommon.button("丢弃1", 16)
		drop1.pressed.connect(_drop_one.bind(id))
		row.add_child(drop1)
		var drop_all := UICommon.button("全丢", 16)
		drop_all.pressed.connect(_drop_all.bind(id))
		row.add_child(drop_all)
		_rows_box.add_child(row)


func _drop_one(id: String) -> void:
	if GameState.remove_dive_item(id):
		Sfx.play("click")


func _drop_all(id: String) -> void:
	while GameState.remove_dive_item(id):
		pass
	Sfx.play("click")
