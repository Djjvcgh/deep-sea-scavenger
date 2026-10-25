extends Node2D
## 海底探索场景：种子抽取区域布局变体、地图搭建（Kenney 素材环境层）、
## 宝物刷新、鲨鱼布置、撤离判定与下潜结算。

const MapDataRes := preload("res://scripts/map_data.gd")
const BalanceRes := preload("res://scripts/balance.gd")
const ItemDBRes := preload("res://scripts/item_db.gd")
const PlayerScript := preload("res://scripts/player.gd")
const WreckGenRes := preload("res://scripts/wreck_gen.gd")
const CaveGenRes := preload("res://scripts/cave_gen.gd")

const ChestScene := preload("res://scenes/treasure_chest.tscn")
const SharkScene := preload("res://scenes/shark.tscn")
const HudScene := preload("res://scenes/ui/hud.tscn")
const InventoryScene := preload("res://scenes/ui/inventory_panel.tscn")
const LootScene := preload("res://scenes/ui/loot_panel.tscn")
const ResultsScene := preload("res://scenes/ui/results_panel.tscn")
const PauseScene := preload("res://scenes/ui/pause_menu.tscn")
const BossScript := preload("res://scripts/boss_leviathan.gd")
const CaptainBossScript := preload("res://scripts/boss_ghost_captain.gd")
const SerpentBossScript := preload("res://scripts/boss_sea_serpent.gd")

const SPR := "res://assets/sprites/kenney_fish/"
const ZONE_GLOWS := {
	"A": Color(0.85, 0.9, 0.85, 0.6),
	"B": Color(0.95, 0.78, 0.25, 0.6),
	"C": Color(0.7, 0.4, 0.85, 0.6),
}
const FISH_COLORS := ["fish_blue", "fish_brown", "fish_green", "fish_grey",
	"fish_orange", "fish_pink", "fish_red"]
const SAND_TOPS := ["a", "b", "c", "d", "e", "f", "g", "h"]
const DIRT_TOPS := ["a", "b", "c", "d", "e", "f", "g", "h"]
const SAND_FILL := ["a", "b", "c", "d"]
const FLORA := ["seaweed_green_a", "seaweed_green_b", "seaweed_green_c",
	"seaweed_green_d", "seaweed_pink_a", "seaweed_pink_b", "seaweed_pink_c",
	"seaweed_pink_d", "seaweed_orange_a", "seaweed_orange_b",
	"seaweed_grass_a", "seaweed_grass_b"]
const BG_FLORA := ["background_seaweed_a", "background_seaweed_b",
	"background_seaweed_c", "background_seaweed_d", "background_seaweed_e",
	"background_seaweed_f", "background_seaweed_g", "background_seaweed_h"]

# 沉船内容器的展示样式（key 对应 ItemDB.WRECK_LOOT 的房间池）
const WRECK_CHEST_STYLE := {
	"merchant": {"name": "货舱宝箱", "glow": Color(0.5, 0.85, 0.85, 0.65)},
	"pirate_cargo": {"name": "海盗货舱宝箱", "glow": Color(0.95, 0.78, 0.25, 0.75)},
	"pirate_captain": {"name": "船长室宝箱", "glow": Color(0.98, 0.6, 0.15, 0.85)},
	"ritual": {"name": "祭祀宝箱", "glow": Color(0.7, 0.4, 0.85, 0.85)},
}

# 洞穴宝箱展示样式与发现提示配色
const CAVE_CHEST_STYLE := {
	"treasure": {"name": "隐藏宝箱", "glow": Color(0.4, 0.95, 0.7, 0.8)},
	"danger": {"name": "深渊宝箱", "glow": Color(0.85, 0.35, 0.6, 0.85)},
}
const CAVE_NOTICE_COLORS := {
	"shelter": Color(0.6, 0.85, 0.75), "treasure": Color(0.4, 0.95, 0.7),
	"danger": Color(0.95, 0.45, 0.6), "hang_shelter": Color(0.6, 0.85, 0.75),
	"hang_treasure": Color(0.4, 0.95, 0.7), "hang_danger": Color(0.95, 0.45, 0.6),
}

var player: CharacterBody2D
var hud: CanvasLayer
var inventory_panel: CanvasLayer
var loot_panel: CanvasLayer
var results_panel: CanvasLayer
var pause_menu: CanvasLayer

var in_extraction := false
var ended := false
var dive_seed := 0
var dive_theme := "abyss"     # 本次海域主题：wreck / cave / abyss，决定出没的 Boss
var time_left := 0.0
var boss: Node2D = null

var _rng := RandomNumberGenerator.new()
var _chosen := {}              # zone -> {"index": int, "variant": Dictionary}
var _wrecks: Array = []        # 本次下潜生成的沉船遗址（WreckGen.generate 结果）
var _wreck_solids := {}        # zone -> 沉船实体矩形（并入地形系统）
var _wreck_seen := {}          # 已提示过发现的沉船下标
var _caves: Array = []         # 本次下潜生成的洞穴（CaveGen.generate 结果）
var _cave_solids := {}         # zone -> 洞穴实体矩形（并入地形系统）
var _cave_seen := {}           # 已提示过发现的洞穴下标
var _extract_area: Area2D
var _seaweeds: Array = []
var _bubbles: Array = []
var _schools: Array = []
var _pickups: Array = []
var _shadow: Polygon2D
var _canvas_mod: CanvasModulate
var _shadow_t := 0.0
var _tension_on := false
var _tex_cache := {}
var _used_rect_cache := {}
var _boss_awaken_left := -1.0
var _idol_warned := false
var _boss_in_trigger := false
var _water_tint := Color.WHITE
var _sand_tint := Color.WHITE
var _rock_tint := Color.WHITE


func _ready() -> void:
	GameState.start_dive()
	player = $Player
	_roll_layout()
	time_left = BalanceRes.DIVE_TIME_LIMIT
	_build_environment()
	_build_terrain()
	_build_extraction()
	_spawn_chests()
	_spawn_wreck_containers()
	_spawn_cave_chests()
	_spawn_containers()
	_spawn_cache()
	_spawn_sharks()

	player.reset_for_dive()
	player.z_index = 5
	player.global_position = MapDataRes.PLAYER_SPAWN
	player.set_camera_limits(-120, -260, 5240, 1100)
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
	pause_menu = PauseScene.instantiate()
	add_child(pause_menu)
	pause_menu.setup(true)

	if not GameState.lost_cache.is_empty():
		var zone := MapDataRes.zone_at(float(GameState.lost_cache["x"]))
		hud.spawn_notice("声呐检测到上次的遗落物（%s）" % MapDataRes.zone_name(zone), UICommon.CYAN)

	hud.spawn_notice("本次海域主题：%s（%s出没）" \
		% [MapDataRes.THEME_NAMES[dive_theme], MapDataRes.THEME_BOSS[dive_theme]], UICommon.CYAN)

	Sfx.play_ambient("ambient_underwater")


func _exit_tree() -> void:
	Sfx.stop_tension()


## 每次下潜的随机种子决定三个区域各用哪套布局变体（"海况"）。
## 环境变量 DEEPSEA_SEED 可固定种子，供自动化测试复现同一张地图。
func _roll_layout() -> void:
	_rng.randomize()
	dive_seed = _rng.randi()
	var env_seed := OS.get_environment("DEEPSEA_SEED")
	if env_seed != "":
		dive_seed = int(env_seed)
	_rng.seed = dive_seed
	# 海域主题：决定本次出没的 Boss，并对生成做轻微偏置
	dive_theme = String(_weighted_roll(MapDataRes.DIVE_THEME_WEIGHTS))
	_chosen = {}
	# 海况色调：每潜微调水色/沙色/岩色，让不同下潜一眼可辨
	_water_tint = Color(_rng.randf_range(0.86, 1.0), _rng.randf_range(0.9, 1.0), _rng.randf_range(0.9, 1.02))
	_sand_tint = Color(_rng.randf_range(0.9, 1.06), _rng.randf_range(0.93, 1.02), _rng.randf_range(0.82, 1.0))
	_rock_tint = Color(_rng.randf_range(0.84, 1.06), _rng.randf_range(0.87, 1.02), _rng.randf_range(0.9, 1.06))
	for zone in ["A", "B", "C"]:
		var variants: Array = MapDataRes.ZONE_VARIANTS[zone]
		var index := _rng.randi_range(0, variants.size() - 1)
		_chosen[zone] = {"index": index, "variant": variants[index]}
	# 沉船主题：B 区变体无沉船锚点时按种子重抽（幽灵船长需要触发点）
	if dive_theme == "wreck":
		for attempt in 6:
			if not _chosen["B"]["variant"].get("wreck_anchors", []).is_empty():
				break
			var idx := _rng.randi_range(0, MapDataRes.ZONE_VARIANTS["B"].size() - 1)
			_chosen["B"] = {"index": idx, "variant": MapDataRes.ZONE_VARIANTS["B"][idx]}
	# 洞穴主题：无悬洞空间的变体按种子重抽（海蛇需要潜伏点）
	if dive_theme == "cave":
		for attempt in 8:
			if not _chosen["C"]["variant"].get("no_hang", false):
				break
			var cidx := _rng.randi_range(0, MapDataRes.ZONE_VARIANTS["C"].size() - 1)
			_chosen["C"] = {"index": cidx, "variant": MapDataRes.ZONE_VARIANTS["C"][cidx]}
	# 沉船遗址：按种子激活变体锚点（0~2 艘，合法性由变体数据校验保证）；
	# 沉船主题保证至少一艘（幽灵船长需要触发点）
	_wrecks = WreckGenRes.generate(_rng, _chosen)
	if dive_theme == "wreck" and _wrecks.is_empty():
		var forced: Dictionary = WreckGenRes.force_one(_rng, _chosen)
		if not forced.is_empty():
			_wrecks.append(forced)
	_wreck_solids = {"A": [], "B": [], "C": []}
	for w in _wrecks:
		for r in w["rects"]:
			_wreck_solids[w["zone"]].append([r.position.x, r.position.y, r.size.x, r.size.y, "wreck"])
	# 洞穴：2~4 处（海床岩洞 / 深渊悬洞），避让沉船与既有地形；
	# 洞穴主题保底 3 处且保证一处危险洞穴（海蛇需要潜伏点）
	var cave_min := 3 if dive_theme == "cave" else 2
	var cave_force := "danger" if dive_theme == "cave" else ""
	_caves = CaveGenRes.generate(_rng, _chosen, _all_wreck_rects(), cave_min, cave_force)
	_cave_solids = {"A": [], "B": [], "C": []}
	for c in _caves:
		for r in c["rects"]:
			# kind "cave"：走完整矩形平铺+碰撞路径（避免落入 rock_blob 小圆石分支，墙必须有实体）
			_cave_solids[c["zone"]].append([r.position.x, r.position.y, r.size.x, r.size.y, "cave"])


func _all_wreck_rects() -> Array:
	var out: Array = []
	for w in _wrecks:
		out.append_array(w["rects"])
	return out


func get_zone_label() -> String:
	if player == null or not is_instance_valid(player):
		return ""
	var zone := MapDataRes.zone_at(player.global_position.x)
	if not _chosen.has(zone):
		return MapDataRes.zone_name(zone)
	return "%s · %s" % [MapDataRes.zone_name(zone), _chosen[zone]["variant"]["name"]]


func _input(event: InputEvent) -> void:
	if ended:
		return
	if loot_panel.visible:
		if event.is_action_pressed("interact"):
			loot_panel.take_all_and_close()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			loot_panel.close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		inventory_panel.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		pause_menu.open()
		get_viewport().set_input_as_handled()


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
	_update_wreck_discovery()
	_update_boss_trigger(delta)


## 进入沉船/洞穴内部时的一次性发现提示。
func _update_wreck_discovery() -> void:
	for wi in _wrecks.size():
		if _wreck_seen.has(wi):
			continue
		var interior: Rect2 = _wrecks[wi]["interior"]
		if interior.has_point(player.global_position):
			_wreck_seen[wi] = true
			var wname: String = MapDataRes.WRECK_TEMPLATES[_wrecks[wi]["kind"]]["name"]
			hud.spawn_notice("发现沉船遗址：%s" % wname, UICommon.GOLD)
			Sfx.play("click", -4.0)
	for ci in _caves.size():
		if _cave_seen.has(ci):
			continue
		var cave_interior: Rect2 = _caves[ci]["interior"]
		if cave_interior.grow(8.0).has_point(player.global_position):
			_cave_seen[ci] = true
			var cname: String = MapDataRes.CAVE_TEMPLATES[_caves[ci]["kind"]]["name"]
			hud.spawn_notice("发现%s" % cname, CAVE_NOTICE_COLORS[_caves[ci]["kind"]])
			Sfx.play("click", -4.0)


## 依据海域主题决定 Boss 出没：
## 深渊主题 → 携带诅咒神像唤醒巨影；沉船主题 → 进入沉船长室显形幽灵船长；
## 洞穴主题 → 靠近深海危险洞穴惊出洞穴海蛇。每次下潜只有一个 Boss。
func _update_boss_trigger(delta: float) -> void:
	if boss != null:
		return
	var in_trigger := false
	match dive_theme:
		"abyss":
			if GameState.has_curse_idol():
				if not _idol_warned:
					_idol_warned = true
					_boss_awaken_left = BalanceRes.BOSS_AWAKEN_DELAY
					hud.spawn_notice("神像的诅咒在深海中回荡……", UICommon.ORANGE)
				else:
					_boss_awaken_left -= delta
					if _boss_awaken_left <= 0.0:
						_spawn_boss(BossScript, Vector2.INF, "深渊巨影苏醒了！")
				in_trigger = true
			else:
				_idol_warned = false
				_boss_awaken_left = -1.0
		"wreck":
			for w in _wrecks:
				var room: Rect2 = w.get("captain_room", w["interior"])
				if room.has_point(player.global_position):
					in_trigger = true
					if not _boss_in_trigger:
						_boss_in_trigger = true
						_spawn_boss(CaptainBossScript, room.get_center(),
							"幽灵船长在沉船深处显形了！")
					break
		"cave":
			for c in _caves:
				if c["kind"] in ["danger", "hang_danger"] \
						and (c["interior"] as Rect2).grow(12.0).has_point(player.global_position):
					in_trigger = true
					if not _boss_in_trigger:
						_boss_in_trigger = true
						_spawn_boss(SerpentBossScript, (c["interior"] as Rect2).get_center(),
							"洞穴海蛇从黑暗中突袭！")
					break
	if not in_trigger:
		_boss_in_trigger = false


func _spawn_boss(script: GDScript, pos: Vector2, notice: String) -> void:
	boss = script.new()
	boss.setup(player)          # 先注入玩家引用（_ready 中会用到）
	if pos != Vector2.INF:
		boss.position = pos     # 固定出生点（船长室/洞穴巢穴中心，非墙体）
	add_child(boss)
	boss.defeated.connect(_on_boss_defeated)
	boss.submerged.connect(_on_boss_submerged)
	hud.spawn_notice(notice, UICommon.DANGER)


func _on_boss_submerged() -> void:
	_boss_awaken_left = -1.0
	_idol_warned = false
	_boss_in_trigger = false
	boss = null


func _on_boss_defeated(pos: Vector2) -> void:
	var loot: Array = boss.loot_items
	var bname := String(boss.boss_name)
	hud.spawn_notice("%s被击败了……战利品浮了上来" % bname, UICommon.GOLD)
	# Boss 战利品袋：用开箱拾取界面取回
	var trophy := ChestScene.instantiate()
	trophy.position = pos + Vector2(0, -40)
	add_child(trophy)
	trophy.setup_container({
		"kind": "trophy", "name": "%s战利品" % bname, "search_time": 1.5,
		"loot": func() -> Array: return loot.duplicate(true),
		"glow": Color(0.95, 0.78, 0.25, 0.8),
	})


func _on_shark_died(pos: Vector2) -> void:
	_spawn_leather_pickup(pos)


func _spawn_leather_pickup(pos: Vector2) -> void:
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
	_pickups.append(pickup)


func any_boss_active() -> bool:
	return boss != null and is_instance_valid(boss) and boss.is_threatening()


func _on_loot_collected(entries: Array, container: Area2D) -> void:
	if entries.is_empty():
		player.control_locked = false
		return
	loot_panel.open(entries, container)


func any_shark_alerting() -> bool:
	for s in get_tree().get_nodes_in_group("sharks"):
		if s.is_threatening():
			return true
	return false


## 撤离成功或失败后结算。成功把临时宝物转入岛上库存；失败掉落在原地（可找回）。
func _end_dive(success: bool, fail_reason := "") -> void:
	if ended:
		return
	ended = true
	var items: Array = GameState.dive_bag.duplicate(true)
	var total := GameState.dive_total_value()
	var elapsed := (Time.get_ticks_msec() - GameState.dive_start_msec) / 1000.0
	var drop_pos: Vector2 = player.global_position if player != null else Vector2.INF
	GameState.end_dive(success, drop_pos)
	SaveManager.save_game(GameState.serialize())
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


# ---------------- 刷新 ----------------

## 从当前变体的宝箱点中按种子随机激活一部分。
func _spawn_chests() -> void:
	for zone in ["A", "B", "C"]:
		var spots: Array = (_chosen[zone]["variant"]["chests"] as Array).duplicate()
		_shuffled(spots)
		var count: int = mini(BalanceRes.ACTIVE_PER_DIVE[zone], spots.size())
		for i in count:
			var chest := ChestScene.instantiate()
			chest.position = spots[i]
			add_child(chest)
			chest.setup_container({
				"kind": "chest",
				"name": String(ItemDBRes.CONTAINERS["chest"]["name"]),
				"search_time": float(ItemDBRes.CONTAINERS["chest"]["search_time"]),
				"loot": _make_chest_provider(zone),
				"glow": ZONE_GLOWS[zone],
			})


## 沉船遗址：舱体阴影 + 舱内可搜索容器（掉落来自 WRECK_LOOT 房间池）。
func _spawn_wreck_containers() -> void:
	for wi in _wrecks.size():
		var wreck: Dictionary = _wrecks[wi]
		var interior: Rect2 = wreck["interior"]
		var shadow := Polygon2D.new()
		shadow.polygon = PackedVector2Array([
			interior.position, interior.position + Vector2(interior.size.x, 0),
			interior.end, interior.position + Vector2(0, interior.size.y)])
		shadow.color = Color(0.01, 0.03, 0.06, 0.4)
		shadow.z_index = 1
		add_child(shadow)
		for si in wreck["spots"].size():
			var pool_key := _wreck_pool_key(wreck["kind"], si)
			var style: Dictionary = WRECK_CHEST_STYLE[pool_key]
			var c := ChestScene.instantiate()
			c.position = wreck["spots"][si]
			add_child(c)
			c.setup_container({
				"kind": "chest",
				"name": String(style["name"]),
				"search_time": float(ItemDBRes.CONTAINERS["chest"]["search_time"]),
				"loot": _make_wreck_provider(pool_key, wreck["anchor"]),
				"glow": style["glow"],
			})


## 房间池 key：海盗船 0 号点=货舱、1 号点=船长室；其余类型单池。
func _wreck_pool_key(kind: String, spot_index: int) -> String:
	if kind == "pirate":
		return "pirate_cargo" if spot_index == 0 else "pirate_captain"
	return kind


func _make_wreck_provider(pool_key: String, anchor: Vector2) -> Callable:
	return func() -> Array: return _roll_wreck_loot(pool_key, anchor)


func _roll_wreck_loot(pool_key: String, anchor: Vector2) -> Array:
	var cfg: Dictionary = ItemDBRes.WRECK_LOOT[pool_key]
	var out: Array = []
	var count := int(_weighted_roll(cfg["count"]))
	for i in count:
		out.append({
			"id": String(_weighted_roll(cfg["pool"])),
			"quality": String(_weighted_roll(ItemDBRes.WRECK_QUALITY_WEIGHTS[cfg["quality"]])),
		})
	if cfg.has("bonus_pool"):
		out.append({"id": String(_weighted_roll(cfg["bonus_pool"])),
			"quality": String(_weighted_roll(ItemDBRes.WRECK_QUALITY_WEIGHTS[cfg["quality"]]))})
	if pool_key == "ritual":
		_disturb_sharks(anchor)
	return out


## 祭祀宝物被扰动：附近鲨群立刻警觉游向玩家（沉船的危险事件）。
func _disturb_sharks(from_pos: Vector2) -> void:
	if hud == null:
		return
	hud.spawn_notice("祭祀船的诅咒惊动了附近的鲨群！", UICommon.ORANGE)
	for s in get_tree().get_nodes_in_group("sharks"):
		if s.global_position.distance_to(from_pos) < 620.0:
			s.disturb()


## 洞穴宝箱：隐藏洞穴 / 深海危险洞穴各有洞内宝箱（藏身岩洞无）。
func _spawn_cave_chests() -> void:
	for cave in _caves:
		if cave["spots"].is_empty():
			continue
		var pool_key := "treasure" if cave["kind"] in ["treasure", "hang_treasure"] else "danger"
		var style: Dictionary = CAVE_CHEST_STYLE[pool_key]
		var c := ChestScene.instantiate()
		c.position = cave["spots"][0]
		add_child(c)
		c.setup_container({
			"kind": "chest",
			"name": String(style["name"]),
			"search_time": float(ItemDBRes.CONTAINERS["chest"]["search_time"]),
			"loot": func() -> Array: return _roll_cave_loot(pool_key),
			"glow": style["glow"],
		})


func _roll_cave_loot(pool_key: String) -> Array:
	var cfg: Dictionary = ItemDBRes.CAVE_LOOT[pool_key]
	var out: Array = []
	var count := int(_weighted_roll(cfg["count"]))
	for i in count:
		out.append({
			"id": String(_weighted_roll(cfg["pool"])),
			"quality": String(_weighted_roll(ItemDBRes.WRECK_QUALITY_WEIGHTS[cfg["quality"]])),
		})
	return out


## 小型容器（海贝/垃圾袋）：按种子沿海床散布，避开实体与宝箱点。
func _spawn_containers() -> void:
	var solids := _all_solids()
	var floor_y := {"A": 800.0, "B": 950.0, "C": 950.0}
	var x_range := {"A": [110.0, 1640.0], "B": [1760.0, 3340.0], "C": [3530.0, 5070.0]}
	for zone in ["A", "B", "C"]:
		var placed := 0
		var tries := 0
		while placed < int(BalanceRes.CONTAINER_COUNTS[zone]) and tries < 80:
			tries += 1
			var x := _rng.randf_range(x_range[zone][0], x_range[zone][1])
			var y: float = floor_y[zone] - 16.0
			# 避障检查点抬高到离地 30px：贴地 16px 会被海床自身的间隙检查否决
			if not MapDataRes.circle_clear(Vector2(x, y - 14.0), 26.0, solids):
				continue
			# 与宝箱点保持距离，避免视觉堆叠
			var near_chest := false
			for cs in _chosen[zone]["variant"]["chests"]:
				if Vector2(cs.x, cs.y).distance_to(Vector2(x, y)) < 60.0:
					near_chest = true
					break
			if near_chest:
				continue
			var kind := "shell" if _rng.randf() < 0.5 else "trash_bag"
			var c := ChestScene.instantiate()
			c.position = Vector2(x, y)
			add_child(c)
			c.setup_container({
				"kind": kind,
				"name": String(ItemDBRes.CONTAINERS[kind]["name"]),
				"search_time": float(ItemDBRes.CONTAINERS[kind]["search_time"]),
				"loot": _make_container_provider(kind),
				"glow": Color(0.8, 0.85, 0.8, 0.45) if kind == "shell"
					else Color(0.45, 0.55, 0.5, 0.4),
			})
			placed += 1


## 上次失败的遗落物袋：内容来自 GameState.lost_cache。
func _spawn_cache() -> void:
	var cache: Dictionary = GameState.lost_cache
	if cache.is_empty() or not cache.has("items") or (cache["items"] as Array).is_empty():
		return
	var c := ChestScene.instantiate()
	c.position = Vector2(float(cache["x"]), float(cache["y"]))
	add_child(c)
	c.setup_container({
		"kind": "cache", "name": "遗落物袋", "search_time": 2.0,
		"loot": _take_cache_loot, "glow": Color(0.5, 0.9, 0.95, 0.7),
	})


func _make_chest_provider(zone: String) -> Callable:
	return func() -> Array: return _roll_chest_loot(zone)


func _make_container_provider(kind: String) -> Callable:
	return func() -> Array: return _roll_container_loot(kind)


## 宝箱掉落：件数与品质均按区域权重。
func _roll_chest_loot(zone: String) -> Array:
	var out: Array = []
	var count := int(_weighted_roll(ItemDBRes.CHEST_COUNT_WEIGHTS[zone]))
	for i in count:
		out.append({
			"id": String(_weighted_roll(ItemDBRes.ZONE_WEIGHTS[zone])),
			"quality": String(_weighted_roll(ItemDBRes.CHEST_QUALITY_WEIGHTS[zone])),
		})
	return out


## 小型容器掉落：单件，低价值池，可掉材料（@前缀）。
func _roll_container_loot(kind: String) -> Array:
	var pick = _weighted_roll(ItemDBRes.CONTAINERS[kind]["loot_pool"])
	if pick is String and pick.begins_with("@"):
		return [{"mat": pick.substr(1)}]
	return [{"id": String(pick), "quality": String(_weighted_roll(ItemDBRes.CONTAINER_QUALITY_WEIGHTS))}]


## 遗落物袋：一次性取出全部缓存内容。
func _take_cache_loot() -> Array:
	var items: Array = GameState.lost_cache.get("items", [])
	GameState.lost_cache = {}
	SaveManager.save_game(GameState.serialize())
	return items.duplicate(true)


func _weighted_roll(weights: Dictionary) -> Variant:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := _rng.randf() * total
	var acc := 0.0
	for k in weights:
		acc += float(weights[k])
		if r <= acc:
			return k
	return weights.keys().back()


func _shuffled(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _spawn_sharks() -> void:
	for cfg in _chosen_zone_solids_patrols():
		var shark := SharkScene.instantiate()
		shark.position = Vector2((cfg[0] + cfg[1]) * 0.5, cfg[2])
		shark.z_index = 4
		add_child(shark)
		shark.setup(cfg[0], cfg[1], cfg[2], player)
		shark.died.connect(_on_shark_died)


func _chosen_zone_solids_patrols() -> Array:
	var out: Array = []
	for zone in ["B", "C"]:
		out.append_array(_chosen[zone]["variant"]["patrols"])
	return out


func _solids_for(zone: String) -> Array:
	return MapDataRes.variant_solids(zone, _chosen[zone]["index"]) \
		+ _wreck_solids.get(zone, []) + _cave_solids.get(zone, [])


func _all_solids() -> Array:
	var out: Array = []
	for zone in ["A", "B", "C"]:
		out.append_array(_solids_for(zone))
	return out


func _tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load(SPR + name + ".png")
	return _tex_cache[name]


# ---------------- 场景搭建 ----------------

func _build_environment() -> void:
	# 海水渐变：上为天空/水面，向下变深
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.16, 0.19, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.56, 0.82, 0.86), Color(0.5, 0.77, 0.81),
		Color(0.1, 0.37, 0.43), Color(0.05, 0.2, 0.26), Color(0.015, 0.04, 0.08)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 256
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.position = Vector2(-120, -260)
	bg.size = Vector2(5240, 1460)
	bg.z_index = -20
	bg.modulate = _water_tint
	add_child(bg)

	# 越往右越暗（区域加深）
	var dark_grad := Gradient.new()
	dark_grad.offsets = PackedFloat32Array([0.0, 1.0])
	dark_grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.45)])
	var dark_tex := GradientTexture2D.new()
	dark_tex.gradient = dark_grad
	dark_tex.width = 64
	dark_tex.height = 64
	dark_tex.fill_from = Vector2(0, 0)
	dark_tex.fill_to = Vector2(1, 0)
	var dark := TextureRect.new()
	dark.texture = dark_tex
	dark.position = Vector2(0, 0)
	dark.size = Vector2(5120, 1100)
	dark.z_index = -19
	add_child(dark)

	# 浅海光柱（锥形，弱化边界感）
	for shaft in MapDataRes.LIGHT_SHAFTS:
		var poly := Polygon2D.new()
		var x: float = shaft[0]
		var w: float = shaft[1]
		poly.polygon = PackedVector2Array([
			Vector2(x + w * 0.3, 0), Vector2(x + w * 0.7, 0),
			Vector2(x + w * 1.4, 420), Vector2(x - w * 0.4, 420)])
		poly.color = Color(1, 1, 0.9, 0.045)
		poly.z_index = -15
		add_child(poly)

	_build_decor()
	_build_fish_schools()

	# 气泡（素材）
	for i in 12:
		var bubble := Sprite2D.new()
		bubble.texture = _tex("bubble_%s" % ["a", "b", "c"][_rng.randi_range(0, 2)])
		bubble.scale = Vector2.ONE * _rng.randf_range(0.12, 0.3)
		bubble.position = Vector2(_rng.randf_range(100, 5000), _rng.randf_range(100, 900))
		bubble.modulate = Color(1, 1, 1, 0.55)
		bubble.z_index = -6
		add_child(bubble)
		_bubbles.append(bubble)

	# 深层洞穴远处的巨大阴影（克苏鲁氛围暗示）
	_shadow = Polygon2D.new()
	_shadow.polygon = _ellipse(260.0, 150.0, 20)
	_shadow.position = Vector2(4650, 160)
	_shadow.color = Color(0, 0, 0, 0.1)
	_shadow.z_index = -14
	add_child(_shadow)

	# 沉船背景剪影
	var silhouette := Polygon2D.new()
	silhouette.polygon = PackedVector2Array([
		Vector2(2050, 700), Vector2(2520, 640), Vector2(2950, 690),
		Vector2(2950, 950), Vector2(2050, 950)])
	silhouette.color = Color(0.05, 0.07, 0.1, 0.55)
	silhouette.z_index = -10
	add_child(silhouette)

	# 深度黑暗调制：区域C明显变暗，配合玩家潜水灯（能见度即风险）
	_canvas_mod = CanvasModulate.new()
	_canvas_mod.color = Color.WHITE
	add_child(_canvas_mod)


## 按种子在海底散布植被与背景层（避开实体地形）。
func _build_decor() -> void:
	var solids := _all_solids()
	var floor_y := {"A": 800.0, "B": 950.0, "C": 950.0}
	var x_range := {"A": [80.0, 1650.0], "B": [1750.0, 3350.0], "C": [3520.0, 5080.0]}
	var counts := {"A": 9, "B": 7, "C": 5}

	for zone in ["A", "B", "C"]:
		var placed := 0
		var tries := 0
		while placed < counts[zone] and tries < 60:
			tries += 1
			var x := _rng.randf_range(x_range[zone][0], x_range[zone][1])
			var y: float = floor_y[zone]
			if not MapDataRes.circle_clear(Vector2(x, y - 26.0), 24.0, solids):
				continue
			placed += 1
			var is_coral: bool = _rng.randf() < 0.3
			var flora_name: String = FLORA[_rng.randi_range(0, FLORA.size() - 1)]
			var s := _rng.randf_range(0.9, 1.6)
			var pivot := Node2D.new()
			pivot.position = Vector2(x, y + 4.0)
			pivot.z_index = -8
			var spr := Sprite2D.new()
			spr.texture = _tex(flora_name)
			spr.scale = Vector2.ONE * s
			spr.offset = Vector2(0, -26.0)
			pivot.add_child(spr)
			add_child(pivot)
			if is_coral:
				spr.modulate = Color(1.0, 0.85, 0.9)
			else:
				_seaweeds.append({"pivot": pivot, "phase": _rng.randf() * TAU,
					"amp": _rng.randf_range(0.05, 0.1)})

		# 背景层植物与岩石（更暗、更大、无碰撞）
		for i in 4:
			var x := _rng.randf_range(x_range[zone][0], x_range[zone][1])
			var y: float = floor_y[zone]
			var spr := Sprite2D.new()
			spr.texture = _tex(BG_FLORA[_rng.randi_range(0, BG_FLORA.size() - 1)])
			spr.scale = Vector2.ONE * _rng.randf_range(1.4, 2.2)
			spr.position = Vector2(x, y - 30.0)
			spr.modulate = Color(0.55, 0.66, 0.78, 0.8)
			spr.z_index = -12
			add_child(spr)
		for i in 2:
			var x := _rng.randf_range(x_range[zone][0], x_range[zone][1])
			var y: float = floor_y[zone]
			var spr := Sprite2D.new()
			spr.texture = _tex("background_rock_%s" % ["a", "b"][_rng.randi_range(0, 1)])
			spr.scale = Vector2.ONE * _rng.randf_range(1.2, 2.0)
			spr.position = Vector2(x, y - 26.0)
			spr.modulate = Color(0.5, 0.6, 0.72, 0.85)
			spr.z_index = -12
			add_child(spr)


## 环境鱼群：纯氛围，无碰撞，按种子生成。
func _build_fish_schools() -> void:
	var solids := _all_solids()
	var ranges := [[300.0, 1600.0], [1800.0, 3300.0], [1800.0, 3300.0],
		[3550.0, 5000.0], [3550.0, 5000.0]]
	for r in ranges:
		var center := Vector2.ZERO
		var ok := false
		for attempt in 8:
			center = Vector2(_rng.randf_range(r[0], r[1]), _rng.randf_range(220.0, 760.0))
			if MapDataRes.circle_clear(center, 90.0, solids):
				ok = true
				break
		if not ok:
			continue
		var school := Node2D.new()
		school.position = center
		school.z_index = -7
		var color: String = FISH_COLORS[_rng.randi_range(0, FISH_COLORS.size() - 1)]
		for i in _rng.randi_range(4, 6):
			var fish := Sprite2D.new()
			fish.texture = _tex(color)
			fish.scale = Vector2.ONE * _rng.randf_range(0.45, 0.7)
			fish.position = Vector2(_rng.randf_range(-46.0, 46.0), _rng.randf_range(-20.0, 20.0))
			fish.modulate = Color(1, 1, 1, 0.9)
			school.add_child(fish)
		add_child(school)
		_schools.append({"node": school,
			"min_x": r[0], "max_x": r[1],
			"dir": 1.0 if _rng.randf() < 0.5 else -1.0,
			"speed": _rng.randf_range(28.0, 55.0),
			"phase": _rng.randf() * TAU})


func _terrain_tiles(rect: Rect2, fill_name: String, top_name: String, mod: Color) -> void:
	var body := Node2D.new()
	body.z_index = 0
	if rect.size.y <= 64.0:
		body.add_child(_tiled(top_name, Rect2(rect.position, rect.size), mod))
	else:
		body.add_child(_tiled(top_name, Rect2(rect.position, Vector2(rect.size.x, 64.0)), mod))
		body.add_child(_tiled(fill_name,
			Rect2(rect.position + Vector2(0, 64.0), rect.size - Vector2(0, 64.0)), mod))
	add_child(body)


func _tiled(tex_name: String, rect: Rect2, mod: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(tex_name)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, rect.size)
	s.centered = false
	s.position = rect.position
	s.modulate = mod
	return s


func _used_rect(tex: Texture2D) -> Rect2:
	## 素材在 64x64 画布中的实际不透明区域（blob），用于贴图对齐与碰撞成形
	var key := tex.resource_path
	if not _used_rect_cache.has(key):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		_used_rect_cache[key] = Rect2(img.get_used_rect())
	return _used_rect_cache[key]


## 小块岩石：blob 底部对齐矩形，碰撞用内切六边形贴合石头外形（不再有空气墙）。
func _add_rock_blob(body: StaticBody2D, rect: Rect2) -> void:
	var tex: Texture2D = _tex("rock_%s" % ["a", "b"][_rng.randi_range(0, 1)])
	var blob := _used_rect(tex)
	var s := rect.size.x / blob.size.x
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2.ONE * s
	spr.flip_h = _rng.randf() < 0.5
	var blob_center_offset := blob.get_center() - Vector2(32, 32)   # 相对贴图中心
	var target := Vector2(rect.get_center().x, rect.end.y - blob.size.y * s * 0.5)
	spr.position = target - blob_center_offset * s
	spr.modulate = Color(0.62, 0.68, 0.78)
	spr.z_index = 0
	body.add_child(spr)

	var w := blob.size.x * s * 0.92
	var h := blob.size.y * s * 0.9
	var cx := rect.get_center().x
	var cy := rect.end.y - h * 0.5
	var hull := ConvexPolygonShape2D.new()
	hull.points = PackedVector2Array([
		Vector2(cx - w * 0.26, cy - h * 0.5), Vector2(cx + w * 0.26, cy - h * 0.5),
		Vector2(cx + w * 0.5, cy - h * 0.08), Vector2(cx + w * 0.44, cy + h * 0.5),
		Vector2(cx - w * 0.44, cy + h * 0.5), Vector2(cx - w * 0.5, cy - h * 0.08)])
	var cs := CollisionShape2D.new()
	cs.shape = hull
	body.add_child(cs)


## 沙地逐格铺装：随机顶盖与填充变体 + 明度抖动，打破平铺图案感。
func _sand_grid(body: StaticBody2D, rect: Rect2, mod: Color) -> void:
	var cols := int(ceil(rect.size.x / 64.0))
	var rows := int(ceil(rect.size.y / 64.0))
	for cy in rows:
		for cx in cols:
			var pos := rect.position + Vector2(cx * 64.0, cy * 64.0)
			var size := Vector2(
				minf(64.0, rect.end.x - pos.x),
				minf(64.0, rect.end.y - pos.y))
			var tex_name: String
			if cy == 0:
				tex_name = "terrain_sand_top_%s" % SAND_TOPS[_rng.randi_range(0, 7)]
			else:
				tex_name = "terrain_sand_%s" % SAND_FILL[_rng.randi_range(0, 3)]
			var spr := Sprite2D.new()
			spr.texture = _tex(tex_name)
			spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			spr.region_enabled = true
			spr.region_rect = Rect2(Vector2.ZERO, size)
			spr.centered = false
			spr.position = pos
			var b := _rng.randf_range(0.92, 1.0)
			spr.modulate = Color(mod.r * b, mod.g * b, mod.b * b)
			body.add_child(spr)


func _build_terrain() -> void:
	var body := StaticBody2D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	body.collision_mask = 0
	for zone in ["A", "B", "C"]:
		for r in _solids_for(zone):
			var rect := Rect2(r[0], r[1], r[2], r[3])
			var kind: String = r[4]
			if kind == "rock" and rect.size.x <= 150.0 and rect.size.y <= 150.0:
				_add_rock_blob(body, rect)
				continue

			var cs := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = rect.size
			cs.shape = shape
			cs.position = rect.get_center()
			body.add_child(cs)

			var edge := Color(0.2, 0.28, 0.33)
			if kind == "sand":
				edge = Color(0.5, 0.45, 0.3) * _sand_tint
				_sand_grid(body, rect, _sand_tint)
			elif kind == "wreck":
				edge = Color(0.38, 0.27, 0.15)
				_terrain_tiles(rect, "terrain_dirt_%s" % SAND_FILL[_rng.randi_range(0, 3)],
					"terrain_dirt_top_%s" % DIRT_TOPS[_rng.randi_range(0, 7)],
					Color(0.78, 0.6, 0.45) * _rock_tint)
			else:
				edge = Color(0.24, 0.3, 0.38)
				_terrain_tiles(rect, "terrain_dirt_%s" % SAND_FILL[_rng.randi_range(0, 3)],
					"terrain_dirt_top_%s" % DIRT_TOPS[_rng.randi_range(0, 7)],
					Color(0.52, 0.58, 0.68) * _rock_tint)

			var top_line := Line2D.new()
			top_line.points = PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0)])
			top_line.width = 3.0
			top_line.default_color = edge
			body.add_child(top_line)
	add_child(body)


func _build_extraction() -> void:
	var rect := MapDataRes.EXTRACT_RECT
	_extract_area = Area2D.new()
	_extract_area.collision_layer = 0
	_extract_area.collision_mask = 2
	_extract_area.position = rect.get_center()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	_extract_area.add_child(cs)
	_extract_area.body_entered.connect(_on_extract_entered)
	_extract_area.body_exited.connect(_on_extract_exited)
	add_child(_extract_area)

	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([
		rect.position, rect.position + Vector2(rect.size.x, 0),
		rect.position + Vector2(rect.size.x + 30, rect.size.y + 60),
		rect.position + Vector2(-30, rect.size.y + 60)])
	beam.color = Color(0.95, 0.78, 0.25, 0.14)
	beam.z_index = -5
	add_child(beam)

	var label := UICommon.label("撤离点", 22, UICommon.GOLD)
	label.position = rect.get_center() + Vector2(-30, -60)
	label.z_index = -4
	add_child(label)


func _on_extract_entered(body: Node2D) -> void:
	if body == player:
		in_extraction = true


func _on_extract_exited(body: Node2D) -> void:
	if body == player:
		in_extraction = false


static func _ellipse(rx: float, ry: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _process(delta: float) -> void:
	_shadow_t += delta
	_shadow.position.x = 4650.0 + sin(_shadow_t * 0.12) * 90.0
	_shadow.position.y = 160.0 + sin(_shadow_t * 0.21) * 24.0
	for weed in _seaweeds:
		weed["pivot"].rotation = sin(_shadow_t * 1.4 + weed["phase"]) * weed["amp"]
	for b in _bubbles:
		b.position.y -= randf_range(14.0, 30.0) * delta * 3.0
		if b.position.y < 20.0:
			b.position.y = 900.0
			b.position.x = randf_range(100, 5000)
	for p in _pickups:
		if is_instance_valid(p) and p.get_child_count() > 1:
			p.get_child(1).position.y = sin(_shadow_t * 3.0 + p.position.x * 0.1) * 3.0
	for school in _schools:
		var node: Node2D = school["node"]
		node.position.x += school["dir"] * school["speed"] * delta
		node.position.y += sin(_shadow_t * 1.1 + school["phase"]) * 6.0 * delta
		if node.position.x > school["max_x"]:
			school["dir"] = -1.0
		elif node.position.x < school["min_x"]:
			school["dir"] = 1.0
		node.scale.x = -school["dir"]   # 素材鱼头朝左：向左游 scale=1

	# 深度黑暗：按区域平滑过渡
	if player != null and is_instance_valid(player):
		var target := Color.WHITE
		match MapDataRes.zone_at(player.global_position.x):
			"B":
				target = Color(0.78, 0.84, 0.93)
			"C":
				target = Color(0.5, 0.57, 0.7)
		_canvas_mod.color = _canvas_mod.color.lerp(target, minf(1.0, 2.5 * delta))

	# 鲨鱼追逐或巨影活跃时的紧张低音
	var threat: bool = (not ended and any_shark_alerting()) or any_boss_active()
	if threat and not _tension_on:
		_tension_on = true
		Sfx.play_tension()
	elif not threat and _tension_on:
		_tension_on = false
		Sfx.stop_tension()
