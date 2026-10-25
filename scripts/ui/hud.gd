extends CanvasLayer
## V0.5 水下 HUD：信息按任务六节布局重做。
## 左上 生命/体力 · 顶部中央 撤离倒计时（区域名切换时短暂淡入淡出）·
## 右上 背包占用/战利品估值 · 上下文 E 键交互提示与搜索进度 ·
## 仅危险时显示的警告（鲨鱼/低体力/返航风险/巨影）· 飘字。
## 常驻操作说明与调试文本已移除（按键说明见 README）。

const MapDataRes := preload("res://scripts/map_data.gd")
const BalanceRes := preload("res://scripts/balance.gd")

const HUD_ICON := "res://assets/icons/hud/"

var player: CharacterBody2D
var dive: Node2D

var _hp_icons: Array = []
var _stamina_bar: ProgressBar
var _breath_label: Label
var _bag_label: Label
var _value_label: Label
var _seed_label: Label
var _zone_label: Label
var _zone_show_t := 0.0
var _last_zone := "__init__"
var _time_label: Label
var _warning_label: Label
var _prompt_key: PanelContainer
var _prompt_label: Label
var _prompt_box: HBoxContainer
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


func setup(player_ref: CharacterBody2D, dive_ref: Node2D) -> void:
	player = player_ref
	dive = dive_ref


func _ready() -> void:
	layer = 5
	_build()


func _icon(name: String, size := 18) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(HUD_ICON + name + ".png")
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tr


func _keycap(letter: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.16, 0.92)
	sb.border_color = Color(0.62, 0.66, 0.72)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", sb)
	var l := UICommon.label(letter, 15, UICommon.TEXT)
	panel.add_child(l)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return panel


## 文字深色描边：保证亮水面上与暗舱内的对比度。
func _outline_text(l: Label, width := 5) -> void:
	l.add_theme_constant_override("outline_size", width)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.11, 0.92))


func _build() -> void:
	# 临界体力红晕（最底层，不拦截鼠标）
	_vignette = ColorRect.new()
	_vignette.color = Color(0.75, 0.08, 0.08, 0.0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	# 顶栏：左侧（生命/体力）与右侧（背包/估值）各一块木纹面板
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 10
	top.offset_right = -10
	top.offset_top = 8
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	var left_panel := UICommon.wood_panel(0.92)
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(left_panel)
	var tl := VBoxContainer.new()
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_theme_constant_override("separation", 6)
	left_panel.add_child(tl)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 5)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(hp_row)
	for i in 3:
		var heart := _icon("hud_heart", 17)
		hp_row.add_child(heart)
		_hp_icons.append(heart)

	var stam_row := HBoxContainer.new()
	stam_row.add_theme_constant_override("separation", 7)
	stam_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(stam_row)
	stam_row.add_child(_icon("hud_bolt", 15))
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(214, 13)
	_stamina_bar.show_percentage = false
	_stamina_bar.max_value = 100.0
	_stamina_bar.value = 100.0
	_stamina_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stam_row.add_child(_stamina_bar)

	# 换气提示（贴近海面时才出现）
	_breath_label = UICommon.label("", 15, UICommon.GOOD)
	_outline_text(_breath_label)
	tl.add_child(_breath_label)

	# 返航风险（仅体力不足时作为危险提示出现）
	_return_label = UICommon.label("", 16, UICommon.DANGER)
	_outline_text(_return_label)
	tl.add_child(_return_label)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(top_spacer)

	var right_panel := UICommon.wood_panel(0.92)
	right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(right_panel)
	var tr := VBoxContainer.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.add_theme_constant_override("separation", 3)
	right_panel.add_child(tr)
	var bag_row := HBoxContainer.new()
	bag_row.add_theme_constant_override("separation", 7)
	bag_row.alignment = BoxContainer.ALIGNMENT_END
	bag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.add_child(bag_row)
	_bag_label = UICommon.label("0/8", 20)
	bag_row.add_child(_bag_label)
	bag_row.add_child(_icon("hud_bag", 18))
	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 7)
	value_row.alignment = BoxContainer.ALIGNMENT_END
	value_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.add_child(value_row)
	_value_label = UICommon.label("0", 20, UICommon.GOLD)
	value_row.add_child(_value_label)
	value_row.add_child(_icon("hud_coin", 18))
	_seed_label = UICommon.label("", 13, UICommon.DIM)
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_seed_label)

	# 顶部中央：撤离倒计时（沙漏 + 木纹小面板）；区域名只在新进入区域时短暂显示
	var time_panel := UICommon.wood_panel(0.82)
	time_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	time_panel.anchor_left = 0.5
	time_panel.anchor_right = 0.5
	time_panel.offset_top = 8
	time_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(time_panel)
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 7)
	time_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_panel.add_child(time_row)
	time_row.add_child(_icon("hud_timer", 16))
	_time_label = UICommon.label("", 18, UICommon.DIM)
	time_row.add_child(_time_label)

	_zone_label = UICommon.label("", 24, UICommon.CYAN)
	_zone_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_zone_label.anchor_left = 0.5
	_zone_label.anchor_right = 0.5
	_zone_label.offset_left = -200
	_zone_label.offset_right = 200
	_zone_label.offset_top = 46
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.visible = false
	_outline_text(_zone_label, 7)
	add_child(_zone_label)

	# 中央大警告（带警示三角图标，仅危险时出现）
	var warn_row := HBoxContainer.new()
	warn_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	warn_row.anchor_left = 0.5
	warn_row.anchor_right = 0.5
	warn_row.offset_left = -300
	warn_row.offset_right = 300
	warn_row.offset_top = 78
	warn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	warn_row.add_theme_constant_override("separation", 8)
	add_child(warn_row)
	warn_row.add_child(_icon("hud_warn", 24))
	_warning_label = UICommon.label("", 24, UICommon.DANGER)
	_outline_text(_warning_label, 6)
	warn_row.add_child(_warning_label)
	warn_row.name = "WarnRow"
	warn_row.visible = false

	# 巨影血条（Boss 活跃时显示）
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_box.anchor_left = 0.5
	_boss_box.anchor_right = 0.5
	_boss_box.offset_left = -170
	_boss_box.offset_right = 170
	_boss_box.offset_top = 110
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

	# 底部中央：飘字 + 上下文交互提示（E 键帽）+ 搜索进度 + 撤离提示
	var bc := VBoxContainer.new()
	bc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bc.anchor_left = 0.5
	bc.anchor_right = 0.5
	bc.offset_left = -260
	bc.offset_right = 260
	bc.offset_top = -170
	bc.offset_bottom = -56
	bc.alignment = BoxContainer.ALIGNMENT_END
	bc.add_theme_constant_override("separation", 8)
	add_child(bc)

	_notice_box = VBoxContainer.new()
	_notice_box.alignment = BoxContainer.ALIGNMENT_END
	_notice_box.add_theme_constant_override("separation", 2)
	bc.add_child(_notice_box)

	_prompt_box = HBoxContainer.new()
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.add_theme_constant_override("separation", 9)
	bc.add_child(_prompt_box)
	_prompt_key = _keycap("E")
	_prompt_box.add_child(_prompt_key)
	_prompt_label = UICommon.label("", 18)
	_prompt_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_outline_text(_prompt_label)
	_prompt_box.add_child(_prompt_label)

	_search_bar = ProgressBar.new()
	_search_bar.custom_minimum_size = Vector2(260, 12)
	_search_bar.show_percentage = false
	_search_bar.visible = false
	bc.add_child(_search_bar)

	_extract_label = UICommon.label("按 E 撤离，返回荒岛", 22, UICommon.GOLD)
	_outline_text(_extract_label, 6)
	_extract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_extract_label.visible = false
	bc.add_child(_extract_label)


func _process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player):
		return

	# 体力
	var ratio: float = player.stamina / player.max_stamina if player.max_stamina > 0.0 else 0.0
	_stamina_bar.value = ratio * 100.0
	var fill := StyleBoxFlat.new()
	if player.breathing:
		fill.bg_color = UICommon.GOOD.lerp(Color(0.7, 1.0, 0.8), 0.5 + 0.5 * sin(_t * 6.0))
		_breath_label.text = "正在换气：体力恢复中 +%d/秒" % int(BalanceRes.SURFACE_REGEN)
		_breath_label.modulate.a = 0.6 + 0.4 * sin(_t * 5.0)
	else:
		fill.bg_color = UICommon.DANGER if ratio <= BalanceRes.CRIT_STAMINA_RATIO \
			else (UICommon.ORANGE if ratio <= BalanceRes.LOW_STAMINA_RATIO else UICommon.CYAN)
		_breath_label.text = ""
	fill.set_corner_radius_all(4)
	_stamina_bar.add_theme_stylebox_override("fill", fill)

	# 生命：失掉的心变暗
	for i in _hp_icons.size():
		(_hp_icons[i] as TextureRect).modulate = Color.WHITE if i < player.hp \
			else Color(0.28, 0.24, 0.26, 0.7)

	# 背包与估值
	_bag_label.text = "%d/%d" % [GameState.bag_used_slots(), GameState.bag_capacity()]
	_value_label.text = "%d" % GameState.dive_total_value()
	if dive != null:
		_seed_label.text = "海况 #%d" % dive.dive_seed

	# 区域名：切换区域时短暂显示后淡出
	if dive != null and is_instance_valid(player):
		var zone: String = dive.get_zone_label()
		if zone != _last_zone:
			_last_zone = zone
			if zone != "":
				_zone_label.text = zone
				_zone_show_t = 2.4
		if _zone_show_t > 0.0:
			_zone_show_t -= delta
			_zone_label.modulate.a = clampf(_zone_show_t / 0.5, 0.0, 1.0)
			_zone_label.visible = true
		else:
			_zone_label.visible = false

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

	# 上下文交互提示：靠近可交互物才出现
	var searching: bool = player.is_searching() and player.active_chest != null \
		and is_instance_valid(player.active_chest)
	if searching:
		_prompt_key.visible = true
		_prompt_label.text = "正在搜索：%s" % player.active_chest.interact_prompt()
		_search_bar.visible = true
		_search_bar.value = player.active_chest.search_ratio() * 100.0
	elif player.focus_target != null:
		var target = player.focus_target
		if target.has_method("prompt_verb"):
			_prompt_label.text = "%s %s" % [target.prompt_verb(), target.interact_prompt()]
		elif target.has_method("begin_search"):
			_prompt_label.text = "长按 E 搜索 %s" % target.interact_prompt()
		else:
			_prompt_label.text = target.interact_prompt()
		_prompt_key.visible = true
		_search_bar.visible = false
	else:
		_prompt_box.visible = false
		_search_bar.visible = false
	if player.focus_target != null or searching:
		_prompt_box.visible = true

	# 撤离提示
	_extract_label.visible = dive != null and dive.in_extraction and not dive.ended

	# 返航风险：只有体力不足（危险）或换气中才提示，中性预估不再常驻
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
			_return_label.visible = false
	else:
		_return_label.visible = false

	# Boss 血条（活跃时显示，名字随 Boss 而定）
	var boss_active: bool = dive != null and dive.any_boss_active()
	_boss_box.visible = boss_active
	if boss_active:
		_boss_name_label.text = String(dive.boss.boss_name)
		_boss_bar.value = float(dive.boss.hp) / float(dive.boss.hp_max)

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
	var warn_row := get_node_or_null("WarnRow")
	if dive != null and dive.any_boss_active():
		_show_warning("%s盯上了你！" % dive.boss.boss_name, Color(0.8, 0.5, 0.85))
	elif dive != null and dive.any_shark_alerting():
		_show_warning("危险！鲨鱼发现了你！", UICommon.DANGER)
	elif player.breathing:
		if warn_row != null:
			warn_row.visible = false
	elif ratio <= BalanceRes.CRIT_STAMINA_RATIO:
		_show_warning("体力即将耗尽！立即返航！", UICommon.DANGER)
	elif ratio <= BalanceRes.LOW_STAMINA_RATIO:
		_show_warning("体力不足，建议返航", UICommon.ORANGE)
	else:
		if warn_row != null:
			warn_row.visible = false


func _show_warning(text: String, color: Color) -> void:
	var warn_row := get_node_or_null("WarnRow")
	if warn_row == null:
		return
	_warning_label.text = text
	_warning_label.add_theme_color_override("font_color", color)
	warn_row.modulate.a = 0.55 + 0.45 * sin(_t * 9.0)
	warn_row.visible = true


## 飘字提示（拾取、空间不足等），1.4 秒后消失。
func spawn_notice(text: String, color: Color) -> void:
	var l := UICommon.label(text, 19, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline_text(l, 4)
	_notice_box.add_child(l)
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(l, "modulate:a", 0.0, 0.5)
	tween.tween_callback(l.queue_free)
