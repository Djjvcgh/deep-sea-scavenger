extends CanvasLayer
## 水下背包界面（Tab 开关）：逐件展示携带宝物（含品质），丢弃以释放容量。

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
	box.add_child(UICommon.label("丢弃会立即释放容量；品质越好的宝物越值钱。", 14, UICommon.DIM))

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

	for i in GameState.dive_bag.size():
		var entry: Dictionary = GameState.dive_bag[i]
		var info: Dictionary = ItemDBRes.TREASURES[entry["id"]]
		var q: Dictionary = ItemDBRes.QUALITIES[entry["quality"]]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		row.add_child(UICommon.quality_icon(entry["id"], q["color"]))

		var name_label := UICommon.label("%s·%s" % [q["name"], info["name"]], 18, q["color"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UICommon.label("估值 %d · %d格" % [GameState.value_of(entry), info["slots"]],
			15, UICommon.DIM))
		var drop := UICommon.button("丢弃", 15)
		drop.pressed.connect(_drop.bind(i))
		row.add_child(drop)
		_rows_box.add_child(row)


func _drop(index: int) -> void:
	if GameState.remove_dive_item_at(index):
		Sfx.play("click")
