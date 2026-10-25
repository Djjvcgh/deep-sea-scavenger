extends Node2D
## 荒岛基地：安全区域（不消耗体力）。
## 包含：下潜点、神秘商人、装备工作台、船坞；永久数据在此自动存档。

const PlayerScript := preload("res://scripts/player.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const PauseScene := preload("res://scenes/ui/pause_menu.tscn")
const InteractableScript := preload("res://scripts/island_interactable.gd")
const MerchantScene := preload("res://scenes/ui/merchant_panel.tscn")
const UpgradesScene := preload("res://scenes/ui/upgrades_panel.tscn")
const BoatPanelScene := preload("res://scenes/ui/boat_builder_panel.tscn")

const GROUND_Y := 560.0

var player: CharacterBody2D
var pause_menu: CanvasLayer
var merchant_panel: CanvasLayer
var upgrades_panel: CanvasLayer
var boat_panel: CanvasLayer

var _status_label: Label
var _panels: Array = []
var _boat_visual: Node2D
var _waves: Array = []
var _t := 0.0


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_props()

	player = PlayerScene.instantiate()
	player.mode = PlayerScript.Mode.WALK
	player.position = Vector2(240, 500)
	player.z_index = 5
	add_child(player)
	player.set_camera_limits(0, 0, 1280, 720)

	merchant_panel = MerchantScene.instantiate()
	add_child(merchant_panel)
	upgrades_panel = UpgradesScene.instantiate()
	add_child(upgrades_panel)
	boat_panel = BoatPanelScene.instantiate()
	add_child(boat_panel)
	_panels = [merchant_panel, upgrades_panel, boat_panel]
	# 面板以任何方式关闭（按钮/Esc/造船完成自动弹出后关闭）都恢复玩家移动。
	for p in _panels:
		p.closed.connect(_on_panel_closed)

	_add_interactable("下潜点", Vector2(150, 520),
		func() -> void: get_tree().change_scene_to_file("res://scenes/underwater.tscn"))
	_add_interactable("神秘商人", Vector2(560, 524), func() -> void: _open_panel(merchant_panel))
	_add_interactable("装备工作台", Vector2(820, 524), func() -> void: _open_panel(upgrades_panel))
	_add_interactable("船坞", Vector2(1060, 524), func() -> void: _open_panel(boat_panel))

	_build_status_bar()
	pause_menu = PauseScene.instantiate()
	add_child(pause_menu)
	pause_menu.setup(false)

	# 任何永久数据变化都自动存档（下潜结算由海底场景显式存档）。
	# 注意：连接 autoload 信号必须用命名方法，场景释放时自动断开；lambda 会残留连接。
	GameState.credits_changed.connect(_on_permanent_changed)
	GameState.island_stock_changed.connect(_on_permanent_changed)
	GameState.materials_changed.connect(_on_permanent_changed)
	GameState.upgrades_changed.connect(_on_permanent_changed)
	GameState.boat_changed.connect(_on_permanent_changed)
	GameState.boat_changed.connect(_refresh_boat_visual)
	GameState.boat_completed_signal.connect(_on_boat_completed)

	Sfx.play_ambient("ambient_island")
	SaveManager.save_game(GameState.serialize())


func _on_permanent_changed(_arg: Variant = null) -> void:
	_save()
	_refresh_status()


func _save() -> void:
	SaveManager.save_game(GameState.serialize())


func _open_panel(panel: CanvasLayer) -> void:
	panel.open()
	player.control_locked = true
	Sfx.play("click")


func _close_panels() -> bool:
	var closed_any := false
	for p in _panels:
		if p.visible:
			p.close()
			closed_any = true
	return closed_any


func _on_panel_closed() -> void:
	player.control_locked = false


func _on_boat_completed() -> void:
	Sfx.play("build")
	boat_panel.open()
	player.control_locked = true


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _close_panels():
			get_viewport().set_input_as_handled()
			return
		pause_menu.open()
		get_viewport().set_input_as_handled()


func _add_interactable(text: String, pos: Vector2, cb: Callable) -> void:
	var area: Area2D = InteractableScript.new()
	area.position = pos
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 70.0
	cs.shape = shape
	area.add_child(cs)
	add_child(area)
	area.setup(text, cb)
	area.setup_visual(text)


func _process(delta: float) -> void:
	_t += delta
	for w in _waves:
		var line: Line2D = w["line"]
		var pts: PackedVector2Array = line.points.duplicate()
		for i in pts.size():
			pts[i].y = w["base_y"] + sin(_t * 1.6 + i * 1.2 + w["phase"]) * 3.0
		line.points = pts


# ---------------- 场景搭建 ----------------

func _build_environment() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 1.0])
	grad.colors = PackedColorArray([
		Color(0.35, 0.65, 0.78), Color(0.62, 0.8, 0.82), Color(0.85, 0.78, 0.6), Color(0.83, 0.72, 0.5)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 256
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var sky := TextureRect.new()
	sky.texture = tex
	sky.size = Vector2(1280, GROUND_Y)
	sky.z_index = -20
	add_child(sky)

	var sun := Polygon2D.new()
	sun.polygon = _ellipse(36.0, 36.0, 16)
	sun.position = Vector2(1080, 110)
	sun.color = Color(0.98, 0.9, 0.6)
	sun.z_index = -18
	add_child(sun)

	var sea := Polygon2D.new()
	sea.polygon = PackedVector2Array([Vector2(0, 420), Vector2(260, 430), Vector2(260, GROUND_Y), Vector2(0, GROUND_Y)])
	sea.color = Color(0.12, 0.42, 0.5)
	sea.z_index = -16
	add_child(sea)
	for i in 3:
		var line := Line2D.new()
		var y := 445.0 + i * 28.0
		line.points = PackedVector2Array([Vector2(10, y), Vector2(80, y), Vector2(150, y), Vector2(230, y)])
		line.width = 2.0
		line.default_color = Color(1, 1, 1, 0.35)
		line.z_index = -15
		add_child(line)
		_waves.append({"line": line, "base_y": y, "phase": i * 2.1})

	for x in [400.0, 740.0]:
		_add_palm(x)


func _add_palm(x: float) -> void:
	var trunk := Line2D.new()
	trunk.points = PackedVector2Array([Vector2(x, GROUND_Y), Vector2(x + 14, GROUND_Y - 60), Vector2(x + 34, GROUND_Y - 100)])
	trunk.width = 8.0
	trunk.default_color = Color(0.4, 0.28, 0.16)
	trunk.z_index = -10
	add_child(trunk)
	var leaves := Polygon2D.new()
	leaves.polygon = PackedVector2Array([
		Vector2(x + 34, GROUND_Y - 100), Vector2(x + 2, GROUND_Y - 116), Vector2(x + 64, GROUND_Y - 118),
		Vector2(x + 40, GROUND_Y - 84), Vector2(x + 74, GROUND_Y - 96), Vector2(x + 44, GROUND_Y - 76)])
	leaves.color = Color(0.16, 0.45, 0.22)
	leaves.z_index = -10
	add_child(leaves)


func _build_ground() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1280, 720 - GROUND_Y)
	cs.shape = shape
	cs.position = Vector2(640, GROUND_Y + (720 - GROUND_Y) * 0.5)
	body.add_child(cs)

	var sand := Polygon2D.new()
	sand.polygon = PackedVector2Array([Vector2(0, GROUND_Y), Vector2(1280, GROUND_Y), Vector2(1280, 720), Vector2(0, 720)])
	sand.color = Color(0.76, 0.66, 0.45)
	body.add_child(sand)

	var grass := Line2D.new()
	grass.points = PackedVector2Array([Vector2(0, GROUND_Y), Vector2(1280, GROUND_Y)])
	grass.width = 6.0
	grass.default_color = Color(0.4, 0.6, 0.3)
	body.add_child(grass)
	add_child(body)


func _build_props() -> void:
	# 神秘商人：紫袍兜帽身影
	var merchant := Node2D.new()
	merchant.position = Vector2(560, 524)
	merchant.z_index = 4
	var robe := Polygon2D.new()
	robe.polygon = PackedVector2Array([
		Vector2(-16, 36), Vector2(16, 36), Vector2(10, -14), Vector2(0, -22), Vector2(-10, -14)])
	robe.color = Color(0.32, 0.2, 0.42)
	merchant.add_child(robe)
	var hood := Polygon2D.new()
	hood.polygon = _ellipse(8.0, 8.0, 10)
	hood.position = Vector2(0, -22)
	hood.color = Color(0.1, 0.06, 0.14)
	merchant.add_child(hood)
	var eye := Polygon2D.new()
	eye.polygon = _ellipse(1.6, 1.6, 6)
	eye.position = Vector2(3, -22)
	eye.color = Color(0.95, 0.78, 0.25)
	merchant.add_child(eye)
	add_child(merchant)

	# 装备工作台：木桌与工具
	var bench := Node2D.new()
	bench.position = Vector2(820, 540)
	bench.z_index = 4
	var table := Polygon2D.new()
	table.polygon = PackedVector2Array([Vector2(-30, -14), Vector2(30, -14), Vector2(26, 20), Vector2(-26, 20)])
	table.color = Color(0.45, 0.3, 0.16)
	bench.add_child(table)
	var tool := Polygon2D.new()
	tool.polygon = PackedVector2Array([Vector2(-8, -22), Vector2(-2, -22), Vector2(0, -14), Vector2(-10, -14)])
	tool.color = Color(0.55, 0.57, 0.6)
	bench.add_child(tool)
	add_child(bench)

	# 船坞：未完成的小帆船（随进度显形）
	_boat_visual = Node2D.new()
	_boat_visual.position = Vector2(1060, 552)
	_boat_visual.z_index = 4
	add_child(_boat_visual)
	_refresh_boat_visual()
	var slipway := Polygon2D.new()
	slipway.polygon = PackedVector2Array([Vector2(990, 560), Vector2(1130, 560), Vector2(1120, 568), Vector2(1000, 568)])
	slipway.color = Color(0.5, 0.42, 0.3)
	slipway.z_index = 3
	add_child(slipway)


func _refresh_boat_visual() -> void:
	for c in _boat_visual.get_children():
		c.queue_free()
	var wood_r: float = clampf(float(GameState.boat_invested["wood"]) / 2.0, 0.0, 1.0)
	var iron_r: float = clampf(float(GameState.boat_invested["iron"]) / 1.0, 0.0, 1.0)
	var canvas_r: float = clampf(float(GameState.boat_invested["canvas"]) / 1.0, 0.0, 1.0)

	var hull := Polygon2D.new()
	hull.polygon = PackedVector2Array([Vector2(-60, -12), Vector2(60, -12), Vector2(42, 14), Vector2(-42, 14)])
	hull.color = Color(0.5, 0.34, 0.16, 0.25 + 0.75 * wood_r)
	_boat_visual.add_child(hull)

	if iron_r > 0.0:
		var mast := Polygon2D.new()
		mast.polygon = PackedVector2Array([Vector2(-2.5, -12), Vector2(2.5, -12), Vector2(2.5, -74), Vector2(-2.5, -74)])
		mast.color = Color(0.62, 0.63, 0.68, 0.3 + 0.7 * iron_r)
		_boat_visual.add_child(mast)

	if canvas_r > 0.0:
		var sail := Polygon2D.new()
		sail.polygon = PackedVector2Array([Vector2(4, -70), Vector2(4, -18), Vector2(48, -18)])
		sail.color = Color(0.92, 0.9, 0.82, 0.25 + 0.75 * canvas_r)
		_boat_visual.add_child(sail)

	if GameState.boat_completed:
		var flag := Polygon2D.new()
		flag.polygon = PackedVector2Array([Vector2(3, -74), Vector2(26, -68), Vector2(3, -62)])
		flag.color = Color(0.95, 0.78, 0.25)
		_boat_visual.add_child(flag)


func _build_status_bar() -> void:
	var layer_ui := CanvasLayer.new()
	layer_ui.layer = 4
	add_child(layer_ui)
	var bar := PanelContainer.new()
	bar.position = Vector2(12, 8)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	bar.add_child(box)
	_status_label = UICommon.label("", 16)
	box.add_child(_status_label)
	var hint := UICommon.label("走向木牌按 E 交互 · Esc 暂停", 13, UICommon.DIM)
	box.add_child(hint)
	layer_ui.add_child(bar)
	_refresh_status()


func _refresh_status() -> void:
	_status_label.text = "交易额度 %d | 木材 %d · 铁件 %d · 帆布 %d | 背包容量 %d格 | 体力上限 %d | 造船 %d%%" \
		% [GameState.credits, GameState.materials["wood"], GameState.materials["iron"],
		GameState.materials["canvas"], GameState.bag_capacity(), int(GameState.max_stamina()),
		int(GameState.boat_progress() * 100.0)]


static func _ellipse(rx: float, ry: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
