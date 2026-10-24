extends Node2D
## 荒岛基地：安全区域（不消耗体力）。
## 阶段一先提供：环境、地面、玩家行走、下潜入口、暂停。
## 商人 / 工作台 / 船坞在阶段四接入。

const PlayerScript := preload("res://scripts/player.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const PauseScene := preload("res://scenes/ui/pause_menu.tscn")
const InteractableScript := preload("res://scripts/island_interactable.gd")

const GROUND_Y := 560.0

var player: CharacterBody2D
var pause_menu: CanvasLayer

var _waves: Array = []
var _t := 0.0


func _ready() -> void:
	_build_environment()
	_build_ground()
	player = PlayerScene.instantiate()
	player.mode = PlayerScript.Mode.WALK
	player.position = Vector2(240, 500)
	player.z_index = 5
	add_child(player)
	player.set_camera_limits(0, 0, 1280, 720)
	_add_interactable("下潜点", Vector2(150, 520),
		func() -> void: get_tree().change_scene_to_file("res://scenes/underwater.tscn"))
	pause_menu = PauseScene.instantiate()
	add_child(pause_menu)
	pause_menu.setup(false)
	Sfx.play_ambient("ambient_island")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_menu.open()
		get_viewport().set_input_as_handled()


func _add_interactable(text: String, pos: Vector2, cb: Callable) -> void:
	var area: Area2D = InteractableScript.new()
	area.position = pos
	area.z_index = 4
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

	# 太阳
	var sun := Polygon2D.new()
	sun.polygon = _ellipse(36.0, 36.0, 16)
	sun.position = Vector2(1080, 110)
	sun.color = Color(0.98, 0.9, 0.6)
	sun.z_index = -18
	add_child(sun)

	# 左侧大海
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

	# 棕榈树
	for x in [640.0, 1180.0]:
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


static func _ellipse(rx: float, ry: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
