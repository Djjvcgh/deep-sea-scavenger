extends CanvasLayer
## 开箱拾取界面：搜索完成后展示掉落条目（品质配色），逐件或全部拾取。
## 背包装不下的条目：遗落物袋 → 放回缓存；其他容器 → 留在海底。
## 面板期间移动保持锁定（搜刮时的 vulnerable 窗口），关闭后解锁。

signal closed

const ItemDBRes := preload("res://scripts/item_db.gd")

var _container: Area2D = null
var _entries: Array = []          # 未拾取的条目
var _rows_box: VBoxContainer
var _title_label: Label
var _flash_label: Label


func _ready() -> void:
	layer = 12
	visible = false
	_build()


func _build() -> void:
	add_child(UICommon.dim_overlay())

	var popup := UICommon.popup_panel(560.0)
	add_child(popup)
	var panel: PanelContainer = popup.get_meta("panel")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	_title_label = UICommon.label("获得物资", 26, UICommon.GOLD)
	box.add_child(_title_label)
	_flash_label = UICommon.label(" ", 15, UICommon.ORANGE)
	box.add_child(_flash_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	box.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 5)
	scroll.add_child(_rows_box)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	var take_all := UICommon.button("全部拾取（E）", 18)
	take_all.pressed.connect(take_all_and_close)
	actions.add_child(take_all)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var close_btn := UICommon.button("离开", 18)
	close_btn.pressed.connect(close)
	actions.add_child(close_btn)


func open(entries: Array, container: Area2D) -> void:
	_container = container
	_entries = entries.duplicate(true)
	_title_label.text = String(container.interact_prompt()) + " — 获得物资"
	_flash_label.text = " "
	visible = true
	_refresh()


func close() -> void:
	if not visible:
		return
	# 未取走的条目：遗落物袋放回缓存，其他容器留在海底
	var leftovers: Array = _entries.duplicate(true)
	if _container != null and is_instance_valid(_container) \
			and _container.has_method("restore_leftovers"):
		_container.restore_leftovers(leftovers)
	_entries = []
	_container = null
	visible = false
	closed.emit()


## 逐件拾取（只拿装得下的）。一件都没拿走时自动关闭（物品留在来源处）。
func take_all_and_close() -> void:
	var taken := 0
	var i := 0
	while i < _entries.size():
		if _try_take(i):
			taken += 1
			continue       # 拿走后原位补位，不前进下标
		i += 1
	if taken == 0 or _entries.is_empty():
		close()
	else:
		_flash_label.text = "背包空间不足，%d 件未带走" % _entries.size()
		Sfx.play("click")
		_refresh()


func _try_take(index: int) -> bool:
	var entry: Dictionary = _entries[index]
	if entry.has("mat"):
		var mat := String(entry["mat"])
		if not ItemDBRes.MATERIALS.has(mat):
			_entries.remove_at(index)
			return true
		GameState.materials[mat] += 1
		GameState.materials_changed.emit()
		_entries.remove_at(index)
		Sfx.play("pickup")
		return true
	var slots := int(ItemDBRes.TREASURES[entry["id"]]["slots"])
	if not GameState.add_dive_item(String(entry["id"]), String(entry.get("quality", "standard"))):
		return false
	var info: Dictionary = ItemDBRes.TREASURES[entry["id"]]
	Sfx.play("rare_pickup" if info["rare"] else "pickup")
	_entries.remove_at(index)
	return true


func _refresh() -> void:
	if _rows_box == null:
		return
	for c in _rows_box.get_children():
		c.queue_free()
	if _entries.is_empty():
		return
	for i in _entries.size():
		var entry: Dictionary = _entries[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		if entry.has("mat"):
			var mat := String(entry["mat"])
			var mat_info: Dictionary = ItemDBRes.MATERIALS[mat]
			var mlabel := UICommon.label("材料 · %s" % mat_info["name"], 18, UICommon.CYAN)
			mlabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(mlabel)
			row.add_child(UICommon.label("用于打造", 14, UICommon.DIM))
			var mbtn := UICommon.button("拾取", 15)
			mbtn.pressed.connect(_try_take.bind(i))
			mbtn.pressed.connect(_refresh)
			row.add_child(mbtn)
		else:
			var info: Dictionary = ItemDBRes.TREASURES[entry["id"]]
			var q: Dictionary = ItemDBRes.QUALITIES[entry["quality"]]
			var slots := int(info["slots"])
			var swatch := Panel.new()
			swatch.custom_minimum_size = Vector2(14, 14)
			var sb := StyleBoxFlat.new()
			sb.bg_color = q["color"]
			sb.set_corner_radius_all(3)
			swatch.add_theme_stylebox_override("panel", sb)
			row.add_child(swatch)
			var name_label := UICommon.label("%s·%s" % [q["name"], info["name"]], 18, q["color"])
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			row.add_child(UICommon.label("估值 %d · 占%d格" % [GameState.value_of(entry), slots],
				15, UICommon.DIM))
			var btn := UICommon.button("拾取", 15)
			btn.disabled = not GameState.can_carry(slots)
			btn.pressed.connect(_try_take.bind(i))
			btn.pressed.connect(_refresh)
			row.add_child(btn)
		_rows_box.add_child(row)
