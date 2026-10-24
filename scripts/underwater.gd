extends Node2D
## 海底探索场景：地图搭建、宝物刷新、鲨鱼布置、撤离判定与下潜结算。

const MapDataRes := preload("res://scripts/map_data.gd")
const BalanceRes := preload("res://scripts/balance.gd")
const ItemDBRes := preload("res://scripts/item_db.gd")
const PlayerScript := preload("res://scripts/player.gd")

const ChestScene := preload("res://scenes/treasure_chest.tscn")
const SharkScene := preload("res://scenes/shark.tscn")
const HudScene := preload("res://scenes/ui/hud.tscn")
const InventoryScene := preload("res://scenes/ui/inventory_panel.tscn")
const ResultsScene := preload("res://scenes/ui/results_panel.tscn")
const PauseScene := preload("res://scenes/ui/pause_menu.tscn")

var player: CharacterBody2D
var hud: CanvasLayer
var inventory_panel: CanvasLayer
var results_panel: CanvasLayer
var pause_menu: CanvasLayer

var in_extraction := false
var ended := false

var _extract_area: Area2D
var _seaweeds: Array = []
var _bubbles: Array = []
var _shadow: Polygon2D
var _shadow_t := 0.0


func _ready() -> void:
	GameState.start_dive()
	player = $Player
	_build_environment()
	_build_terrain()
	_build_extraction()
	_spawn_chests()
	_spawn_sharks()

	player.reset_for_dive()
	player.z_index = 5
	player.global_position = MapDataRes.PLAYER_SPAWN
	player.set_camera_limits(-120, -260, 5240, 1100)
	player.exhausted.connect(_on_dive_failed)
	player.died.connect(_on_dive_failed)

	hud = HudScene.instantiate()
	add_child(hud)
	hud.setup(player, self)
	player.notice.connect(func(text: String, color: Color) -> void:
		hud.spawn_notice(text, color))

	inventory_panel = InventoryScene.instantiate()
	add_child(inventory_panel)
	results_panel = ResultsScene.instantiate()
	add_child(results_panel)
	pause_menu = PauseScene.instantiate()
	add_child(pause_menu)
	pause_menu.setup(true)

	Sfx.play_ambient("ambient_underwater")


func _input(event: InputEvent) -> void:
	if ended:
		return
	if event.is_action_pressed("inventory"):
		inventory_panel.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		pause_menu.open()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if ended:
		return
	if in_extraction and not player.is_searching() and Input.is_action_just_pressed("interact"):
		_end_dive(true)


func any_shark_alerting() -> bool:
	for s in get_tree().get_nodes_in_group("sharks"):
		if s.is_threatening():
			return true
	return false


## 撤离成功或失败后结算。成功把临时宝物转入岛上库存；失败丢弃。
func _end_dive(success: bool) -> void:
	if ended:
		return
	ended = true
	var items: Array = GameState.dive_bag.duplicate()
	var total := GameState.dive_total_value()
	GameState.end_dive(success)
	SaveManager.save_game(GameState.serialize())
	Sfx.stop_ambient()
	Sfx.play("sell" if success else "fail")
	get_tree().paused = true
	results_panel.open(success, items, total)


func _on_dive_failed() -> void:
	if ended:
		return
	await get_tree().create_timer(BalanceRes.FAIL_RESULT_DELAY).timeout
	_end_dive(false)


# ---------------- 刷新 ----------------

## 每次下潜：A/B/C 各激活固定点位，再从剩余点位随机补足。
func _spawn_chests() -> void:
	var by_zone := {"A": [], "B": [], "C": []}
	for spot in MapDataRes.CHEST_SPOTS:
		by_zone[MapDataRes.zone_at(spot.x)].append(spot)
	for zone in by_zone:
		by_zone[zone].shuffle()

	var counts := {"A": BalanceRes.SPAWN_A_ACTIVE, "B": BalanceRes.SPAWN_B_ACTIVE,
		"C": BalanceRes.SPAWN_C_ACTIVE}
	var active: Array = []
	var rest: Array = []
	for zone in ["A", "B", "C"]:
		active.append_array(by_zone[zone].slice(0, counts[zone]))
		rest.append_array(by_zone[zone].slice(counts[zone]))
	rest.shuffle()
	active.append_array(rest.slice(0, BalanceRes.SPAWN_EXTRA))

	for spot in active:
		var chest := ChestScene.instantiate()
		chest.position = spot
		add_child(chest)
		chest.setup(_roll_treasure(MapDataRes.zone_at(spot.x)))


func _roll_treasure(zone: String) -> String:
	var weights: Dictionary = ItemDBRes.ZONE_WEIGHTS[zone]
	var roll := randf()
	var acc := 0.0
	for id in weights:
		acc += weights[id]
		if roll <= acc:
			return id
	var keys: Array = weights.keys()
	return keys[keys.size() - 1]


func _spawn_sharks() -> void:
	for cfg in MapDataRes.SHARK_PATROLS:
		var shark := SharkScene.instantiate()
		shark.position = Vector2((cfg[0] + cfg[1]) * 0.5, cfg[2])
		shark.z_index = 4
		add_child(shark)
		shark.setup(cfg[0], cfg[1], cfg[2], player)


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

	# 浅海光柱
	for shaft in MapDataRes.LIGHT_SHAFTS:
		var poly := Polygon2D.new()
		var x: float = shaft[0]
		var w: float = shaft[1]
		poly.polygon = PackedVector2Array([
			Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w + 60, 420), Vector2(x - 60, 420)])
		poly.color = Color(1, 1, 0.9, 0.06)
		poly.z_index = -15
		add_child(poly)

	# 海藻（摆动）
	for d in MapDataRes.DECOR_RECTS:
		if d[4] == "seaweed":
			var line := Line2D.new()
			var base_x: float = d[0] + d[2] * 0.5
			var base_y: float = d[1] + d[3]
			var h: float = d[3] * 3.0
			line.points = PackedVector2Array([
				Vector2(base_x, base_y), Vector2(base_x, base_y - h * 0.4),
				Vector2(base_x, base_y - h * 0.7), Vector2(base_x, base_y - h)])
			line.width = 5.0
			line.default_color = Color(0.12, 0.35, 0.24)
			line.z_index = -8
			add_child(line)
			_seaweeds.append({"line": line, "base": base_x, "top_y": base_y - h})
		else:
			var coral := Polygon2D.new()
			coral.polygon = PackedVector2Array([
				Vector2(d[0], d[1] + d[3]), Vector2(d[0] + d[2] * 0.3, d[1] - 14),
				Vector2(d[0] + d[2] * 0.55, d[1] + d[3] * 0.4), Vector2(d[0] + d[2], d[1] + d[3])])
			coral.color = Color(0.75, 0.35, 0.45)
			coral.z_index = -8
			add_child(coral)

	# 气泡
	for i in 10:
		var bubble := Polygon2D.new()
		bubble.polygon = _ellipse(randf_range(3.0, 7.0), randf_range(3.0, 7.0), 8)
		bubble.position = Vector2(randf_range(100, 5000), randf_range(100, 900))
		bubble.color = Color(1, 1, 1, 0.18)
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


func _build_terrain() -> void:
	var body := StaticBody2D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	body.collision_mask = 0
	for r in MapDataRes.SOLID_RECTS:
		var rect := Rect2(r[0], r[1], r[2], r[3])
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		cs.shape = shape
		cs.position = rect.get_center()
		body.add_child(cs)

		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			rect.position, rect.position + Vector2(rect.size.x, 0),
			rect.end, rect.position + Vector2(0, rect.size.y)])
		var base := Color(0.07, 0.12, 0.17)
		var edge := Color(0.2, 0.28, 0.33)
		if r[4] == "sand":
			base = Color(0.16, 0.19, 0.2)
			edge = Color(0.5, 0.45, 0.3)
		elif r[4] == "wreck":
			base = Color(0.19, 0.13, 0.08)
			edge = Color(0.38, 0.27, 0.15)
		poly.color = base
		body.add_child(poly)

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
		var pts: PackedVector2Array = weed["line"].points.duplicate()
		var sway := sin(_shadow_t * 1.4 + weed["base"] * 0.05) * 7.0
		pts[3] = Vector2(weed["base"] + sway, weed["top_y"])
		pts[2] = Vector2(weed["base"] + sway * 0.5, weed["top_y"] + 30.0)
		weed["line"].points = pts
	for b in _bubbles:
		b.position.y -= randf_range(14.0, 30.0) * delta * 3.0
		if b.position.y < 20.0:
			b.position.y = 900.0
			b.position.x = randf_range(100, 5000)
