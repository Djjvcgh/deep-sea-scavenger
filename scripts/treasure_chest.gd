extends Area2D
## 可搜索容器（物理层4，组 interactables）：沉船宝箱 / 海贝 / 垃圾袋 / 遗落物袋。
## loot_provider 回调在搜索完成时生成掉落条目：
##   {"id": String, "quality": String} 宝物实例 或 {"mat": String} 材料
## 遗落物袋（cache）的剩余条目在拾取面板关闭时通过 restore_leftovers() 放回缓存。

const ItemDBRes := preload("res://scripts/item_db.gd")

var container_kind := "chest"
var container_name := "沉船宝箱"
var search_total := 3.0
var looted := false
var search_progress := 0.0
var loot_provider: Callable = Callable()

var _glow: Polygon2D
var _core_glow: Polygon2D
var _lid: Node2D
var _box: Polygon2D
var _body_visuals: Node2D
var _t := randf() * TAU


## cfg: kind / name / search_time / loot(Callable) / glow(Color)
func setup_container(cfg: Dictionary) -> void:
	container_kind = cfg["kind"]
	container_name = String(cfg["name"])
	search_total = float(cfg["search_time"])
	loot_provider = cfg.get("loot", Callable())
	_build(cfg.get("glow", Color(0.95, 0.78, 0.25, 0.65)))


func is_available() -> bool:
	return not looted


func interact_prompt() -> String:
	return container_name


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


## 搜索完成：标记已搜取并生成掉落条目。
func collect_loot() -> Array:
	if looted:
		return []
	looted = true
	search_progress = 0.0
	_glow.visible = false
	if _core_glow != null:
		_core_glow.visible = false
	_apply_looted_visual()
	if loot_provider.is_valid():
		return loot_provider.call()
	return []


## 遗落物袋专用：拾取面板关闭时把未取走的条目放回缓存。
func restore_leftovers(entries: Array) -> void:
	if container_kind == "cache" and not entries.is_empty():
		GameState.restore_to_cache(entries)


func _apply_looted_visual() -> void:
	match container_kind:
		"chest":
			_lid.rotation = -1.0
			_box.color = Color(0.28, 0.2, 0.13)
		_:
			_body_visuals.modulate = Color(0.55, 0.55, 0.58)


func _process(delta: float) -> void:
	if _glow == null or looted:
		return
	_t += delta
	_glow.modulate.a = 0.55 + 0.35 * sin(_t * 3.0)
	if _core_glow != null:
		_core_glow.modulate.a = 0.5 + 0.4 * sin(_t * 5.0)


func _build(glow_color: Color) -> void:
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

	_glow = Polygon2D.new()
	_glow.polygon = _ellipse(30.0, 14.0)
	_glow.position = Vector2(0, 8)
	_glow.color = glow_color
	add_child(_glow)

	_body_visuals = Node2D.new()
	add_child(_body_visuals)
	match container_kind:
		"chest":
			_build_chest()
		"shell":
			_build_shell()
		"trash_bag":
			_build_trash_bag()
		"cache":
			_build_cache()


func _build_chest() -> void:
	_box = Polygon2D.new()
	_box.polygon = PackedVector2Array([
		Vector2(-16, -12), Vector2(16, -12), Vector2(16, 10), Vector2(-16, 10)])
	_box.color = Color(0.36, 0.23, 0.13)
	_body_visuals.add_child(_box)

	var trim := Polygon2D.new()
	trim.polygon = PackedVector2Array([Vector2(-16, -3), Vector2(16, -3), Vector2(16, 1), Vector2(-16, 1)])
	trim.color = Color(0.85, 0.68, 0.25)
	_body_visuals.add_child(trim)

	_lid = Node2D.new()
	_lid.position = Vector2(-16, -12)
	var lid_poly := Polygon2D.new()
	lid_poly.polygon = PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, -8), Vector2(0, -8)])
	lid_poly.color = Color(0.42, 0.28, 0.16)
	_lid.add_child(lid_poly)
	_body_visuals.add_child(_lid)


func _build_shell() -> void:
	# 扇贝：底铰 + 放射壳纹
	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([
		Vector2(-14, 6), Vector2(0, -12), Vector2(14, 6), Vector2(0, 10)])
	base.color = Color(0.9, 0.62, 0.72)
	_body_visuals.add_child(base)
	for i in 3:
		var rib := Line2D.new()
		rib.points = PackedVector2Array([Vector2(0, 8), Vector2(-9 + i * 9.0, -9)])
		rib.width = 2.0
		rib.default_color = Color(0.75, 0.45, 0.58)
		_body_visuals.add_child(rib)


func _build_trash_bag() -> void:
	var bag := Polygon2D.new()
	bag.polygon = PackedVector2Array([
		Vector2(-13, 10), Vector2(-15, -2), Vector2(-8, -10), Vector2(8, -10),
		Vector2(15, -2), Vector2(13, 10)])
	bag.color = Color(0.16, 0.2, 0.2)
	_body_visuals.add_child(bag)
	var knot := Polygon2D.new()
	knot.polygon = PackedVector2Array([
		Vector2(-4, -10), Vector2(4, -10), Vector2(2, -16), Vector2(-2, -16)])
	knot.color = Color(0.3, 0.36, 0.34)
	_body_visuals.add_child(knot)


func _build_cache() -> void:
	# 遗落物袋：暖棕布袋 + 青色核心光点（灵魂信号感）
	var sack := Polygon2D.new()
	sack.polygon = PackedVector2Array([
		Vector2(-12, 10), Vector2(-14, -4), Vector2(-6, -12), Vector2(6, -12),
		Vector2(14, -4), Vector2(12, 10)])
	sack.color = Color(0.45, 0.34, 0.2)
	_body_visuals.add_child(sack)
	var tie := Polygon2D.new()
	tie.polygon = PackedVector2Array([Vector2(-5, -12), Vector2(5, -12), Vector2(0, -18)])
	tie.color = Color(0.6, 0.46, 0.28)
	_body_visuals.add_child(tie)

	_core_glow = Polygon2D.new()
	_core_glow.polygon = _ellipse(6.0, 6.0, 8)
	_core_glow.position = Vector2(0, -2)
	_core_glow.color = Color(0.5, 0.9, 0.95, 0.85)
	_body_visuals.add_child(_core_glow)


static func _ellipse(rx: float, ry: float, n := 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
