extends CanvasLayer
## 船坞界面：投入材料造小帆船。材料齐全即完成，视为 v0.1 通关目标。

const ItemDBRes := preload("res://scripts/item_db.gd")

signal closed

var _progress_bar: ProgressBar
var _progress_label: Label
var _rows_box: VBoxContainer
var _owned_label: Label
var _done_label: Label


func _ready() -> void:
	layer = 10
	visible = false
	_build()
	GameState.materials_changed.connect(_refresh)
	GameState.boat_changed.connect(_refresh)


func _build() -> void:
	add_child(UICommon.dim_overlay())
	var popup := UICommon.popup_panel(640.0)
	add_child(popup)
	var panel: PanelContainer = popup.get_meta("panel")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	box.add_child(UICommon.label("船坞 · 建造小帆船", 28, UICommon.GOLD))

	var boat_view: Control = preload("res://scripts/ui/boat_drawing.gd").new()
	boat_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(boat_view)

	_owned_label = UICommon.label("", 18)
	box.add_child(_owned_label)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	box.add_child(_rows_box)

	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	box.add_child(prow)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(360, 22)
	_progress_bar.show_percentage = false
	_progress_bar.max_value = 100.0
	prow.add_child(_progress_bar)
	_progress_label = UICommon.label("", 18, UICommon.CYAN)
	prow.add_child(_progress_label)

	_done_label = UICommon.label("小帆船建造完成！下一片海域即将开放。", 20, UICommon.GOLD)
	_done_label.visible = false
	box.add_child(_done_label)

	var close_btn := UICommon.button("离开（Esc）", 18)
	close_btn.pressed.connect(close)
	box.add_child(close_btn)


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	if not visible:
		return
	_owned_label.text = "持有材料：木材 %d · 铁件 %d · 帆布 %d" \
		% [GameState.materials["wood"], GameState.materials["iron"], GameState.materials["canvas"]]

	for c in _rows_box.get_children():
		c.queue_free()
	for id in ItemDBRes.BOAT_REQUIREMENT:
		var m: Dictionary = ItemDBRes.MATERIALS[id]
		var need: int = ItemDBRes.BOAT_REQUIREMENT[id]
		var invested: int = GameState.boat_invested[id]
		var missing: int = maxi(0, need - invested)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := UICommon.label(m["name"], 18)
		name_label.custom_minimum_size = Vector2(90, 0)
		row.add_child(name_label)
		var info := UICommon.label("需要 %d · 已投入 %d · 还差 %d" % [need, invested, missing], 17,
			UICommon.GOOD if missing == 0 else UICommon.TEXT)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		if missing > 0:
			var btn := UICommon.button("投入全部", 15)
			btn.disabled = GameState.materials[id] <= 0
			btn.pressed.connect(_invest.bind(id))
			row.add_child(btn)
		else:
			row.add_child(UICommon.label("✓ 已投入", 17, UICommon.GOOD))
		_rows_box.add_child(row)

	var progress := GameState.boat_progress()
	_progress_bar.value = progress * 100.0
	_progress_label.text = "建造进度 %d%%" % int(progress * 100.0)
	_done_label.visible = GameState.boat_completed


func _invest(id: String) -> void:
	var m: Dictionary = ItemDBRes.MATERIALS[id]
	var moved: int = GameState.invest_material(id, GameState.materials[id])
	if moved > 0 and not GameState.boat_completed:
		Sfx.play("click")
