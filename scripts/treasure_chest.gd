extends Area2D
## 宝箱：一次性可搜索交互物（物理层4，组 interactables）。
## 由海底场景在每次下潜开始时摆放并调用 setup() 指定宝物。

const ItemDBRes := preload("res://scripts/item_db.gd")

var treasure_id := "bronze_coins"
var looted := false
var search_progress := 0.0
var search_total := 1.5

var _glow: Polygon2D
var _core_glow: Polygon2D
var _lid: Node2D
var _box: Polygon2D
var _t := randf() * TAU


func setup(id: String) -> void:
	treasure_id = id
	search_total = float(ItemDBRes.TREASURES[id]["search_time"])
	_build()


func is_available() -> bool:
	return not looted


func interact_prompt() -> String:
	return String(ItemDBRes.TREASURES[treasure_id]["name"])


func can_search(_player: Node) -> bool:
	return GameState.can_carry(int(ItemDBRes.TREASURES[treasure_id]["slots"]))


func blocked_reason() -> String:
	return "背包空间不足，无法拾取%s" % ItemDBRes.TREASURES[treasure_id]["name"]


func begin_search() -> void:
	search_progress = 0.0


## 返回搜索进度 0..1，达到 1 表示完成。
func add_search(delta: float) -> float:
	if looted:
		return 0.0
	search_progress += delta
	return clampf(search_progress / search_total, 0.0, 1.0)


func cancel_search() -> void:
	search_progress = 0.0


func search_ratio() -> float:
	return clampf(search_progress / search_total, 0.0, 1.0)


func mark_looted() -> void:
	looted = true
	search_progress = 0.0
	_glow.visible = false
	if _core_glow != null:
		_core_glow.visible = false
	_lid.rotation = -1.0
	_box.color = Color(0.28, 0.2, 0.13)


func _process(delta: float) -> void:
	if _glow == null or looted:
		return
	_t += delta
	_glow.modulate.a = 0.55 + 0.35 * sin(_t * 3.0)
	if _core_glow != null:
		_core_glow.modulate.a = 0.5 + 0.4 * sin(_t * 5.0)


func _build() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	add_to_group("interactables")
	z_index = 2

	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(44, 30)
	cs.shape = shape
	add_child(cs)

	# 光晕按宝物稀有度分层：玩家远远就能判断"值不值得冒险"
	var info: Dictionary = ItemDBRes.TREASURES[treasure_id]
	_glow = Polygon2D.new()
	var glow_rx := 38.0 if info["rare"] else 26.0
	var glow_ry := 16.0 if info["rare"] else 12.0
	_glow.polygon = _ellipse(glow_rx, glow_ry)
	_glow.position = Vector2(0, 8)
	_glow.color = Color(info["color"], 0.65)
	add_child(_glow)

	if info["rare"]:
		# 稀有宝箱中心亮核 + 纵向光柱，隔半个屏幕也能看到
		_core_glow = Polygon2D.new()
		_core_glow.polygon = _ellipse(12.0, 6.0)
		_core_glow.position = Vector2(0, 6)
		_core_glow.color = Color(1, 1, 0.9, 0.8)
		add_child(_core_glow)
		var beam := Polygon2D.new()
		beam.polygon = PackedVector2Array([
			Vector2(-7, -10), Vector2(7, -10), Vector2(13, -150), Vector2(-13, -150)])
		beam.color = Color(info["color"], 0.16)
		add_child(beam)

	_box = Polygon2D.new()
	_box.polygon = PackedVector2Array([
		Vector2(-16, -12), Vector2(16, -12), Vector2(16, 10), Vector2(-16, 10)])
	_box.color = Color(0.36, 0.23, 0.13)
	add_child(_box)

	var trim := Polygon2D.new()
	trim.polygon = PackedVector2Array([Vector2(-16, -3), Vector2(16, -3), Vector2(16, 1), Vector2(-16, 1)])
	trim.color = Color(0.85, 0.68, 0.25)
	add_child(trim)

	_lid = Node2D.new()
	_lid.position = Vector2(-16, -12)
	var lid_poly := Polygon2D.new()
	lid_poly.polygon = PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, -8), Vector2(0, -8)])
	lid_poly.color = Color(0.42, 0.28, 0.16)
	_lid.add_child(lid_poly)
	add_child(_lid)


static func _ellipse(rx: float, ry: float, n := 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
