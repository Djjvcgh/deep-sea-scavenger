extends Area2D
## 黑潮号残骸关卡的机关交互点：航海日志（可反复翻阅）/ 船尾神龛（开密室暗门）/
## 应急绞盘（开返航捷径）。视觉按 kind 绘制，行为由关卡注入的回调决定。

var kind := "log"            # log / shrine / winch
var prompt_text := ""
var verb := "按 E"
var one_shot := false
var used := false
var on_interact: Callable = Callable()

var _flame: Polygon2D


func setup(cfg: Dictionary) -> void:
	kind = String(cfg.get("kind", "log"))
	prompt_text = String(cfg.get("name", ""))
	verb = String(cfg.get("verb", "按 E"))
	one_shot = bool(cfg.get("one_shot", false))
	on_interact = cfg.get("on_interact", Callable())


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	add_to_group("interactables")
	z_index = 3
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(52, 52)
	cs.shape = shape
	add_child(cs)
	_build_visual()


func is_available() -> bool:
	return not (one_shot and used)


func interact_prompt() -> String:
	return prompt_text if is_available() else "%s（已用过）" % prompt_text


func prompt_verb() -> String:
	return verb


func interact(_player: Node) -> void:
	if not is_available():
		return
	if one_shot:
		used = true
	Sfx.play("click", -6.0)
	if on_interact.is_valid():
		on_interact.call()


func _process(delta: float) -> void:
	if _flame != null:
		var t := Time.get_ticks_msec() / 1000.0
		_flame.modulate.a = 0.65 + 0.3 * sin(t * 4.0)
		_flame.scale = Vector2.ONE * (1.0 + 0.08 * sin(t * 3.0))


func _build_visual() -> void:
	match kind:
		"log":
			_build_log()
		"shrine":
			_build_shrine()
		"winch":
			_build_winch()


## 航海日志：斜面书桌 + 摊开的书页。
func _build_log() -> void:
	var desk := Polygon2D.new()
	desk.polygon = PackedVector2Array([
		Vector2(-24, 18), Vector2(24, 18), Vector2(24, 10), Vector2(-24, 10)])
	desk.color = Color(0.42, 0.28, 0.14)
	add_child(desk)
	var legs := Polygon2D.new()
	legs.polygon = PackedVector2Array([
		Vector2(-20, 10), Vector2(-14, 10), Vector2(-14, -6), Vector2(-20, -6),
		Vector2(14, 10), Vector2(20, 10), Vector2(20, -6), Vector2(14, -6)])
	legs.color = Color(0.32, 0.21, 0.1)
	add_child(legs)
	var book := Polygon2D.new()
	book.polygon = PackedVector2Array([
		Vector2(-16, 8), Vector2(0, 4), Vector2(16, 8), Vector2(0, 12)])
	book.color = Color(0.88, 0.84, 0.7)
	add_child(book)
	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(0, 4), Vector2(0, 12)])
	line.width = 2.0
	line.default_color = Color(0.5, 0.44, 0.3)
	add_child(line)


## 船尾神龛：石龛 + 幽蓝长明火（密室存在的视觉线索之一）。
func _build_shrine() -> void:
	var pedestal := Polygon2D.new()
	pedestal.polygon = PackedVector2Array([
		Vector2(-20, 20), Vector2(20, 20), Vector2(14, -8), Vector2(-14, -8)])
	pedestal.color = Color(0.3, 0.34, 0.42)
	add_child(pedestal)
	var niche := Polygon2D.new()
	niche.polygon = PackedVector2Array([
		Vector2(-12, -8), Vector2(12, -8), Vector2(12, -26), Vector2(-12, -26)])
	niche.color = Color(0.16, 0.2, 0.26)
	add_child(niche)
	_flame = Polygon2D.new()
	_flame.polygon = PackedVector2Array([
		Vector2(0, -24), Vector2(6, -14), Vector2(0, -9), Vector2(-6, -14)])
	_flame.color = Color(0.4, 0.95, 0.85, 0.85)
	add_child(_flame)


## 应急绞盘：立柱 + 绞盘轮（辐条随交互后停转）。
func _build_winch() -> void:
	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([
		Vector2(-5, 20), Vector2(5, 20), Vector2(5, -4), Vector2(-5, -4)])
	post.color = Color(0.36, 0.24, 0.12)
	add_child(post)
	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([
		Vector2(-16, 20), Vector2(16, 20), Vector2(16, 26), Vector2(-16, 26)])
	base.color = Color(0.3, 0.2, 0.1)
	add_child(base)
	var wheel := Node2D.new()
	wheel.position = Vector2(0, -12)
	wheel.name = "Wheel"
	add_child(wheel)
	var ring := Polygon2D.new()
	ring.polygon = _ellipse(11.0, 11.0, 14)
	ring.color = Color(0.62, 0.5, 0.2)
	wheel.add_child(ring)
	for i in 4:
		var spoke := Polygon2D.new()
		spoke.polygon = PackedVector2Array([
			Vector2(-1.5, -9), Vector2(1.5, -9), Vector2(1.5, 9), Vector2(-1.5, 9)])
		spoke.color = Color(0.42, 0.32, 0.14)
		var s := Node2D.new()
		s.rotation = PI * 0.5 * i
		s.add_child(spoke)
		wheel.add_child(s)
	var chain := Line2D.new()
	chain.points = PackedVector2Array([Vector2(9, -4), Vector2(18, 4), Vector2(18, 20)])
	chain.width = 3.0
	chain.default_color = Color(0.4, 0.42, 0.48)
	add_child(chain)


static func _ellipse(rx: float, ry: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
