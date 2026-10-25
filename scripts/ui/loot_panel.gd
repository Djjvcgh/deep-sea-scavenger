extends CanvasLayer
## V0.5 开箱拾取面板：宝物展示重做。
## 每件掉落：物品图标 + 名称（品质配色）+ 估值 + 占格；稀有度用边框与底色分层；
## 稀有 / 高价值物品带呼吸光效；面板高度随条目数收缩。
## 未取走条目：遗落物袋 → 放回缓存；其他容器 → 留在海底。面板期间移动锁定。

signal closed

const ItemDBRes := preload("res://scripts/item_db.gd")

var _container: Area2D = null
var _entries: Array = []          # 未拾取的条目
var _rows_box: VBoxContainer
var _scroll: ScrollContainer
var _title_label: Label
var _flash_label: Label
var _pulse_panels: Array = []     # 高价值图标框（呼吸脉冲）


func _ready() -> void:
	layer = 12
	visible = false
	_build()


func _process(_delta: float) -> void:
	# 高价值呼吸脉冲（在 _t 上叠加各自相位）
	var t := Time.get_ticks_msec() / 1000.0
	for i in _pulse_panels.size():
		var p: PanelContainer = _pulse_panels[i]
		p.modulate = Color.WHITE.lerp(Color(1.35, 1.2, 0.8),
			0.5 + 0.5 * sin(t * 3.2 + i * 1.7))


func _build() -> void:
	add_child(UICommon.dim_overlay())

	var popup := UICommon.popup_panel(520.0)
	add_child(popup)
	var panel: PanelContainer = popup.get_meta("panel")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.12, 0.96)
	sb.border_color = Color(0.3, 0.34, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	_title_label = UICommon.label("获得物资", 24, UICommon.GOLD)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	header.add_child(UICommon.label("搜刮完成", 14, UICommon.DIM))

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 6)
	_scroll.add_child(_rows_box)

	_flash_label = UICommon.label(" ", 15, UICommon.ORANGE)
	box.add_child(_flash_label)

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
	_title_label.text = String(container.interact_prompt())
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


## 稀有度 → 行底色 / 边框。
func _rarity_style(quality: String, rare: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.075, 0.1, 0.88)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	match quality:
		"fine":
			sb.border_color = Color(0.4, 0.75, 0.95, 0.9)
			sb.set_border_width_all(2)
			sb.bg_color = Color(0.08, 0.14, 0.2, 0.88)
		"pristine":
			sb.border_color = UICommon.GOLD
			sb.set_border_width_all(2)
			sb.bg_color = Color(0.22, 0.17, 0.07, 0.9)
		"worn":
			sb.border_color = Color(0.4, 0.4, 0.45, 0.8)
			sb.set_border_width_all(1)
		_:
			sb.border_color = Color(0.55, 0.55, 0.6, 0.8)
			sb.set_border_width_all(1)
	if rare:
		sb.set_border_width_all(3)
	return sb


func _refresh() -> void:
	if _rows_box == null:
		return
	_pulse_panels.clear()
	for c in _rows_box.get_children():
		c.queue_free()
	# 面板高度随内容收缩（约 4 条内不出滚动条）
	_scroll.custom_minimum_size = Vector2(0,
		minf(66.0 * _entries.size() + 6.0, 264.0))
	if _entries.is_empty():
		close()
		return
	for i in _entries.size():
		_rows_box.add_child(_build_row(i))


func _build_row(index: int) -> Control:
	var entry: Dictionary = _entries[index]
	var row := PanelContainer.new()
	var mat_entry: bool = entry.has("mat")
	var info: Dictionary
	var q: Dictionary
	var slots := 1
	var high_value := false
	var rare := false
	if mat_entry:
		q = {"name": "材料", "color": UICommon.CYAN}
		info = ItemDBRes.MATERIALS[entry["mat"]]
	else:
		info = ItemDBRes.TREASURES[entry["id"]]
		q = ItemDBRes.QUALITIES[entry["quality"]]
		slots = int(info["slots"])
		rare = bool(info["rare"])
		high_value = rare and GameState.value_of(entry) >= 300
	row.add_theme_stylebox_override("panel", _rarity_style(
		"标准" if mat_entry else String(entry["quality"]), rare))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	# 图标（品质描边；高价值呼吸脉冲）
	var icon: PanelContainer = UICommon.quality_icon(
		String(entry["mat"] if mat_entry else entry["id"]),
		q["color"] if not rare else UICommon.GOLD, 46)
	hbox.add_child(icon)
	if high_value:
		_pulse_panels.append(icon)

	# 名称 + 估值/占格
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	hbox.add_child(mid)
	var name_label: Label
	if mat_entry:
		name_label = UICommon.label("材料 · %s" % info["name"], 18, q["color"])
	else:
		name_label = UICommon.label("%s%s·%s" % [
			"★ " if rare else "", q["name"], info["name"]], 18,
			UICommon.GOLD if high_value else q["color"])
	mid.add_child(name_label)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 8)
	mid.add_child(sub)
	var value_color := UICommon.GOLD if high_value else UICommon.DIM
	var value: int = int(info["price"]) if mat_entry else GameState.value_of(entry)
	sub.add_child(UICommon.label("估值 %d" % value, 15, value_color))
	var slots_label := UICommon.label("占 %d 格" % slots, 15, UICommon.DIM)
	slots_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_child(slots_label)
	if high_value:
		sub.add_child(UICommon.label("高价值", 14, Color(0.98, 0.6, 0.15)))

	# 拾取按钮
	var btn := UICommon.button("拾取", 16)
	btn.disabled = not mat_entry and not GameState.can_carry(slots)
	btn.pressed.connect(_try_take.bind(index))
	btn.pressed.connect(_refresh)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(btn)
	return row
