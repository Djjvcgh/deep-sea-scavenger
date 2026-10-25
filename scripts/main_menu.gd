extends Control
## 主菜单：开始新游戏 / 继续游戏 / 设置 / 退出。
## 音量与全屏设置持久化到 user://settings.json。

const SETTINGS_PATH := "user://settings.json"

var _bubbles: Array = []
var _t := 0.0
var _volume := 80.0
var _fullscreen := false


func _ready() -> void:
	_load_settings()
	_apply_audio()
	if _fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_build_background()
	_build_ui()
	Sfx.play_ambient("ambient_island")


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_volume = clampf(float(parsed.get("volume", 80.0)), 0.0, 100.0)
	_fullscreen = bool(parsed.get("fullscreen", false))


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		push_error("设置写入失败")
		return
	f.store_string(JSON.stringify({"volume": _volume, "fullscreen": _fullscreen}))
	f.close()


func _apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(_volume / 100.0) if _volume > 0.0 else -80.0)


func _build_background() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	grad.colors = PackedColorArray([
		Color(0.55, 0.78, 0.82), Color(0.1, 0.38, 0.46), Color(0.02, 0.1, 0.16)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 256
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	for i in 12:
		var bubble := Polygon2D.new()
		var r := randf_range(3.0, 10.0)
		bubble.polygon = _ellipse(r, r, 8)
		bubble.position = Vector2(randf_range(0, 1280), randf_range(200, 760))
		bubble.color = Color(1, 1, 1, randf_range(0.08, 0.2))
		add_child(bubble)
		_bubbles.append(bubble)


func _build_ui() -> void:
	var title := UICommon.label("深海摸金", 76, UICommon.GOLD)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -300
	title.offset_right = 300
	title.offset_top = 96
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var subtitle := UICommon.label("Deep Sea Scavenger · v0.1", 20, UICommon.DIM)
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.anchor_left = 0.5
	subtitle.anchor_right = 0.5
	subtitle.offset_left = -300
	subtitle.offset_right = 300
	subtitle.offset_top = 196
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -120
	box.offset_right = 120
	box.offset_top = -60
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var new_btn := UICommon.button("开始新游戏", 24)
	new_btn.pressed.connect(_on_new_game)
	box.add_child(new_btn)

	var continue_btn := UICommon.button("继续游戏", 24)
	continue_btn.disabled = not SaveManager.has_save()
	continue_btn.pressed.connect(_on_continue)
	box.add_child(continue_btn)

	var settings_btn := UICommon.button("设置", 24)
	settings_btn.pressed.connect(_on_settings)
	box.add_child(settings_btn)

	var level_btn := UICommon.button("关卡测试：黑潮号残骸（V0.5）", 18)
	level_btn.pressed.connect(_on_blacktide)
	box.add_child(level_btn)

	var quit_btn := UICommon.button("退出", 24)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit_btn)

	var hint := UICommon.label("有限体力 + 有限背包 —— 搜刮宝物，活着带回岸上", 17, UICommon.DIM)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.offset_left = -400
	hint.offset_right = 400
	hint.offset_top = -64
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func _on_new_game() -> void:
	Sfx.play("click")
	if SaveManager.has_save():
		var dlg := ConfirmationDialog.new()
		dlg.dialog_text = "开始新游戏将覆盖现有存档，是否继续？"
		dlg.ok_button_text = "覆盖存档"
		dlg.cancel_button_text = "取消"
		dlg.confirmed.connect(_start_new)
		add_child(dlg)
		dlg.popup_centered()
	else:
		_start_new()


func _start_new() -> void:
	GameState.reset_defaults()
	SaveManager.save_game(GameState.serialize())
	get_tree().change_scene_to_file("res://scenes/island.tscn")


func _on_continue() -> void:
	Sfx.play("click")
	GameState.apply_save(SaveManager.load_game())
	get_tree().change_scene_to_file("res://scenes/island.tscn")


## V0.5 独立测试关卡：进入前不读写存档，关卡自身保护并还原现场。
func _on_blacktide() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/level_blacktide.tscn")


func _on_settings() -> void:
	Sfx.play("click")
	var popup := UICommon.popup_panel(400.0)
	add_child(popup)
	popup.name = "Settings"
	var panel: PanelContainer = popup.get_meta("panel")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	box.add_child(UICommon.label("设置", 28, UICommon.GOLD))

	box.add_child(UICommon.label("主音量", 18))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = _volume
	slider.custom_minimum_size = Vector2(0, 24)
	slider.value_changed.connect(func(v: float) -> void:
		_volume = v
		_apply_audio()
		_save_settings())
	box.add_child(slider)

	var fullscreen := CheckButton.new()
	fullscreen.text = "全屏"
	fullscreen.button_pressed = _fullscreen
	fullscreen.toggled.connect(func(on: bool) -> void:
		_fullscreen = on
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
		_save_settings())
	box.add_child(fullscreen)

	var close_btn := UICommon.button("关闭", 18)
	close_btn.pressed.connect(popup.queue_free)
	box.add_child(close_btn)


func _process(delta: float) -> void:
	_t += delta
	for b in _bubbles:
		b.position.y -= (20.0 + b.position.x * 0.01) * delta * 3.0
		if b.position.y < 160.0:
			b.position.y = 780.0
			b.position.x = randf_range(0, 1280)


static func _ellipse(rx: float, ry: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
