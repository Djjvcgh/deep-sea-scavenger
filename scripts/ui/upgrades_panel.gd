extends CanvasLayer
## 装备工作台界面：三项永久升级，每项只能购买一次，升级逻辑集中在 GameState。

const ItemDBRes := preload("res://scripts/item_db.gd")

signal closed

var _rows_box: VBoxContainer
var _credits_label: Label
var _flash_label: Label
var _bag_box: VBoxContainer
var _weapon_box: VBoxContainer


func _ready() -> void:
	layer = 10
	visible = false
	_build()
	GameState.credits_changed.connect(_on_state_changed)
	GameState.upgrades_changed.connect(_on_state_changed)
	GameState.materials_changed.connect(_on_state_changed)
	GameState.bag_tier_changed.connect(_on_state_changed)


func _on_state_changed(_arg: Variant = null) -> void:
	_refresh()


func _build() -> void:
	add_child(UICommon.dim_overlay())
	var popup := UICommon.popup_panel(640.0)
	add_child(popup)
	var panel: PanelContainer = popup.get_meta("panel")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(UICommon.label("装备工作台", 28, UICommon.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_credits_label = UICommon.label("", 22, UICommon.GOLD)
	head.add_child(_credits_label)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 10)
	box.add_child(_rows_box)

	box.add_child(UICommon.vspace(4))
	box.add_child(UICommon.label("背包打造（材料来自海底）", 20, UICommon.CYAN))
	_bag_box = VBoxContainer.new()
	_bag_box.add_theme_constant_override("separation", 6)
	box.add_child(_bag_box)

	box.add_child(UICommon.vspace(4))
	box.add_child(UICommon.label("兵器打造（对抗深海生物）", 20, UICommon.CYAN))
	_weapon_box = VBoxContainer.new()
	_weapon_box.add_theme_constant_override("separation", 6)
	box.add_child(_weapon_box)

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
	closed.emit()


func _refresh() -> void:
	if not visible:
		return
	_credits_label.text = "交易额度 %d" % GameState.credits
	for c in _rows_box.get_children():
		c.queue_free()
	for id in ItemDBRes.UPGRADES:
		var u: Dictionary = ItemDBRes.UPGRADES[id]
		var owned: bool = GameState.upgrades[id]
		var row := PanelContainer.new()
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		row.add_child(inner)

		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		inner.add_child(line)
		var name_label := UICommon.label(u["name"], 20,
			UICommon.GOLD if owned else UICommon.TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		if owned:
			line.add_child(UICommon.label("已升级", 18, UICommon.GOOD))
		else:
			var buy := UICommon.button("购买（%d 额度）" % u["cost"], 16)
			buy.disabled = GameState.credits < int(u["cost"])
			buy.pressed.connect(_buy.bind(id))
			line.add_child(buy)

		inner.add_child(UICommon.label(u["desc"], 15, UICommon.DIM))
		_rows_box.add_child(row)

	_refresh_bag()
	_refresh_weapon()


func _refresh_weapon() -> void:
	for c in _weapon_box.get_children():
		c.queue_free()
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	if GameState.has_harpoon:
		var owned := UICommon.label("鱼叉 —— 已打造（空格键刺击）", 17, UICommon.GOOD)
		owned.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(owned)
	else:
		var name_label := UICommon.label("鱼叉：空格键刺击，可击杀鲨鱼、惊退巨影", 17)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		var parts: Array = []
		var enough := true
		for mat in ItemDBRes.HARPOON_CRAFT:
			var need := int(ItemDBRes.HARPOON_CRAFT[mat])
			var have := int(GameState.materials[mat])
			if have < need:
				enough = false
			parts.append("%s %d/%d" % [ItemDBRes.MATERIALS[mat]["name"], have, need])
		line.add_child(UICommon.label(" / ".join(parts), 15,
			UICommon.GOOD if enough else UICommon.DIM))
		var craft := UICommon.button("打造", 16)
		craft.disabled = not enough
		craft.pressed.connect(_craft_harpoon)
		line.add_child(craft)
	_weapon_box.add_child(line)


func _craft_harpoon() -> void:
	if GameState.craft_harpoon():
		_flash("鱼叉打造完成！空格键刺击")
		Sfx.play("build", -4.0)


func _refresh_bag() -> void:
	for c in _bag_box.get_children():
		c.queue_free()
	var tier: int = GameState.bag_tier
	var current: Dictionary = ItemDBRes.BAG_TIERS[tier]
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var cur := UICommon.label("当前：%s（%d 格）" % [current["name"], current["capacity"]], 17)
	cur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(cur)
	if tier + 1 >= ItemDBRes.BAG_TIERS.size():
		line.add_child(UICommon.label("已是最高级背包", 16, UICommon.GOOD))
	else:
		var next: Dictionary = ItemDBRes.BAG_TIERS[tier + 1]
		var cost: Dictionary = next["cost"]
		var parts: Array = []
		var enough := true
		for mat in cost:
			var need := int(cost[mat])
			var have := int(GameState.materials[mat])
			if have < need:
				enough = false
			parts.append("%s %d/%d" % [ItemDBRes.MATERIALS[mat]["name"], have, need])
		line.add_child(UICommon.label("%s（%d格）：" % [next["name"], next["capacity"]], 17))
		line.add_child(UICommon.label(" / ".join(parts), 15,
			UICommon.GOOD if enough else UICommon.DIM))
		var craft := UICommon.button("打造", 16)
		craft.disabled = not enough
		craft.pressed.connect(_craft)
		line.add_child(craft)
	_bag_box.add_child(line)


func _craft() -> void:
	if GameState.craft_bag():
		_flash("%s 打造完成！" % ItemDBRes.BAG_TIERS[GameState.bag_tier]["name"])
		Sfx.play("build", -4.0)


func _buy(id: String) -> void:
	var u: Dictionary = ItemDBRes.UPGRADES[id]
	if GameState.buy_upgrade(id):
		_flash("%s 升级完成！" % u["name"])
		Sfx.play("build", -4.0)


func _flash(text: String) -> void:
	_flash_label.text = text
	_flash_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_flash_label, "modulate:a", 0.0, 0.4)
