extends Node2D
## V0.5 独立测试关卡：黑潮号残骸（手工灰盒关卡，不参与程序化生成管线）。
##
## 结构（世界 3800×1250，撤离点在左上，沉船横卧中部）：
##   撤离点 → 外部礁沙海床 → 黑潮号：
##     · 安全路线（船底破口 y890-1010）→ 前货舱（普通宝物）→ 低门 → 轮机舱 →
##       顶门 → 船尾舱 → 落口 → 船长货舱（绕远、无鲨鱼）
##     · 危险路线（上层甲板，3 条鲨鱼巡逻）→ 甲板破口/瞭望舱（早接触高价值）→
##       桅杆断口 → 直落船尾舱 → 船长货舱（更快）
##     · 船长货舱：航海日志 + 船长金库（高价值重型宝物）+ 船尾神龛
##     · 隐藏密室：神龛后的暗门（日志线索 + 神龛蓝火视觉线索），内藏独特遗物
##     · 返航捷径：应急绞盘同时打开龙骨活门与夹层坍塌 → 龙骨夹层爬行道直通
##       前货舱船底口，返程更短且完全避开鲨鱼
##
## 调试：R 重置 · F1 背包档位 · F2 补满体力 · F3 鲨鱼清除/恢复 · F4 鱼叉。
## 存档保护：进入时快照全局状态，结束时从不写盘，退出关卡时原样还原。

const BalanceRes := preload("res://scripts/balance.gd")
const ItemDBRes := preload("res://scripts/item_db.gd")

const ChestScene := preload("res://scenes/treasure_chest.tscn")
const SharkScene := preload("res://scenes/shark.tscn")
const HudScene := preload("res://scenes/ui/hud.tscn")
const InventoryScene := preload("res://scenes/ui/inventory_panel.tscn")
const LootScene := preload("res://scenes/ui/loot_panel.tscn")
const ResultsScene := preload("res://scenes/ui/results_panel.tscn")
const PauseScene := preload("res://scenes/ui/pause_menu.tscn")
const SwitchScene := preload("res://scenes/level_switch.tscn")

const SPR := "res://assets/sprites/kenney_fish/"
const SCN := "res://assets/scenery/blacktide/"
const LEVEL_PATH := "res://scenes/level_blacktide.tscn"

const PLAYER_SPAWN := Vector2(240, 420)
const EXTRACT_RECT := Rect2(70, 80, 240, 300)

## 静态地形：[x, y, w, h, kind]，kind 决定配色（rock/sand/wreck/crate）。
const SOLIDS := [
	# 四壁与海床
	[-140, -200, 140, 1550, "rock"],
	[3700, -200, 140, 1550, "rock"],
	[-140, 1150, 3860, 400, "sand"],
	# 外部海域礁岩（撤离点到沉船之间的掩体与视觉锚点）
	[430, 1020, 140, 130, "rock"],
	[700, 960, 120, 190, "rock"],
	[520, 700, 90, 450, "rock"],
	# 黑潮号龙骨底板（船底）：1000-1120 前货舱船底口，2960-3070 龙骨活门（捷径）
	[960, 1030, 40, 40, "wreck"],
	[1120, 1030, 1840, 40, "wreck"],
	[3070, 1030, 170, 40, "wreck"],
	# 船头壁：y890-1010 为船底破口（安全路线入口）
	[900, 620, 60, 270, "wreck"],
	[900, 1010, 60, 140, "wreck"],
	# 船尾壁：y850-1010 段为密室暗门（可开关节点）
	[3240, 620, 60, 230, "wreck"],
	[3240, 1010, 60, 140, "wreck"],
	# 甲板：1240-1400 船头甲板破口，3050-3200 桅杆断口（危险路线入口）
	[900, 560, 340, 60, "wreck"],
	[1400, 560, 1650, 60, "wreck"],
	[3200, 560, 40, 60, "wreck"],
	# 1 号舱壁（前货舱|轮机舱），低门 y940-1030
	[2100, 620, 60, 320, "wreck"],
	# 2 号舱壁（轮机舱|船尾舱），顶门 y620-710
	[2860, 710, 60, 360, "wreck"],
	# 船尾中层甲板（船长货舱顶），2960-3070 为垂直落口
	[2920, 850, 40, 45, "wreck"],
	[3070, 850, 170, 45, "wreck"],
	# 前货舱货箱（障碍与掩体）
	[1320, 920, 110, 110, "crate"],
	[1620, 880, 90, 150, "crate"],
	[1880, 940, 120, 90, "crate"],
	# 轮机舱锅炉与吊管
	[2430, 850, 180, 180, "wreck"],
	[2700, 620, 24, 200, "wreck"],
	# 隐藏密室外壳（仅暗门可入）
	[3300, 790, 260, 60, "wreck"],
	[3300, 1010, 260, 140, "wreck"],
	[3560, 790, 140, 360, "rock"],
	# 瞭望舱（危险路线上早接触的高价值点），1600-1700 为破顶入口
	[1500, 440, 20, 120, "wreck"],
	[1760, 440, 20, 120, "wreck"],
	[1500, 420, 100, 20, "wreck"],
	[1700, 420, 80, 20, "wreck"],
	# 甲板掩体：断桅（同时分隔两条鲨鱼巡逻带）、横桁、货箱、船头挡浪板
	[2600, 320, 24, 240, "wreck"],
	[2280, 470, 200, 18, "wreck"],
	[1420, 512, 90, 48, "crate"],
	[980, 470, 120, 90, "wreck"],
]

## 可开关节点（初始封堵，交互后消失）：[x, y, w, h]
const DOOR_SPECS := {
	"secret": [3240, 850, 60, 160],     # 密室暗门（船尾神龛）
	"gate": [2960, 1030, 110, 40],      # 龙骨活门（应急绞盘）
	"wedge": [1980, 1070, 260, 80],     # 龙骨夹层坍塌（应急绞盘）
}

const ZONES := [
	{"name": "黑潮号 · 前货舱", "rect": Rect2(960, 620, 1140, 410)},
	{"name": "黑潮号 · 轮机舱", "rect": Rect2(2160, 620, 700, 410)},
	{"name": "黑潮号 · 船尾舱", "rect": Rect2(2920, 620, 320, 230)},
	{"name": "黑潮号 · 船长货舱", "rect": Rect2(2920, 895, 320, 135)},
	{"name": "黑潮号 · 密室", "rect": Rect2(3300, 850, 260, 160)},
	{"name": "黑潮号 · 龙骨夹层", "rect": Rect2(960, 1070, 2280, 80)},
]

const SHARK_PATROLS := [
	[1250.0, 2050.0, 385.0],
	[2150.0, 2560.0, 430.0],
	[2660.0, 3000.0, 395.0],
]

var player: CharacterBody2D
var hud: CanvasLayer
var inventory_panel: CanvasLayer
var loot_panel: CanvasLayer
var results_panel: CanvasLayer
var pause_menu: CanvasLayer

var in_extraction := false
var ended := false
var dive_seed := 505            # 展示用海况编号（HUD）
var dive_theme := "wreck"
var time_left := 0.0
var shortcut_open := false
var secret_open := false

var _snapshot: Dictionary = {}  # 进入关卡时的全局状态快照（退出时还原）
var _doors := {}                # key -> StaticBody2D
var _sharks: Array = []
var _sharks_cleared := false
var _extract_area: Area2D
var _canvas_mod: CanvasModulate
var _zone_seen := {}
var _tension_on := false
var _t := 0.0
var _seaweeds: Array = []
var _schools: Array = []
var _bubbles: Array = []
var _lantern_glow: Polygon2D
var _secret_glint: Polygon2D
var _gold_glints: Array = []
var _room_glows: Array = []


func _ready() -> void:
	_snapshot = GameState.serialize()
	GameState.start_dive()
	player = $Player
	time_left = BalanceRes.DIVE_TIME_LIMIT

	_build_environment()
	_build_terrain()
	_build_doors()
	_build_visual_world()
	_build_hold_dressing()
	_build_extraction()
	_spawn_chests()
	_spawn_switches()
	_spawn_sharks()

	player.reset_for_dive()
	player.z_index = 5
	player.global_position = PLAYER_SPAWN
	player.set_camera_limits(-100, -160, 3700, 1300)
	player.exhausted.connect(_on_dive_failed.bind("体力耗尽"))
	player.died.connect(_on_dive_failed.bind("生命归零"))

	hud = HudScene.instantiate()
	add_child(hud)
	hud.setup(player, self)
	player.notice.connect(func(text: String, color: Color) -> void:
		hud.spawn_notice(text, color))

	inventory_panel = InventoryScene.instantiate()
	add_child(inventory_panel)
	loot_panel = LootScene.instantiate()
	add_child(loot_panel)
	player.loot_collected.connect(_on_loot_collected)
	loot_panel.closed.connect(func() -> void: player.control_locked = false)
	results_panel = ResultsScene.instantiate()
	add_child(results_panel)
	results_panel.return_scene = LEVEL_PATH
	results_panel.return_button_text = "重新潜入（重置关卡）"
	pause_menu = PauseScene.instantiate()
	add_child(pause_menu)
	pause_menu.setup(true)

	hud.spawn_notice("黑潮号残骸：上层甲板快但有鲨鱼；船底破口安全但绕远", UICommon.CYAN)
	Sfx.play_ambient("ambient_underwater")


## 退出关卡（重置/结算/暂停菜单离开/关窗）时还原进入前的全局状态；
## 本关卡从不调用 SaveManager，磁盘存档不受影响。
func _exit_tree() -> void:
	Sfx.stop_tension()
	Sfx.stop_ambient()
	if not _snapshot.is_empty():
		GameState.apply_save(_snapshot)


func extract_center() -> Vector2:
	return EXTRACT_RECT.get_center()


func any_boss_active() -> bool:
	return false


func any_shark_alerting() -> bool:
	for s in get_tree().get_nodes_in_group("sharks"):
		if s.is_threatening():
			return true
	return false


func get_zone_label() -> String:
	if player == null or not is_instance_valid(player):
		return ""
	var p := player.global_position
	for z in ZONES:
		if (z["rect"] as Rect2).has_point(p):
			return String(z["name"])
	if p.x > 900.0 and p.x < 3300.0 and p.y < 560.0:
		return "黑潮号 · 上层甲板"
	if EXTRACT_RECT.grow(40.0).has_point(p):
		return "撤离浮标"
	if p.y < 300.0:
		return "开阔上层水域"
	return "外部海域 · 礁沙海床"


func _input(event: InputEvent) -> void:
	if loot_panel.visible:
		if event.is_action_pressed("interact"):
			loot_panel.take_all_and_close()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			loot_panel.close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") and not ended:
		inventory_panel.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		pause_menu.open()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_reset_level()
			KEY_F1:
				GameState.bag_tier = (GameState.bag_tier + 1) % ItemDBRes.BAG_TIERS.size()
				GameState.bag_tier_changed.emit()
				hud.spawn_notice("背包档位 → %s（容量 %d）"
					% [ItemDBRes.BAG_TIERS[GameState.bag_tier]["name"], GameState.bag_capacity()],
					UICommon.CYAN)
			KEY_F2:
				player.stamina = player.max_stamina
				player.stamina_changed.emit(player.stamina, player.max_stamina)
				hud.spawn_notice("体力已补满", UICommon.GOOD)
			KEY_F3:
				_toggle_sharks()
			KEY_F4:
				GameState.has_harpoon = not GameState.has_harpoon
				GameState.upgrades_changed.emit()
				hud.spawn_notice("鱼叉：%s" % ("已装备" if GameState.has_harpoon else "已卸下"), UICommon.CYAN)


func _reset_level() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_PATH)


func _toggle_sharks() -> void:
	if _sharks_cleared:
		_spawn_sharks()
		_sharks_cleared = false
		hud.spawn_notice("鲨鱼已恢复巡逻", UICommon.ORANGE)
	else:
		for s in _sharks:
			if is_instance_valid(s):
				s.queue_free()
		_sharks = []
		_sharks_cleared = true
		hud.spawn_notice("鲨鱼已清除", UICommon.CYAN)


func _physics_process(delta: float) -> void:
	if ended:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_end_dive(false, "撤离窗口已关闭")
		return
	if in_extraction and not player.is_searching() and Input.is_action_just_pressed("interact"):
		_end_dive(true)
		return
	_update_zone_discovery()


## 首次进入各舱室的发现提示（密室给含蓄提示——发现感留给视觉线索）。
func _update_zone_discovery() -> void:
	for i in ZONES.size():
		if _zone_seen.has(i):
			continue
		if (ZONES[i]["rect"] as Rect2).has_point(player.global_position):
			_zone_seen[i] = true
			if ZONES[i]["name"].ends_with("密室"):
				hud.spawn_notice("这里不该有房间……", Color(0.4, 0.95, 0.85))
			else:
				hud.spawn_notice("发现%s" % ZONES[i]["name"], UICommon.GOLD)
			Sfx.play("click", -4.0)


# ---------------- 结算 ----------------

func _end_dive(success: bool, fail_reason := "") -> void:
	if ended:
		return
	ended = true
	var items: Array = GameState.dive_bag.duplicate(true)
	var total := GameState.dive_total_value()
	var elapsed := (Time.get_ticks_msec() - GameState.dive_start_msec) / 1000.0
	GameState.end_dive(success, player.global_position)
	Sfx.stop_ambient()
	Sfx.stop_tension()
	Sfx.play("sell" if success else "fail")
	get_tree().paused = true
	results_panel.open(success, items, total, elapsed, dive_seed, fail_reason)


func _on_dive_failed(reason: String = "体力耗尽") -> void:
	if ended:
		return
	await get_tree().create_timer(BalanceRes.FAIL_RESULT_DELAY).timeout
	_end_dive(false, reason)


func _on_loot_collected(entries: Array, container: Area2D) -> void:
	if entries.is_empty():
		player.control_locked = false
		return
	loot_panel.open(entries, container)


# ---------------- 刷新 ----------------

func _spawn_chests() -> void:
	# 前货舱：普通宝物多、风险低（安全路线的稳定收益）
	for pos in [Vector2(1090, 985), Vector2(1520, 985), Vector2(1840, 985)]:
		_add_chest(pos, "货舱木箱", 2.5, Color(0.8, 0.85, 0.88, 0.5),
			func() -> Array: return _roll_loot(
				{2: 70, 3: 30},
				{"bronze_coins": 40, "pearl": 25, "silver_platter": 25, "old_coin": 10},
				ItemDBRes.CHEST_QUALITY_WEIGHTS["B"]))
	# 轮机舱：安全路线中段的进阶奖励
	_add_chest(Vector2(2790, 985), "轮机舱储物柜", 3.0, Color(0.86, 0.7, 0.5, 0.55),
		func() -> Array: return _roll_loot(
			{2: 60, 3: 40},
			{"silver_platter": 45, "gold_cup": 35, "bronze_coins": 20},
			ItemDBRes.CHEST_QUALITY_WEIGHTS["B"]))
	# 瞭望舱：危险路线上早接触的高价值宝箱
	_add_chest(Vector2(1640, 528), "瞭望舱铁柜", 3.5, Color(0.95, 0.78, 0.25, 0.7),
		func() -> Array: return _roll_loot(
			{2: 70, 3: 30},
			{"gold_cup": 65, "silver_platter": 35},
			ItemDBRes.CHEST_QUALITY_WEIGHTS["C"]))
	# 船长金库：高价值重型宝物（完美六分仪 + 精良金杯 = 6 格，逼出背包取舍）
	_add_chest(Vector2(3130, 985), "船长金库", 5.0, Color(0.98, 0.72, 0.15, 0.85),
		func() -> Array: return [
			{"id": "gold_sextant", "quality": "pristine"},
			{"id": "gold_cup", "quality": "fine"},
		])
	# 密室圣龛：独特遗物（黑潮号船首像）
	_add_chest(Vector2(3430, 955), "密室圣龛", 4.0, Color(0.4, 0.95, 0.85, 0.85),
		func() -> Array: return [
			{"id": "figurehead_blacktide", "quality": "pristine"},
		])


func _add_chest(pos: Vector2, cname: String, search_time: float,
		glow: Color, provider: Callable) -> void:
	var c := ChestScene.instantiate()
	c.position = pos
	add_child(c)
	c.setup_container({
		"kind": "chest", "name": cname, "search_time": search_time,
		"loot": provider, "glow": glow,
	})


func _roll_loot(count_w: Dictionary, pool: Dictionary, quality_w: Dictionary) -> Array:
	var out: Array = []
	var count := int(_weighted_roll(count_w))
	for i in count:
		out.append({
			"id": String(_weighted_roll(pool)),
			"quality": String(_weighted_roll(quality_w)),
		})
	return out


func _weighted_roll(weights: Dictionary) -> Variant:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := randf() * total
	var acc := 0.0
	for k in weights:
		acc += float(weights[k])
		if r <= acc:
			return k
	return weights.keys().back()


## 机关交互点：日志（线索）/ 神龛（密室）/ 绞盘（捷径）。
func _spawn_switches() -> void:
	_add_switch(Vector2(2940, 975), {
		"kind": "log", "name": "航海日志（残页）", "verb": "按 E 翻阅",
		"on_interact": Callable(self, "_read_log"),
	})
	_add_switch(Vector2(3225, 930), {
		"kind": "shrine", "name": "船尾神龛", "verb": "按 E 推开", "one_shot": true,
		"on_interact": Callable(self, "_pull_shrine"),
	})
	_add_switch(Vector2(3190, 985), {
		"kind": "winch", "name": "应急绞盘", "verb": "按 E 摇动", "one_shot": true,
		"on_interact": Callable(self, "_crank_winch"),
	})


func _read_log() -> void:
	hud.spawn_notice("「……黑潮吞了我们。真正的珍宝藏进龙骨尽头的暗室——」", Color(0.85, 0.8, 0.6))
	hud.spawn_notice("「——就在船尾神龛之后。」字迹旁刻着长翼船首像的涂鸦。", Color(0.85, 0.8, 0.6))


func _pull_shrine() -> void:
	_open_door("secret", "神龛后的暗板滑开——露出隐秘的舱室！")


func _crank_winch() -> void:
	_open_door("gate", "锚链轰然绷直——龙骨活门打开了！")
	_open_door("wedge", "夹层坍塌被拖开，返航捷径贯通！")
	shortcut_open = true


func _add_switch(pos: Vector2, cfg: Dictionary) -> void:
	var s := SwitchScene.instantiate()
	s.position = pos
	add_child(s)
	s.setup(cfg)


func _open_door(key: String, notice: String) -> void:
	if not _doors.has(key) or not is_instance_valid(_doors[key]):
		return
	if key == "secret":
		secret_open = true
	var door: StaticBody2D = _doors[key]
	_doors.erase(key)
	Sfx.play("build", -4.0)
	hud.spawn_notice(notice, UICommon.GOLD)
	var tw := create_tween()
	tw.tween_property(door, "modulate:a", 0.0, 0.5)
	tw.tween_callback(door.queue_free)


func _spawn_sharks() -> void:
	for cfg in SHARK_PATROLS:
		var shark := SharkScene.instantiate()
		shark.position = Vector2((cfg[0] + cfg[1]) * 0.5, cfg[2])
		shark.z_index = 4
		add_child(shark)
		shark.setup(cfg[0], cfg[1], cfg[2], player)
		shark.died.connect(_on_shark_died)
		_sharks.append(shark)


func _on_shark_died(pos: Vector2) -> void:
	# 与正式玩法一致：击杀鲨鱼掉落皮革（可拾取）
	var pickup := Area2D.new()
	pickup.position = pos
	pickup.collision_layer = 0
	pickup.collision_mask = 2
	pickup.z_index = 2
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	cs.shape = shape
	pickup.add_child(cs)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-10, 6), Vector2(-12, -4), Vector2(-4, -10), Vector2(8, -8),
		Vector2(12, 2), Vector2(4, 8)])
	visual.color = Color(0.55, 0.38, 0.22)
	pickup.add_child(visual)
	pickup.set_meta("picked", false)
	pickup.body_entered.connect(func(b: Node2D) -> void:
		if b == player and not pickup.get_meta("picked"):
			pickup.set_meta("picked", true)
			GameState.materials["leather"] += 1
			GameState.materials_changed.emit()
			Sfx.play("pickup")
			hud.spawn_notice("获得：皮革", UICommon.CYAN)
			pickup.queue_free())
	add_child(pickup)


## 测试与工具用：当前全部实体矩形（含未开的门）。
func all_solids() -> Array:
	var out: Array = []
	for r in SOLIDS:
		out.append(r)
	for key in DOOR_SPECS:
		if _doors.has(key) and is_instance_valid(_doors[key]):
			var d: Array = DOOR_SPECS[key]
			out.append([d[0], d[1], d[2], d[3], "wreck"])
	return out


# ---------------- 场景搭建 ----------------

func _build_environment() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.16, 0.19, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.5, 0.76, 0.8), Color(0.46, 0.72, 0.77),
		Color(0.09, 0.34, 0.41), Color(0.05, 0.19, 0.25), Color(0.012, 0.035, 0.075)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 256
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.position = Vector2(-140, -200)
	bg.size = Vector2(3840, 1450)
	bg.z_index = -20
	add_child(bg)

	# 越深越暗
	var dark_grad := Gradient.new()
	dark_grad.offsets = PackedFloat32Array([0.0, 1.0])
	dark_grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.42)])
	var dark_tex := GradientTexture2D.new()
	dark_tex.gradient = dark_grad
	dark_tex.width = 64
	dark_tex.height = 64
	dark_tex.fill_from = Vector2(0, 0)
	dark_tex.fill_to = Vector2(0, 1)
	var dark := TextureRect.new()
	dark.texture = dark_tex
	dark.position = Vector2(-140, -200)
	dark.size = Vector2(3840, 1450)
	dark.z_index = -19
	add_child(dark)

	# 浅海光柱
	for shaft in [[150, 90], [400, 70], [700, 100], [1100, 80]]:
		var poly := Polygon2D.new()
		var x: float = shaft[0]
		var w: float = shaft[1]
		poly.polygon = PackedVector2Array([
			Vector2(x + w * 0.3, 0), Vector2(x + w * 0.7, 0),
			Vector2(x + w * 1.4, 420), Vector2(x - w * 0.4, 420)])
		poly.color = Color(1, 1, 0.9, 0.05)
		poly.z_index = -15
		add_child(poly)

	# 船长货舱的金色漏光（从船尾舱落口照下去：高价值区域的视觉暗示）
	var hold_light := Polygon2D.new()
	hold_light.polygon = PackedVector2Array([
		Vector2(2965, 850), Vector2(3065, 850), Vector2(3120, 1030), Vector2(2910, 1030)])
	hold_light.color = Color(0.98, 0.82, 0.35, 0.055)
	hold_light.z_index = 1
	add_child(hold_light)

	# 外部海床植被与气泡、鱼群（氛围）
	var weed_kinds := ["a", "b", "c", "d"]
	for i in [250, 610, 860, 3450, 3650]:
		var pivot := Node2D.new()
		pivot.position = Vector2(i, 1154)
		pivot.z_index = -8
		var spr := Sprite2D.new()
		spr.texture = _tex("seaweed_green_%s" % weed_kinds[i % 4])
		spr.scale = Vector2.ONE * 1.4
		spr.offset = Vector2(0, -26.0)
		pivot.add_child(spr)
		add_child(pivot)
		_seaweeds.append({"pivot": pivot, "phase": i * 0.1, "amp": 0.07})
	for i in 8:
		var bubble := Sprite2D.new()
		bubble.texture = _tex("bubble_%s" % ["a", "b", "c"][i % 3])
		bubble.scale = Vector2.ONE * randf_range(0.12, 0.3)
		bubble.position = Vector2(randf_range(100, 3600), randf_range(100, 900))
		bubble.modulate = Color(1, 1, 1, 0.55)
		bubble.z_index = -6
		add_child(bubble)
		_bubbles.append(bubble)
	for cfg in [[600, 300, 400, 800], [2300, 250, 2050, 2600]]:
		var school := Node2D.new()
		school.position = Vector2(cfg[0], cfg[1])
		school.z_index = -7
		for i in 5:
			var fish := Sprite2D.new()
			fish.texture = _tex("fish_blue" if i % 2 == 0 else "fish_green")
			fish.scale = Vector2.ONE * 0.55
			fish.position = Vector2(randf_range(-40.0, 40.0), randf_range(-18.0, 18.0))
			school.add_child(fish)
		add_child(school)
		_schools.append({"node": school, "min_x": cfg[2], "max_x": cfg[3],
			"dir": 1.0, "speed": randf_range(30.0, 48.0), "phase": randf() * TAU})

	_canvas_mod = CanvasModulate.new()
	_canvas_mod.color = Color.WHITE
	add_child(_canvas_mod)


func _build_terrain() -> void:
	# V0.5 纠偏：碰撞体不再挂任何可见形状，视觉全部由 _build_visual_world() 铺装
	var body := StaticBody2D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	body.collision_mask = 0
	for r in SOLIDS:
		var rect := Rect2(r[0], r[1], r[2], r[3])
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		cs.shape = shape
		cs.position = rect.get_center()
		body.add_child(cs)
	add_child(body)


# ---------------- V0.5 纠偏：分层视觉世界 ----------------
# 层级（后 → 前）：渐变海体(-20/-19) → 视差远景(ParallaxLayer -18/-17) →
# 船体整体剪影(-2) → 结构铺装(z0) → 舱内背板(z0) → 船肋/梁(z1) →
# 门窗机关(z1) → 货件道具(z2) → 粒子(z3) → 玩家(5) → 前景遮挡(6)。
# 碰撞矩形（SOLIDS/DOOR_SPECS）不承载任何可见形状。

func _hash01(a: int, b := 0) -> float:
	return fposmod(sin(float(a * 127 + b * 311)) * 43758.5453, 1.0)


func _build_visual_world() -> void:
	_build_parallax()
	_build_ship_silhouette()
	_clad_all_solids()
	_build_room_dressing()


## 视差远景：远礁影 + Kenney 背景岩与海草（中景）。
func _build_parallax() -> void:
	var pb := ParallaxBackground.new()
	pb.layer = -18
	add_child(pb)

	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.15, 0.1)
	far.motion_mirroring = Vector2(1320, 0)
	pb.add_child(far)
	for i in 3:
		var s := Sprite2D.new()
		s.texture = load(SCN + "far_rock.png")
		s.position = Vector2(i * 440 + 220, 985)
		s.scale = Vector2.ONE * 2.0
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		far.add_child(s)

	var mid := ParallaxLayer.new()
	mid.motion_scale = Vector2(0.45, 0.3)
	mid.motion_mirroring = Vector2(1500, 0)
	pb.add_child(mid)
	var mid_tint := Color(0.5, 0.58, 0.66)
	for cfg in [["background_rock_a", 140, 1010, 1.6], ["background_rock_b", 520, 1030, 1.4],
			["background_seaweed_c", 800, 1020, 1.6], ["background_rock_a", 1080, 1005, 1.5],
			["background_seaweed_g", 1300, 1025, 1.5], ["background_rock_b", 260, 980, 1.2],
			["background_seaweed_e", 640, 990, 1.3]]:
		var ms := Sprite2D.new()
		ms.texture = load(SPR + String(cfg[0]) + ".png")
		ms.position = Vector2(cfg[1], cfg[2])
		ms.scale = Vector2.ONE * float(cfg[3])
		ms.modulate = mid_tint
		ms.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mid.add_child(ms)


## 船体整体剪影：从外部看是一艘破损风帆船的暗色体量（甲板下船身 + 龙骨带 + 外板条纹）。
func _build_ship_silhouette() -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(878, 648), Vector2(905, 800), Vector2(955, 1000), Vector2(985, 1072),
		Vector2(3075, 1072), Vector2(3150, 1030), Vector2(3230, 940),
		Vector2(3302, 820), Vector2(3308, 640), Vector2(3270, 618), Vector2(908, 618)])
	poly.color = Color("181009")
	poly.z_index = -2
	add_child(poly)
	# 外板条纹（舷侧板列的明暗韵律）
	for band in [[640, 0.55, 0.16], [760, 0.5, 0.22], [900, 0.45, 3.2]]:
		var line := Line2D.new()
		var y0: float = band[0]
		var thick: float = band[1]
		line.points = PackedVector2Array([
			Vector2(895, y0 + float(band[2])), Vector2(1500, y0), Vector2(2400, y0 - 6),
			Vector2(3060, y0), Vector2(3290, y0 - 70)])
		line.width = thick * 8.0
		line.default_color = Color("0E0906", 0.5)
		line.z_index = -1
		add_child(line)
	# 龙骨带
	var keel := Line2D.new()
	keel.points = PackedVector2Array([
		Vector2(985, 1072), Vector2(2000, 1078), Vector2(3075, 1072)])
	keel.width = 14.0
	keel.default_color = Color("0C0805")
	keel.z_index = -1
	add_child(keel)


## 全部碰撞矩形铺装（不留任何可见纯色块）。
func _clad_all_solids() -> void:
	for i in SOLIDS.size():
		var r: Array = SOLIDS[i]
		var rect := Rect2(r[0], r[1], r[2], r[3])
		match String(r[4]):
			"sand":
				_clad_sand(rect)
			"rock":
				_clad_rock(rect, i)
			"wreck":
				_clad_wood(rect)
			"crate":
				_clad_crate(rect, i)


func _clad_wood(rect: Rect2) -> void:
	_tile_walls(rect, Color(0.86, 0.82, 0.78), int(rect.position.x) % 5)


## 甲板面与舱底额外铺 deck_plank（可行走面的专用板）。
func _clad_deck_strip(x0: float, x1: float, y: float) -> void:
	var x := x0
	while x < x1:
		_scn_sprite("deck_plank", Vector2(x + 96.0, y + 20.0), 0, 2.0, Color(0.95, 0.9, 0.82))
		x += 192.0


func _clad_sand(rect: Rect2) -> void:
	var row := 0
	var y := rect.position.y
	while y < rect.end.y:
		var dim := 1.0 - 0.09 * row
		var x := rect.position.x
		while x < rect.end.x:
			_scn_sprite("sand_tile", Vector2(x + 96.0, y + 22.0), 0, 2.0,
				Color(dim, dim, minf(1.0, dim + 0.02)))
			x += 192.0
		y += 44.0
		row += 1


func _clad_rock(rect: Rect2, idx: int) -> void:
	# 石缝底色 + 巨石贴图网格覆盖
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([
		rect.position, rect.position + Vector2(rect.size.x, 0),
		rect.end, rect.position + Vector2(0, rect.size.y)])
	fill.color = Color("101B26")
	fill.z_index = 0
	add_child(fill)
	var cy := rect.position.y
	var jy := 0
	while cy < rect.end.y:
		var cx := rect.position.x
		var jx := 0
		while cx < rect.end.x:
			var h1 := _hash01(idx, jx * 31 + jy)
			var h2 := _hash01(idx + 7, jx + jy * 17)
			var name := "rock_b" if h2 < 0.45 else "rock_a"
			var s := _scn_sprite(name,
				Vector2(cx + 74.0 + (h1 - 0.5) * 34.0, cy + 52.0 + (h2 - 0.5) * 22.0),
				0, 2.0 + h1 * 0.7)
			s.flip_h = h1 > 0.5
			cx += 150.0
			jx += 1
		cy += 108.0
		jy += 1


func _clad_crate(rect: Rect2, idx: int) -> void:
	_tile_walls(rect, Color(0.7, 0.62, 0.5), idx)
	var cols := int(rect.size.x / 108.0)
	var rows := int(rect.size.y / 92.0)
	for iy in maxi(1, rows):
		for ix in maxi(1, cols):
			var h := _hash01(idx + 3, ix * 7 + iy)
			var s := _scn_sprite("crate",
				Vector2(rect.position.x + 54.0 + ix * 108.0 + (h - 0.5) * 10.0,
					rect.position.y + 46.0 + iy * 92.0),
				1, 1.9 + h * 0.25, Color(0.98, 0.94, 0.88), (h - 0.5) * 0.2)
			s.flip_h = h > 0.5


## 各舱室主题铺装：背板压暗 + 船肋 + 道具 + 灯光焦点 + 粒子。
func _build_room_dressing() -> void:
	# —— 前货舱：货件堆叠的日用舱 ——
	_tile_walls(Rect2(960, 620, 1140, 410), Color(0.5, 0.53, 0.58), 11)
	for i in 5:
		_scn_sprite("hull_rib", Vector2(1030.0 + i * 200.0, 825), 1, 2.0, Color.WHITE,
			[-0.04, 0.05, -0.03, 0.04, -0.05][i])
	_scn_sprite("barrel", Vector2(1180, 1004), 2)
	_scn_sprite("barrel_open", Vector2(1216, 1008), 2, 2.0, Color(1.0, 0.98, 0.94))
	_scn_sprite("rope_coil", Vector2(2000, 1016), 2)
	_scn_sprite("net", Vector2(1360, 655), 2)
	_scn_sprite("lantern", Vector2(1560, 640), 2)
	add_child(_add_glow(Vector2(1560, 648), 40.0, 22.0, Color(1.0, 0.72, 0.3, 0.14), 1))
	_scn_sprite("porthole", Vector2(1750, 760), 1)
	_scn_sprite("sediment_a", Vector2(1120, 1016), 1)
	_scn_sprite("sediment_b", Vector2(1700, 1019), 1)
	_scn_sprite("sediment_a", Vector2(1960, 1016), 1)
	_scn_sprite("seaweed_hold", Vector2(985, 1004), 2)
	_room_motes(Vector2(1530, 820), Vector2(520, 170), 22, Color(0.72, 0.85, 0.84, 0.35))

	# —— 轮机舱：锅炉与管道的机舱 ——
	_tile_walls(Rect2(2160, 620, 700, 410), Color(0.46, 0.5, 0.56), 23)
	_scn_sprite("boiler", Vector2(2520, 940), 2, 3.2)
	var fire_glow := _add_glow(Vector2(2520, 1000), 34.0, 20.0, Color(1.0, 0.5, 0.16, 0.2), 1)
	add_child(fire_glow)
	_room_glows.append({"node": fire_glow, "speed": 5.2, "phase": 0.0, "base": 0.16, "amp": 0.08})
	_scn_sprite("pipe", Vector2(2712, 720), 2)
	_scn_sprite("pipe", Vector2(2748, 760), 2, 1.5)
	for i in 2:
		_scn_sprite("hull_rib", Vector2(2210.0 + i * 590.0, 825), 1, 2.0, Color.WHITE,
			0.04 if i == 0 else -0.05)
	_scn_sprite("lantern", Vector2(2300, 640), 2)
	add_child(_add_glow(Vector2(2300, 648), 36.0, 20.0, Color(1.0, 0.72, 0.3, 0.13), 1))
	_scn_sprite("sediment_a", Vector2(2350, 1016), 1)
	_scn_sprite("sediment_b", Vector2(2810, 1019), 1)
	_scn_sprite("fishbone", Vector2(2650, 1022), 2)
	_room_motes(Vector2(2500, 850), Vector2(320, 160), 16, Color(0.55, 0.58, 0.62, 0.3))

	# —— 船尾舱：落口与杂物 ——
	_tile_walls(Rect2(2920, 620, 320, 230), Color(0.52, 0.5, 0.54), 31)
	_scn_sprite("door_frame", Vector2(2890, 660), 1, 2.0, Color.WHITE, PI / 2.0)
	_scn_sprite("barrel", Vector2(3180, 824), 2)
	_scn_sprite("crate", Vector2(3120, 830), 2, 1.8)
	_scn_sprite("rope_coil", Vector2(2965, 836), 2)
	_scn_sprite("porthole", Vector2(3000, 700), 1)
	_scn_sprite("sediment_b", Vector2(3080, 839), 1)
	_room_motes(Vector2(3080, 735), Vector2(150, 100), 10, Color(0.78, 0.88, 0.86, 0.32))

	# —— 上层甲板：桅杆 / 横桁 / 栏杆 / 破口围板 ——
	_clad_deck_strip(900.0, 1240.0, 560.0)
	_clad_deck_strip(1400.0, 3050.0, 560.0)
	_clad_deck_strip(3200.0, 3240.0, 560.0)
	for span in [[950.0, 1230.0], [1410.0, 2260.0], [2300.0, 3030.0]]:
		var x: float = span[0]
		while x < span[1]:
			_scn_sprite("railing", Vector2(minf(x + 96.0, span[1] - 96.0), 534), 1)
			x += 192.0
	_scn_sprite("mast", Vector2(2612, 438), 1)
	_scn_sprite("spar", Vector2(2380, 479), 1)
	_scn_sprite("spar", Vector2(1040, 505), 1, 1.2)
	_scn_sprite("hull_bow", Vector2(938, 770), 0, 2.2)
	_scn_sprite("hull_stern", Vector2(3272, 766), 0, 2.2)
	for hx in [1250.0, 1390.0, 3060.0, 3190.0]:
		_scn_sprite("hatch_coaming", Vector2(hx, 528), 1)
	_scn_sprite("hull_rib", Vector2(1800, 500), 1, 1.4, Color(0.8, 0.78, 0.74), 0.5)
	_scn_sprite("seaweed_hold", Vector2(1200, 548), 1, 1.6)
	_scn_sprite("seaweed_hold", Vector2(2800, 548), 1, 1.6, Color(0.9, 0.95, 0.95))

	# —— 瞭望舱（危险路线高价值点） ——
	_scn_sprite("hatch_coaming", Vector2(1610, 428), 1)
	_scn_sprite("hatch_coaming", Vector2(1690, 428), 1)
	_scn_sprite("lantern", Vector2(1640, 430), 2)
	add_child(_add_glow(Vector2(1640, 438), 34.0, 18.0, Color(1.0, 0.78, 0.35, 0.15), 1))

	# —— 龙骨夹层：近黑爬行道 ——
	_tile_walls(Rect2(960, 1070, 2280, 80), Color(0.34, 0.37, 0.42), 41)
	for i in 8:
		_scn_sprite("hull_rib", Vector2(1100.0 + i * 280.0, 1108), 1, 0.62,
			Color(0.8, 0.8, 0.84), (i % 2) * 0.08 - 0.04)
	_scn_sprite("fishbone", Vector2(1400, 1130), 2)
	_scn_sprite("fishbone", Vector2(2400, 1135), 2, 1.4)
	_scn_sprite("rope_hang", Vector2(1800, 1106), 1, 1.8)
	_scn_sprite("sediment_b", Vector2(1300, 1141), 1, 2.0, Color(0.6, 0.62, 0.66))
	_scn_sprite("sediment_b", Vector2(2700, 1141), 1, 2.0, Color(0.6, 0.62, 0.66))

	# —— 密室：金堆与青绿火 ——
	_tile_walls(Rect2(3300, 850, 260, 160), Color(0.42, 0.46, 0.5), 53)
	_scn_sprite("hull_rib", Vector2(3345, 928), 1)
	_scn_sprite("hull_rib", Vector2(3515, 928), 1, 2.0, Color.WHITE, 0.06)
	_scn_sprite("gold_pile", Vector2(3470, 1000), 2)
	_scn_sprite("gold_pile", Vector2(3390, 1004), 2, 1.4)
	_scn_sprite("sediment_a", Vector2(3440, 1016), 1)
	_room_motes(Vector2(3430, 930), Vector2(230, 130), 12, Color(0.5, 0.9, 0.84, 0.3))


func _room_motes(pos: Vector2, extents: Vector2, amount: int, color: Color) -> void:
	var motes := CPUParticles2D.new()
	motes.position = pos
	motes.z_index = 3
	motes.emitting = true
	motes.amount = amount
	motes.lifetime = 6.0
	motes.preprocess = 4.0
	motes.texture = load(SCN + "mote.png")
	motes.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	motes.scale_amount_min = 0.35
	motes.scale_amount_max = 0.8
	motes.color = color
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = extents
	motes.direction = Vector2(0.12, -1)
	motes.spread = 14
	motes.initial_velocity_min = 2.0
	motes.initial_velocity_max = 5.0
	motes.gravity = Vector2(0, -1.2)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(color.r, color.g, color.b, 0.0), color,
		Color(color.r, color.g, color.b, color.a * 0.7), Color(color.r, color.g, color.b, 0.0)])
	motes.color_ramp = ramp
	add_child(motes)


# ---------------- 船长货舱样板房视觉层（V0.5） ----------------
# 只读贴图与光照，不参与碰撞；区域身份由船体结构本身表达（无文字标签）。

func _scn_sprite(name: String, pos: Vector2, z: int, scale := 2.0,
		tint := Color.WHITE, rot := 0.0, flip_v := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(SCN + name + ".png")
	s.position = pos
	s.scale = Vector2(scale, -scale if flip_v else scale)
	s.rotation = rot
	s.z_index = z
	s.modulate = tint
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	return s


## 木板墙平铺（hull_wall_a 为主，规律掺入破损 hull_wall_b）。
func _tile_walls(rect: Rect2, tint: Color, seed := 0) -> void:
	var tw := 192.0
	var th := 32.0
	var ix := 0
	var iy := 0
	var y := rect.position.y
	while y < rect.end.y:
		var x := rect.position.x
		ix = 0
		while x < rect.end.x:
			var damaged := (ix * 7 + iy * 3 + seed) % 6 == 0
			_scn_sprite("hull_wall_b" if damaged else "hull_wall_a",
				Vector2(x + tw / 2.0, y + th / 2.0), 0, 2.0, tint)
			x += tw
			ix += 1
		y += th
		iy += 1


func _build_hold_dressing() -> void:
	# 舱内背板压暗（Dead Cells 前后景分离；结构铺装由 _clad_all_solids 统一处理）
	_tile_walls(Rect2(2918, 893, 324, 139), Color(0.5, 0.53, 0.6), 7)

	# 船肋：间隔竖向结构（沉船内部的骨架韵律）
	for i in 4:
		var x := 2954.0 + i * 80.0
		_scn_sprite("hull_rib", Vector2(x, 960), 1, 2.0, Color.WHITE,
			[-0.05, 0.04, -0.03, 0.05][i])

	# 倚墙断裂横梁（金库背景的纵深感）
	var beam := _scn_sprite("beam_broken", Vector2(3152, 945), 1, 0.85, Color(1.05, 1.0, 0.92))
	beam.rotation = deg_to_rad(108.0)

	# 舷窗（舱内一点"外面还有海"的暗示）
	_scn_sprite("porthole", Vector2(3000, 930), 1)
	_scn_sprite("porthole", Vector2(3148, 930), 1)

	# 地面沉积
	for cfg in [["sediment_b", 2940, 1019], ["sediment_a", 2990, 1016],
			["sediment_b", 3135, 1019], ["sediment_a", 3185, 1014]]:
		_scn_sprite(cfg[0], Vector2(cfg[1], cfg[2]), 1)

	# 家具：航海桌（日志）/ 神龛（密室线索）/ 绞盘（捷径）
	_scn_sprite("desk", Vector2(2940, 998), 2)
	_scn_sprite("shrine", Vector2(3222, 994), 2)
	_scn_sprite("winch", Vector2(3192, 1002), 2)

	# 货件：木桶 / 敞口桶（金光）/ 货箱堆 / 缆绳
	_scn_sprite("barrel", Vector2(2976, 1000), 2)
	_scn_sprite("barrel_open", Vector2(3008, 1002), 2, 2.0, Color(1.0, 0.98, 0.94))
	_scn_sprite("crate", Vector2(3160, 1006), 2)
	_scn_sprite("crate", Vector2(3168, 958), 2, 2.0, Color.WHITE, 0.07)
	_scn_sprite("rope_coil", Vector2(3090, 1016), 2)
	_scn_sprite("rope_hang", Vector2(3100, 933), 2)

	# 悬挂油灯 + 暖光晕（船长舱室的人造光）
	_scn_sprite("lantern", Vector2(3082, 911), 2)
	_lantern_glow = _add_glow(Vector2(3082, 920), 64.0, 36.0,
		Color(1.0, 0.72, 0.3, 0.22), 1)
	add_child(_lantern_glow)
	add_child(_add_glow(Vector2(3082, 915), 26.0, 15.0,
		Color(1.0, 0.82, 0.45, 0.25), 1))

	# 舱内海草：地面两丛 + 倒挂两丛
	_scn_sprite("seaweed_hold", Vector2(2932, 1004), 2)
	_scn_sprite("seaweed_hold", Vector2(3238, 1006), 2)
	_scn_sprite("seaweed_hold", Vector2(2960, 921), 2, 2.0, Color.WHITE, 0.0, true)
	_scn_sprite("seaweed_hold", Vector2(3232, 921), 2, 2.0, Color(0.9, 0.95, 0.95), 0.0, true)

	# 可疑角落：神龛上方倾斜搁架 + 暗门底缝青绿微光 + 金库旁散落金件
	_scn_sprite("shelf", Vector2(3234, 952), 2, 2.0, Color(1.0, 0.97, 0.92), -0.18)
	_secret_glint = _add_glow(Vector2(3247, 978), 16.0, 10.0,
		Color(0.4, 0.95, 0.85, 0.14), 1)
	add_child(_secret_glint)
	for gpos in [Vector2(3110, 1024), Vector2(3148, 1026), Vector2(3122, 1018)]:
		var glint := _add_glow(gpos, 5.0, 4.0, Color(0.98, 0.85, 0.4, 0.5), 1)
		add_child(glint)
		_gold_glints.append(glint)

	# 前景遮挡（透明度压低，不破坏可读性）
	_scn_sprite("seaweed_hold", Vector2(2925, 1006), 6, 2.0, Color(1, 1, 1, 0.8), 0.0, true)
	_scn_sprite("rope_hang", Vector2(3238, 946), 6, 2.0, Color(1, 1, 1, 0.85))

	_build_hold_particles()


func _add_glow(pos: Vector2, rx: float, ry: float, color: Color, z: int) -> Polygon2D:
	var glow := Polygon2D.new()
	glow.polygon = _ellipse_pts(rx, ry, 16)
	glow.position = pos
	glow.color = color
	glow.z_index = z
	return glow


static func _ellipse_pts(rx: float, ry: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _build_hold_particles() -> void:
	# 悬浮微粒：静水中的尘埃感
	var motes := CPUParticles2D.new()
	motes.position = Vector2(3080, 962)
	motes.z_index = 3
	motes.emitting = true
	motes.amount = 36
	motes.lifetime = 6.5
	motes.preprocess = 4.0
	motes.texture = load(SCN + "mote.png")
	motes.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	motes.scale_amount_min = 0.4
	motes.scale_amount_max = 0.9
	motes.color = Color(0.78, 0.9, 0.88, 0.4)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(150, 62)
	motes.direction = Vector2(0.15, -1)
	motes.spread = 12
	motes.initial_velocity_min = 2.0
	motes.initial_velocity_max = 6.0
	motes.gravity = Vector2(0, -1.5)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.78, 0.9, 0.88, 0.0), Color(0.78, 0.9, 0.88, 0.45),
		Color(0.78, 0.9, 0.88, 0.3), Color(0.78, 0.9, 0.88, 0.0)])
	motes.color_ramp = ramp
	add_child(motes)

	# 敞口木桶冒泡
	var bub := CPUParticles2D.new()
	bub.position = Vector2(3008, 988)
	bub.z_index = 3
	bub.emitting = true
	bub.amount = 3
	bub.lifetime = 3.2
	bub.preprocess = 2.0
	bub.texture = _tex("bubble_a")
	bub.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bub.scale_amount_min = 0.08
	bub.scale_amount_max = 0.14
	bub.modulate = Color(1, 1, 1, 0.7)
	bub.direction = Vector2(0, -1)
	bub.spread = 8
	bub.initial_velocity_min = 8.0
	bub.initial_velocity_max = 14.0
	add_child(bub)


## 灰盒导视：入口与房间名（密室除外——秘密靠视觉线索）。
func _build_doors() -> void:
	# 密室暗门：与船壁同板但带青色细缝漏光（不靠文字也能发现的视觉线索）
	_doors["secret"] = _make_door(DOOR_SPECS["secret"], "secret")
	_doors["gate"] = _make_door(DOOR_SPECS["gate"], "gate")
	_doors["wedge"] = _make_door(DOOR_SPECS["wedge"], "wedge")


func _make_door(spec: Array, key: String) -> StaticBody2D:
	var rect := Rect2(spec[0], spec[1], spec[2], spec[3])
	var door := StaticBody2D.new()
	door.collision_layer = 1
	door.collision_mask = 0
	door.z_index = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.position = rect.get_center()
	door.add_child(cs)
	var spr := Sprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = rect.get_center() - door.global_position
	match key:
		"gate":
			# 龙骨活门：金属格栅
			spr.texture = load(SCN + "hatch_grate.png")
			spr.scale = Vector2.ONE * 2.0
		"wedge":
			# 夹层坍塌：木板碎石堆积
			spr.texture = load(SCN + "debris_pile.png")
			spr.scale = Vector2.ONE * 2.0
		"secret":
			# 密室暗门：竖向船壳板伪装
			spr.texture = load(SCN + "hull_wall_a.png")
			spr.scale = Vector2(2.0, 2.6)
			spr.rotation = PI / 2.0
	door.add_child(spr)
	if key == "secret":
		var crack := Line2D.new()
		crack.points = PackedVector2Array([
			Vector2(0.0, -rect.size.y / 2.0 + 14.0),
			Vector2(-3.0, 0.0),
			Vector2(0.0, rect.size.y / 2.0 - 14.0)])
		crack.width = 3.0
		crack.default_color = Color(0.4, 0.95, 0.85, 0.8)
		crack.name = "Crack"
		crack.position = rect.get_center()
		door.add_child(crack)
	add_child(door)
	return door


func _build_extraction() -> void:
	_extract_area = Area2D.new()
	_extract_area.collision_layer = 0
	_extract_area.collision_mask = 2
	_extract_area.position = EXTRACT_RECT.get_center()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = EXTRACT_RECT.size
	cs.shape = shape
	_extract_area.add_child(cs)
	_extract_area.body_entered.connect(_on_extract_entered)
	_extract_area.body_exited.connect(_on_extract_exited)
	add_child(_extract_area)

	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([
		EXTRACT_RECT.position, EXTRACT_RECT.position + Vector2(EXTRACT_RECT.size.x, 0),
		EXTRACT_RECT.position + Vector2(EXTRACT_RECT.size.x + 30, EXTRACT_RECT.size.y + 60),
		EXTRACT_RECT.position + Vector2(-30, EXTRACT_RECT.size.y + 60)])
	beam.color = Color(0.95, 0.78, 0.25, 0.14)
	beam.z_index = -5
	add_child(beam)
	# 撤离浮标：灯标 + 锚链垂到水面下，金光脉冲（代替文字标签）
	_scn_sprite("buoy", EXTRACT_RECT.position + Vector2(50, -20), 2)
	var buoy_glow := _add_glow(EXTRACT_RECT.position + Vector2(50, -36), 22.0, 14.0,
		Color(0.98, 0.85, 0.4, 0.3), 2)
	add_child(buoy_glow)
	_room_glows.append({"node": buoy_glow, "speed": 2.2, "phase": 1.0, "base": 0.22, "amp": 0.14})


func _on_extract_entered(body: Node2D) -> void:
	if body == player:
		in_extraction = true


func _on_extract_exited(body: Node2D) -> void:
	if body == player:
		in_extraction = false


func _tex(name: String) -> Texture2D:
	return load(SPR + name + ".png")


func _process(delta: float) -> void:
	_t += delta
	for weed in _seaweeds:
		weed["pivot"].rotation = sin(_t * 1.4 + weed["phase"]) * weed["amp"]
	for b in _bubbles:
		b.position.y -= randf_range(14.0, 30.0) * delta * 3.0
		if b.position.y < 20.0:
			b.position.y = 900.0
			b.position.x = randf_range(100, 3600)
	for school in _schools:
		var node: Node2D = school["node"]
		node.position.x += school["dir"] * school["speed"] * delta
		node.position.y = node.position.y + sin(_t * 1.1 + school["phase"]) * 6.0 * delta
		if node.position.x > school["max_x"]:
			school["dir"] = -1.0
		elif node.position.x < school["min_x"]:
			school["dir"] = 1.0
		node.scale.x = -school["dir"]

	# 深度变暗：甲板以上明亮、舱内昏暗、龙骨夹层最暗
	if player != null and is_instance_valid(player):
		var y := player.global_position.y
		var target := Color(0.95, 0.97, 1.0)
		if y > 1030.0:
			target = Color(0.58, 0.63, 0.76)
		elif y > 560.0:
			target = Color(0.76, 0.8, 0.88)
		_canvas_mod.color = _canvas_mod.color.lerp(target, minf(1.0, 2.5 * delta))

	# 密室暗门缝隙漏光脉冲
	if _doors.has("secret") and is_instance_valid(_doors["secret"]):
		var crack: Line2D = _doors["secret"].get_node_or_null("Crack")
		if crack != null:
			crack.modulate.a = 0.45 + 0.35 * sin(_t * 2.6)

	# 样板房光效：油灯暖光闪烁 / 暗门微光呼吸 / 散金闪光
	if _lantern_glow != null:
		_lantern_glow.color.a = 0.18 + 0.07 * (0.5 + 0.5 * sin(_t * 7.3)) \
			+ 0.03 * (0.5 + 0.5 * sin(_t * 13.7))
	if _secret_glint != null:
		_secret_glint.color.a = 0.1 + 0.07 * (0.5 + 0.5 * sin(_t * 1.8))
	for i in _gold_glints.size():
		var g: Polygon2D = _gold_glints[i]
		g.color.a = 0.35 + 0.45 * maxf(0.0, sin(_t * 2.2 + i * 2.1))
	# 各舱室灯光焦点脉冲（锅炉炉火 / 浮标灯等）
	for glow in _room_glows:
		var node: Polygon2D = glow["node"]
		node.color.a = float(glow["base"]) + float(glow["amp"]) \
			* (0.5 + 0.5 * sin(_t * float(glow["speed"]) + float(glow["phase"])))

	# 鲨鱼警觉时的紧张低音
	var threat: bool = not ended and any_shark_alerting()
	if threat and not _tension_on:
		_tension_on = true
		Sfx.play_tension()
	elif not threat and _tension_on:
		_tension_on = false
		Sfx.stop_tension()
