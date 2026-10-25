extends Area2D
## 黑潮号残骸关卡的机关交互点：航海日志（可反复翻阅）/ 船尾神龛（开密室暗门）/
## 应急绞盘（开返航捷径）。视觉按 kind 绘制，行为由关卡注入的回调决定。

var kind := "log"            # log / shrine / winch
var prompt_text := ""
var verb := "按 E"
var one_shot := false
var used := false
var on_interact: Callable = Callable()

var _flames: Array = []      # 神龛烛火（静态结构由关卡贴图提供，这里只画动态件）


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
	var t := Time.get_ticks_msec() / 1000.0
	for f in _flames:
		f.modulate.a = 0.65 + 0.3 * sin(t * 4.0 + f.position.x)
		f.scale = Vector2.ONE * (1.0 + 0.08 * sin(t * 3.0 + f.position.x))


func _build_visual() -> void:
	match kind:
		"log":
			_build_log()
		"shrine":
			_build_shrine()
		"winch":
			_build_winch()


## 航海日志：摊开的书页（桌体由场景贴图 desk 提供）。
func _build_log() -> void:
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


## 船尾神龛：两簇幽蓝烛火（龛体由场景贴图 shrine 提供，火苗落在供烛位置）。
func _build_shrine() -> void:
	for off in [Vector2(-15, 68), Vector2(9, 68)]:
		var flame := Polygon2D.new()
		flame.polygon = PackedVector2Array([
			Vector2(0, -10), Vector2(3.5, -4), Vector2(0, 0), Vector2(-3.5, -4)])
		flame.position = off
		flame.color = Color(0.4, 0.95, 0.85, 0.85)
		add_child(flame)
		_flames.append(flame)


## 应急绞盘：锚链（绞盘本体由场景贴图 winch 提供，链身延向龙骨活门）。
func _build_winch() -> void:
	var chain := Line2D.new()
	chain.points = PackedVector2Array([
		Vector2(-2, 14), Vector2(-2, 42), Vector2(-66, 44)])
	chain.width = 3.0
	chain.default_color = Color(0.4, 0.42, 0.48)
	add_child(chain)
