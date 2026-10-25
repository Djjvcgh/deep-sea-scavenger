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

const KIND_COLORS := {
	"rock": Color(0.34, 0.42, 0.52), "sand": Color(0.72, 0.64, 0.46),
	"wreck": Color(0.42, 0.29, 0.16), "crate": Color(0.55, 0.4, 0.2),
}

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


func _ready() -> void:
	_snapshot = GameState.serialize()
	GameState.start_dive()
	player = $Player
	time_left = BalanceRes.DIVE_TIME_LIMIT

	_build_environment()
	_build_terrain()
	_build_doors()
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
	hud.spawn_notice("[测试] R 重置 · F1 背包档位 · F2 补满体力 · F3 鲨鱼 · F4 鱼叉", UICommon.DIM)
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
	if event.is_action_pressed("inventory") and not loot_panel.visible and not ended:
		inventory_panel.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and not loot_panel.visible:
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
	var body := StaticBody2D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	body.collision_mask = 0
	for r in SOLIDS:
		var rect := Rect2(r[0], r[1], r[2], r[3])
		var kind: String = r[4]
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		cs.shape = shape
		cs.position = rect.get_center()
		body.add_child(cs)
		body.add_child(_solid_visual(rect, kind))
	add_child(body)
	_build_room_signs()


func _solid_visual(rect: Rect2, kind: String) -> Node2D:
	var node := Node2D.new()
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([
		rect.position, rect.position + Vector2(rect.size.x, 0),
		rect.end, rect.position + Vector2(0, rect.size.y)])
	fill.color = KIND_COLORS[kind]
	node.add_child(fill)
	# 顶边描线：灰盒可读性（地形轮廓清晰）
	var edge := Line2D.new()
	edge.points = PackedVector2Array([
		rect.position, rect.position + Vector2(rect.size.x, 0)])
	edge.width = 3.0
	edge.default_color = KIND_COLORS[kind].lightened(0.35)
	node.add_child(edge)
	if kind == "wreck":
		# 船壳板条纹理
		for x in range(rect.position.x + 22.0, rect.end.x - 8.0, 46.0):
			var seam := Line2D.new()
			seam.points = PackedVector2Array([Vector2(x, rect.position.y + 2.0),
				Vector2(x, rect.end.y - 2.0)])
			seam.width = 2.0
			seam.default_color = KIND_COLORS[kind].darkened(0.3)
			node.add_child(seam)
	return node


## 灰盒导视：入口与房间名（密室除外——秘密靠视觉线索）。
func _build_room_signs() -> void:
	_add_sign("船底破口 · 安全", Vector2(830, 845), UICommon.GOOD)
	_add_sign("上层甲板 · 有鲨鱼", Vector2(700, 500), UICommon.ORANGE)
	_add_sign("甲板破口", Vector2(1258, 528), UICommon.DIM)
	_add_sign("桅杆断口", Vector2(3068, 528), UICommon.DIM)
	_add_sign("前货舱", Vector2(1530, 668), UICommon.DIM)
	_add_sign("轮机舱", Vector2(2510, 668), UICommon.DIM)
	_add_sign("船尾舱", Vector2(3080, 660), UICommon.DIM)
	_add_sign("船长货舱", Vector2(3080, 918), UICommon.GOLD)
	_add_sign("龙骨夹层", Vector2(2050, 1112), UICommon.DIM)
	_add_sign("黑潮号", Vector2(2100, 505), Color(0.72, 0.6, 0.42))


func _add_sign(text: String, pos: Vector2, color: Color) -> void:
	var label := UICommon.label(text, 17, color)
	label.position = pos
	label.z_index = 2
	add_child(label)


func _build_doors() -> void:
	# 密室暗门：与船壁同色但带青色细缝漏光（不靠文字也能发现的视觉线索）
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
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([
		rect.position, rect.position + Vector2(rect.size.x, 0),
		rect.end, rect.position + Vector2(0, rect.size.y)])
	fill.color = Color(0.5, 0.36, 0.2) if key != "wedge" else Color(0.4, 0.48, 0.56)
	door.add_child(fill)
	if key == "secret":
		var crack := Line2D.new()
		crack.points = PackedVector2Array([
			Vector2(rect.get_center().x, rect.position.y + 14.0),
			Vector2(rect.get_center().x - 3.0, rect.get_center().y),
			Vector2(rect.get_center().x, rect.end.y - 14.0)])
		crack.width = 3.0
		crack.default_color = Color(0.4, 0.95, 0.85, 0.8)
		crack.name = "Crack"
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
	_add_sign("撤离点", EXTRACT_RECT.get_center() + Vector2(-30, -55), UICommon.GOLD)


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

	# 鲨鱼警觉时的紧张低音
	var threat: bool = not ended and any_shark_alerting()
	if threat and not _tension_on:
		_tension_on = true
		Sfx.play_tension()
	elif not threat and _tension_on:
		_tension_on = false
		Sfx.stop_tension()
