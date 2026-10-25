extends CanvasLayer
## 水下 HUD：生命 / 体力 / 背包与估值 / 交互与搜索进度 / 危险警告 / 撤离提示 / 飘字。

const MapDataRes := preload("res://scripts/map_data.gd")
const BalanceRes := preload("res://scripts/balance.gd")

var player: CharacterBody2D
var dive: Node2D

var _hp_dots: Array = []
var _stamina_bar: ProgressBar
var _breath_label: Label
var _bag_label: Label
var _value_label: Label
var _seed_label: Label
var _zone_label: Label
var _time_label: Label
var _warning_label: Label
var _prompt_label: Label
var _search_bar: ProgressBar
var _extract_label: Label
var _notice_box: VBoxContainer
var _return_label: Label
var _vignette: ColorRect
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_name_label: Label
var _heartbeat_cd := 0.0
var _t := 0.0
var _hint_base := "WASD 游动 · Shift 冲刺 · 长按 E 搜索 · Tab 背包 · Esc 暂停"


func setup(player_ref: CharacterBody2D, dive_ref: Node2D) -> void:
	player = player_ref
	dive = dive_ref


func _ready() -> void:
	layer = 5
	_build()


func _build() -> void:
	# 临界体力红晕（最底层，不拦截鼠标）
	_vignette = ColorRect.new()
	_vignette.color = Color(0.75, 0.08, 0.08, 0.0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	# 左上：生命 + 体力
	var tl := VBoxContainer.new()
	tl.position = Vector2(16, 12)
	tl.add_theme_constant_override("separation", 6)
	add_child(tl)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	tl.add_child(hp_row)
	hp_row.add_child(UICommon.label("生命", 18, UICommon.TEXT))
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 5)
	hp_row.add_child(dots)
	for i in 3:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 18)
		var sb := StyleBoxFlat.new()
		sb.bg_color = UICommon.DANGER
		sb.set_corner_radius_all(4)
		dot.add_theme_stylebox_override("panel", sb)
		dots.add_child(dot)
		_hp_dots.append(dot)

	var stam_row := HBoxContainer.new()
	stam_row.add_theme_constant_override("separation", 8)
	tl.add_child(stam_row)
	stam_row.add_child(UICommon.label("体力", 18, UICommon.TEXT))
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(230, 20)
	_stamina_bar.show_percentage = false
	_stamina_bar.max_value = 100.0
	_stamina_bar.value = 100.0
	stam_row.add_child(_stamina_bar)

	# 换气提示（贴近开放海面时显示）
	_breath_label = UICommon.label("", 15, UICommon.GOOD)
	tl.add_child(_breath_label)

	# 返航体力预估：支撑"现在返航还来得及吗"的决策
	_return_label = UICommon.label("", 15, UICommon.DIM)
	tl.add_child(_return_label)

	# 右上：背包 + 估值
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(1264 - 220, 12)
	tr.custom_minimum_size = Vector2(204, 0)
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(tr)
	_bag_label = UICommon.label("背包 0/8", 20)
	tr.add_child(_bag_label)
	_value_label = UICommon.label("本次估值 0", 20, UICommon.GOLD)
	tr.add_child(_value_label)
	_seed_label = UICommon.label("", 13, UICommon.DIM)
	tr.add_child(_seed_label)

	# 顶部中央：区域名 + 撤离窗口倒计时
	_zone_label = UICommon.label("", 16, UICommon.DIM)
	_zone_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_zone_label.anchor_left = 0.5
	_zone_label.anchor_right = 0.5
	_zone_label.offset_left = -150
	_zone_label.offset_right = 150
	_zone_label.offset_top = 12
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_zone_label)

	_time_label = UICommon.label("", 18, UICommon.DIM)
	_time_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_time_label.anchor_left = 0.5
	_time_label.anchor_right = 0.5
	_time_label.offset_left = -150
	_time_label.offset_right = 150
	_time_label.offset_top = 36
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_time_label)

	# 中央大警告
	_warning_label = UICommon.label("", 26, UICommon.DANGER)
	_warning_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_warning_label.anchor_left = 0.5
	_warning_label.anchor_right = 0.5
	_warning_label.offset_left = -300
	_warning_label.offset_right = 300
	_warning_label.offset_top = 90
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.visible = false
	add_child(_warning_label)

	# 巨影血条（Boss 活跃时显示）
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_box.anchor_left = 0.5
	_boss_box.anchor_right = 0.5
	_boss_box.offset_left = -170
	_boss_box.offset_right = 170
	_boss_box.offset_top = 64
	_boss_box.visible = false
	add_child(_boss_box)
	_boss_name_label = UICommon.label("深渊巨影", 16, Color(0.8, 0.5, 0.85))
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name_label)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(0, 12)
	_boss_bar.show_percentage = false
	_boss_bar.max_value = 1.0
	_boss_box.add_child(_boss_bar)

	# 底部中央：交互提示 + 搜索进度 + 撤离提示
	var bc := VBoxContainer.new()
	bc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bc.anchor_left = 0.5
	bc.anchor_right = 0.5
	bc.offset_left = -260
	bc.offset_right = 260
	bc.offset_top = -170
	bc.offset_bottom = -60
	bc.alignment = BoxContainer.ALIGNMENT_END
	bc.add_theme_constant_override("separation", 8)
	add_child(bc)

	_notice_box = VBoxContainer.new()
	_notice_box.alignment = BoxContainer.ALIGNMENT_END
	_notice_box.add_theme_constant_override("separation", 2)
	bc.add_child(_notice_box)

	_prompt_label = UICommon.label("", 20)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bc.add_child(_prompt_label)

	_search_bar = ProgressBar.new()
	_search_bar.custom_minimum_size = Vector2(260, 14)
	_search_bar.show_percentage = false
	_search_bar.visible = false
	bc.add_child(_search_bar)

	_extract_label = UICommon.label("按 E 撤离，返回荒岛", 24, UICommon.GOLD)
	_extract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_extract_label.visible = false
	bc.add_child(_extract_label)

	# 右下：操作提示
	var hint := UICommon.label(_hint_base, 14, UICommon.DIM)
	hint.name = "HintLabel"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.anchor_left = 1.0
	hint.anchor_top = 1.0
	hint.anchor_right = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -470
	hint.offset_top = -30
	hint.offset_right = -12
	hint.offset_bottom = -8
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint)


func _process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player):
		return

	# 体力
	var ratio: float = player.stamina / player.max_stamina if player.max_stamina > 0.0 else 0.0
	_stamina_bar.value = ratio * 100.0
	var fill := StyleBoxFlat.new()
	if player.breathing:
		# 换气恢复动画：绿色条 + 呼吸脉冲
		fill.bg_color = UICommon.GOOD.lerp(Color(0.7, 1.0, 0.8), 0.5 + 0.5 * sin(_t * 6.0))
		_breath_label.text = "正在换气：体力恢复中 +%d/秒" % int(BalanceRes.SURFACE_REGEN)
		_breath_label.modulate.a = 0.6 + 0.4 * sin(_t * 5.0)
	else:
		fill.bg_color = UICommon.DANGER if ratio <= BalanceRes.CRIT_STAMINA_RATIO \
			else (UICommon.ORANGE if ratio <= BalanceRes.LOW_STAMINA_RATIO else UICommon.CYAN)
		_breath_label.text = ""
	fill.set_corner_radius_all(4)
	_stamina_bar.add_theme_stylebox_override("fill", fill)

	# 生命
	for i in _hp_dots.size():
		var sb: StyleBoxFlat = _hp_dots[i].get_theme_stylebox("panel")
		sb.bg_color = UICommon.DANGER if i < player.hp else Color(0.22, 0.2, 0.22)

	# 背包与估值
	_bag_label.text = "背包 %d/%d" % [GameState.bag_used_slots(), GameState.bag_capacity()]
	_value_label.text = "本次估值 %d" % GameState.dive_total_value()
	if dive != null:
		_seed_label.text = "海况 #%d · %s" % [dive.dive_seed,
			MapDataRes.THEME_NAMES.get(dive.dive_theme, "")]

	# 区域（含变体名，体现本次"海况"）
	if dive != null and is_instance_valid(player):
		_zone_label.text = dive.get_zone_label()

	# 撤离窗口倒计时
	if dive != null and not dive.ended:
		var t: float = maxf(0.0, dive.time_left)
		_time_label.text = "撤离窗口 %d:%02d" % [int(t) / 60, int(t) % 60]
		if t < 30.0:
			_time_label.add_theme_color_override("font_color", UICommon.DANGER)
			_time_label.modulate.a = 0.6 + 0.4 * sin(_t * 10.0)
		elif t < 120.0:
			_time_label.add_theme_color_override("font_color", UICommon.ORANGE)
			_time_label.modulate.a = 1.0
		else:
			_time_label.add_theme_color_override("font_color", UICommon.DIM)
			_time_label.modulate.a = 1.0
	else:
		_time_label.text = ""

	# 交互与搜索
	var searching: bool = player.is_searching() and player.active_chest != null \
		and is_instance_valid(player.active_chest)
	if searching:
		_prompt_label.text = "正在搜索：%s" % player.active_chest.interact_prompt()
		_search_bar.visible = true
		_search_bar.value = player.active_chest.search_ratio() * 100.0
	elif player.focus_target != null:
		var target = player.focus_target
		if target.has_method("prompt_verb"):
			_prompt_label.text = "%s：%s" % [target.prompt_verb(), target.interact_prompt()]
		elif target.has_method("begin_search"):
			_prompt_label.text = "长按 E 搜索：%s" % target.interact_prompt()
		else:
			_prompt_label.text = "按 E：%s" % target.interact_prompt()
		_search_bar.visible = false
	else:
		_prompt_label.text = ""
		_search_bar.visible = false

	# 撤离提示
	_extract_label.visible = dive != null and dive.in_extraction and not dive.ended

	# 返航体力预估（按游泳效率保守估算；换气中不会误报不足）
	var alive: bool = not player.dead and dive != null and not dive.ended
	if alive and not dive.in_extraction and player.global_position.x > 700.0:
		var ec: Vector2 = MapDataRes.EXTRACT_RECT.get_center()
		if dive.has_method("extract_center"):
			ec = dive.extract_center()
		var dist: float = player.global_position.distance_to(ec)
		var speed: float = BalanceRes.SWIM_SPEED * GameState.speed_mult() * GameState.weight_speed_mult()
		var cost: float = dist / speed * BalanceRes.DRAIN_SWIM * GameState.weight_drain_mult()
		if player.breathing:
			_return_label.text = "换气中——恢复后继续探索或返航"
			_return_label.add_theme_color_override("font_color", UICommon.GOOD)
			_return_label.visible = true
		elif cost > player.stamina:
			_return_label.text = "体力不足以返航！（约需 %d）" % ceili(cost)
			_return_label.add_theme_color_override("font_color", UICommon.DANGER)
			_return_label.visible = true
		else:
			_return_label.text = "返航预计消耗 %d 体力" % ceili(cost)
			_return_label.add_theme_color_override("font_color", UICommon.DIM)
			_return_label.visible = true
	else:
		_return_label.visible = false

	# Boss 血条（活跃时显示，名字随 Boss 而定）
	var boss_active: bool = dive != null and dive.any_boss_active()
	_boss_box.visible = boss_active
	if boss_active:
		_boss_name_label.text = String(dive.boss.boss_name)
		_boss_bar.value = float(dive.boss.hp) / float(dive.boss.hp_max)

	# 操作提示（拥有鱼叉后追加）
	var hint_label := get_node_or_null("HintLabel")
	if hint_label != null:
		hint_label.text = _hint_base + (" · 空格 鱼叉刺击" if GameState.has_harpoon else "")

	# 临界体力：红晕脉冲 + 心跳（换气恢复期间不告警）
	if alive and not player.breathing and ratio <= BalanceRes.CRIT_STAMINA_RATIO:
		_vignette.color.a = 0.14 + 0.1 * (0.5 + 0.5 * sin(_t * 7.0))
		_heartbeat_cd -= delta
		if _heartbeat_cd <= 0.0:
			_heartbeat_cd = 0.95
			Sfx.play("heartbeat", -2.0)
	else:
		_vignette.color.a = 0.0
		_heartbeat_cd = 0.0

	# 危险警告（优先级：Boss > 鲨鱼 > 重度低体力 > 低体力；换气中不提示体力警告）
	if dive != null and dive.any_boss_active():
		_show_warning("%s盯上了你！" % dive.boss.boss_name, Color(0.8, 0.5, 0.85))
	elif dive != null and dive.any_shark_alerting():
		_show_warning("危险！鲨鱼发现了你！", UICommon.DANGER)
	elif player.breathing:
		_warning_label.visible = false
	elif ratio <= BalanceRes.CRIT_STAMINA_RATIO:
		_show_warning("体力即将耗尽！立即返航！", UICommon.DANGER)
	elif ratio <= BalanceRes.LOW_STAMINA_RATIO:
		_show_warning("体力不足，建议返航", UICommon.ORANGE)
	else:
		_warning_label.visible = false


func _show_warning(text: String, color: Color) -> void:
	_warning_label.text = text
	_warning_label.add_theme_color_override("font_color", color)
	_warning_label.modulate.a = 0.55 + 0.45 * sin(_t * 9.0)
	_warning_label.visible = true


## 飘字提示（拾取、空间不足等），1.4 秒后消失。
func spawn_notice(text: String, color: Color) -> void:
	var l := UICommon.label(text, 20, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_box.add_child(l)
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(l, "modulate:a", 0.0, 0.5)
	tween.tween_callback(l.queue_free)
