extends Node2D
## 荒岛基地：安全区域（不消耗体力）。
## 包含：下潜点、神秘商人、装备工作台、船坞；永久数据在此自动存档。
## 岛屿横向 2600px，摄像机平滑跟随（摄像机由 player.gd 持有，limit 限制在世界内）。

const PlayerScript := preload("res://scripts/player.gd")
const ThemeRes := preload("res://scripts/level_theme.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const PauseScene := preload("res://scenes/ui/pause_menu.tscn")
const InteractableScript := preload("res://scripts/island_interactable.gd")
const MerchantScene := preload("res://scenes/ui/merchant_panel.tscn")
const UpgradesScene := preload("res://scenes/ui/upgrades_panel.tscn")
const BoatPanelScene := preload("res://scenes/ui/boat_builder_panel.tscn")

const GROUND_Y := 560.0
const ISLAND_WIDTH := 2600.0
# 左右海水区（下潜点在左海滩，船坞滑道朝右海湾）
const SEA_LEFT_END := 300.0
const SEA_RIGHT_START := 2380.0

var player: CharacterBody2D
var pause_menu: CanvasLayer
var merchant_panel: CanvasLayer
var upgrades_panel: CanvasLayer
var boat_panel: CanvasLayer

var _status_label: Label
var _panels: Array = []
var _boat_visual: Node2D
var _waves: Array = []
var _flame: Polygon2D
var _t := 0.0


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_props()

	player = PlayerScene.instantiate()
	player.mode = PlayerScript.Mode.WALK
	player.position = Vector2(420, 500)
	player.z_index = 5
	add_child(player)
	player.set_camera_limits(0, 0, int(ISLAND_WIDTH), 720)

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

	_add_interactable("下潜点", Vector2(160, 520),
		func() -> void: get_tree().change_scene_to_file("res://scenes/underwater.tscn"))
	_add_interactable("神秘商人", Vector2(950, 524), func() -> void: _open_panel(merchant_panel))
	_add_interactable("装备工作台", Vector2(1600, 524), func() -> void: _open_panel(upgrades_panel))
	_add_interactable("船坞", Vector2(2280, 524), func() -> void: _open_panel(boat_panel))

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
	if _flame != null:
		var f := 1.0 + 0.14 * sin(_t * 9.0) + 0.05 * sin(_t * 15.0)
		_flame.scale = Vector2(0.9 + 0.12 * sin(_t * 7.0), f)
		_flame.modulate.a = 0.8 + 0.2 * sin(_t * 11.0)
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
	sky.size = Vector2(ISLAND_WIDTH, GROUND_Y)
	sky.z_index = -20
	add_child(sky)

	var sun := Polygon2D.new()
	sun.polygon = _ellipse(36.0, 36.0, 16)
	sun.position = Vector2(2050, 110)
	sun.color = Color(0.98, 0.9, 0.6)
	sun.z_index = -18
	add_child(sun)

	# 远景云（缓慢飘动的感觉由静态形状分层即可，不引入额外系统）
	for cx in [700.0, 1500.0, 2200.0]:
		var cloud := Polygon2D.new()
		cloud.polygon = PackedVector2Array([
			Vector2(-70, 0), Vector2(-40, -18), Vector2(10, -26), Vector2(60, -12),
			Vector2(80, 0), Vector2(40, 8), Vector2(-40, 8)])
		cloud.position = Vector2(cx, 150.0 + 30.0 * sin(cx))
		cloud.color = Color(1, 1, 1, 0.5)
		cloud.z_index = -17
		add_child(cloud)

	_build_sea(SEA_LEFT_END - 300.0, SEA_LEFT_END, true)
	_build_sea(SEA_RIGHT_START, ISLAND_WIDTH, false)

	for x in [560.0, 1240.0, 1900.0, 2500.0]:
		ThemeRes.sprite(self, "palm", Vector2(x + 26.0, GROUND_Y - 62.0), -9, 2.0,
			Color.WHITE, (x - 560.0) * 0.0004)
	# 草地边条压住沙面
	ThemeRes.tile(self, "grass_edge", "", Rect2(280.0, GROUND_Y - 16.0, ISLAND_WIDTH - 580.0, 32.0),
		Color.WHITE, -9, 3)

	# 沿途装饰：礁石 / 草丛 / 漂木 / 海星（贴图化）
	for d in [["rock", 700.0], ["grass", 820.0], ["drift", 1130.0], ["grass", 1400.0],
			["rock", 1750.0], ["grass", 2050.0], ["drift", 2470.0], ["star", 260.0], ["star", 2420.0]]:
		_add_decor(d[0], d[1])

	# 功能区模块：下潜栈道 / 商人摊位 / 工作区 / 船坞 / 营火（视觉可识别，不依赖木牌）
	ThemeRes.island_pier(self, 24.0, 300.0, GROUND_Y - 12.0)
	ThemeRes.sprite(self, "buoy", Vector2(90.0, 470.0), -2)
	ThemeRes.glow(self, Vector2(90.0, 454.0), 20.0, 13.0, Color(0.98, 0.85, 0.4, 0.26), -1)
	ThemeRes.island_merchant(self, Vector2(950.0, GROUND_Y))
	ThemeRes.island_workshop(self, Vector2(1600.0, GROUND_Y))
	ThemeRes.island_dock(self, Vector2(2280.0, GROUND_Y - 8.0))
	_flame = ThemeRes.island_campfire(self, Vector2(1290.0, GROUND_Y - 2.0))


func _build_sea(x0: float, x1: float, has_dive_beach: bool) -> void:
	var sea := Polygon2D.new()
	sea.polygon = PackedVector2Array([
		Vector2(x0, 420), Vector2(x1 - 40, 430), Vector2(x1, 445),
		Vector2(x1, GROUND_Y), Vector2(x0, GROUND_Y)])
	if not has_dive_beach:
		sea.polygon = PackedVector2Array([
			Vector2(x0, 445), Vector2(x0 + 40, 430), Vector2(x1, 420),
			Vector2(x1, GROUND_Y), Vector2(x0, GROUND_Y)])
	sea.color = Color(0.12, 0.42, 0.5)
	sea.z_index = -16
	add_child(sea)
	for i in 3:
		var line := Line2D.new()
		var y := 445.0 + i * 28.0
		line.points = PackedVector2Array([
			Vector2(x0 + 10, y), Vector2(x0 + (x1 - x0) * 0.35, y),
			Vector2(x0 + (x1 - x0) * 0.7, y), Vector2(x1 - 12, y)])
		line.width = 2.0
		line.default_color = Color(1, 1, 1, 0.35)
		line.z_index = -15
		add_child(line)
		_waves.append({"line": line, "base_y": y, "phase": i * 2.1 + (0.0 if has_dive_beach else 1.3)})


func _add_decor(kind: String, x: float) -> void:
	var node := Node2D.new()
	node.position = Vector2(x, GROUND_Y)
	node.z_index = -9
	match kind:
		"rock":
			var spr := ThemeRes.sprite(node, "rock_b", Vector2(0, -20.0), 0, 1.5)
			spr.flip_h = fmod(x, 200.0) < 100.0
		"grass":
			for i in 3:
				var spr2 := ThemeRes.sprite(node, "grass_tuft", Vector2(-14.0 + i * 14.0, -6.0), 0, 2.0)
				spr2.flip_h = i % 2 == 0
		"drift":
			var log := Polygon2D.new()
			log.polygon = PackedVector2Array([
				Vector2(-26, -3), Vector2(24, -6), Vector2(28, 0), Vector2(-22, 3)])
			log.color = Color(0.45, 0.33, 0.2)
			node.add_child(log)
		"star":
			var star := Polygon2D.new()
			star.polygon = PackedVector2Array([
				Vector2(-8, 2), Vector2(-3, -3), Vector2(0, -9), Vector2(3, -3),
				Vector2(8, 2), Vector2(2, 4), Vector2(0, 3), Vector2(-2, 4)])
			star.color = Color(0.9, 0.5, 0.4)
			node.add_child(star)
	add_child(node)


func _build_ground() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(ISLAND_WIDTH, 720 - GROUND_Y)
	cs.shape = shape
	cs.position = Vector2(ISLAND_WIDTH * 0.5, GROUND_Y + (720 - GROUND_Y) * 0.5)
	body.add_child(cs)

	# 沙面贴图化：逐行加深（视觉层，逻辑碰撞矩形不变）
	var art := Node2D.new()
	art.name = "Art"
	var row := 0
	var y := GROUND_Y
	while y < 720.0:
		var dim := 1.0 - 0.09 * row
		var x := 0.0
		while x < ISLAND_WIDTH:
			ThemeRes.sprite(art, "sand_tile", Vector2(x + 96.0, y + 22.0), 0, 2.0,
				Color(dim, dim, minf(1.0, dim + 0.02)))
			x += 192.0
		y += 44.0
		row += 1
	body.add_child(art)

	# 屏幕两侧隐形边界墙：防止走出世界坠落消失
	for wx in [-20.0, ISLAND_WIDTH + 20.0]:
		var wcs := CollisionShape2D.new()
		var wshape := RectangleShape2D.new()
		wshape.size = Vector2(40, 1600)
		wcs.shape = wshape
		wcs.position = Vector2(wx, 80)
		body.add_child(wcs)
	add_child(body)


func _build_props() -> void:
	# 神秘商人：紫袍兜帽身影
	var merchant := Node2D.new()
	merchant.position = Vector2(950, 524)
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

	# 船坞：未完成的小帆船（随进度显形），滑道朝右海湾
	_boat_visual = Node2D.new()
	_boat_visual.position = Vector2(2280, 552)
	_boat_visual.z_index = 4
	add_child(_boat_visual)
	_refresh_boat_visual()
	# 滑道甲板（入水轨道）
	ThemeRes.sprite(self, "deck_plank", Vector2(2276.0, 572.0), 3, 1.3, Color(0.92, 0.86, 0.78))


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
	bar.add_theme_stylebox_override("panel", UICommon.wood_stylebox(0.92))
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
