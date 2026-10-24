extends CanvasLayer
## 神秘商人界面：出售宝物 / 购买物资。交易额度不足时禁止购买。

const ItemDBRes := preload("res://scripts/item_db.gd")

var _credits_label: Label
var _sell_box: VBoxContainer
var _buy_box: VBoxContainer
var _flash_label: Label


func _ready() -> void:
	layer = 10
	visible = false
	_build()
	GameState.credits_changed.connect(_on_state_changed)
	GameState.island_stock_changed.connect(_on_state_changed)
	GameState.materials_changed.connect(_on_state_changed)


func _on_state_changed(_arg: Variant = null) -> void:
	_refresh()


func _build() -> void:
	add_child(UICommon.dim_overlay())
	var popup := UICommon.popup_panel(760.0)
	add_child(popup)
	var panel: PanelContainer = popup.get_meta("panel")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(UICommon.label("神秘商人", 28, UICommon.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_credits_label = UICommon.label("", 22, UICommon.GOLD)
	head.add_child(_credits_label)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	box.add_child(cols)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	cols.add_child(left)
	left.add_child(UICommon.label("出售宝物", 20, UICommon.CYAN))
	_sell_box = VBoxContainer.new()
	_sell_box.add_theme_constant_override("separation", 6)
	left.add_child(_sell_box)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UICommon.label("购买物资（用于造船）", 20, UICommon.CYAN))
	_buy_box = VBoxContainer.new()
	_buy_box.add_theme_constant_override("separation", 6)
	right.add_child(_buy_box)

	_flash_label = UICommon.label(" ", 18, UICommon.GOOD)
	box.add_child(_flash_label)

	var close_btn := UICommon.button("离开（Esc）", 18)
	close_btn.pressed.connect(close)
	box.add_child(close_btn)


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	visible = false


func _refresh() -> void:
	if not visible:
		return
	_credits_label.text = "交易额度 %d" % GameState.credits

	for c in _sell_box.get_children():
		c.queue_free()
	var counted := {}
	for id in GameState.island_stock:
		counted[id] = counted.get(id, 0) + 1
	if counted.is_empty():
		_sell_box.add_child(UICommon.label("暂无可出售宝物 —— 去海底搜寻吧", 16, UICommon.DIM))
	for id in counted:
		var info: Dictionary = ItemDBRes.TREASURES[id]
		var n: int = counted[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := UICommon.label("%s ×%d" % [info["name"], n], 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UICommon.label("单价%d · 共%d" % [info["value"], info["value"] * n], 15, UICommon.DIM))
		var one := UICommon.button("出售1", 15)
		one.pressed.connect(_sell_one.bind(id))
		row.add_child(one)
		var all_btn := UICommon.button("全部", 15)
		all_btn.pressed.connect(_sell_all.bind(id))
		row.add_child(all_btn)
		_sell_box.add_child(row)

	for c in _buy_box.get_children():
		c.queue_free()
	for id in ItemDBRes.MATERIALS:
		var m: Dictionary = ItemDBRes.MATERIALS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := UICommon.label("%s（持有 %d）" % [m["name"], GameState.materials[id]], 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UICommon.label("价格 %d" % m["price"], 15, UICommon.DIM))
		var buy := UICommon.button("购买1", 15)
		buy.disabled = GameState.credits < int(m["price"])
		buy.pressed.connect(_buy_mat.bind(id))
		row.add_child(buy)
		_buy_box.add_child(row)


func _sell_one(id: String) -> void:
	var info: Dictionary = ItemDBRes.TREASURES[id]
	if GameState.sell_one(id):
		_flash("出售 %s +%d" % [info["name"], info["value"]])
		Sfx.play("sell")


func _sell_all(id: String) -> void:
	var info: Dictionary = ItemDBRes.TREASURES[id]
	var n: int = GameState.sell_all_of(id)
	if n > 0:
		_flash("出售 %s×%d +%d" % [info["name"], n, info["value"] * n])
		Sfx.play("sell")


func _buy_mat(id: String) -> void:
	var m: Dictionary = ItemDBRes.MATERIALS[id]
	if GameState.buy_material(id):
		_flash("购入 %s ×1（-%d）" % [m["name"], m["price"]])
		Sfx.play("sell")


func _flash(text: String) -> void:
	_flash_label.text = text
	_flash_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_flash_label, "modulate:a", 0.0, 0.4)
