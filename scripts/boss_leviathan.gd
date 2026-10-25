extends Node2D
## 深渊巨影（克苏鲁级 Boss）：携带诅咒神像在区域 C 逗留时苏醒。
## 行为：浮现 → 循环（缓慢逼近 + 触拍预警圈 → 拍击）→ 生命归零沉没掉大额战利品；
## 玩家逃出区域 C 则潜回深渊（由海底场景重新计时触发）。
## 鱼叉可造成伤害（自动瞄准会锁定本体的 hit_radius）。

signal defeated(pos: Vector2)
signal submerged

const BalanceRes := preload("res://scripts/balance.gd")
const MapDataRes := preload("res://scripts/map_data.gd")
const ItemDBRes := preload("res://scripts/item_db.gd")

enum State { EMERGING, ACTIVE, SINKING }

var boss_name := "深渊巨影"
var state: int = State.EMERGING
var hp: int = BalanceRes.BOSS_HP
var hp_max: int = BalanceRes.BOSS_HP
var player: CharacterBody2D = null
var dead := false
var hit_radius := 160.0
var loot_items: Array = ItemDBRes.BOSS_LOOT.duplicate(true)
## 巢穴区域（由布局注入）：出生位置限制在其中；zone_check 判定玩家是否仍在深渊区
var spawn_region := Rect2(3620, 560, 1430, 320)
var zone_check := Callable()

var _emerge_left := 2.5
var _slam_timer := 2.2
var _telegraph_left := 0.0
var _marker_pos := Vector2.ZERO
var _flash := 0.0
var _t := 0.0

var _visual: Node2D
var _tentacles: Array = []
var _eye: Polygon2D
var _marker: Node2D
var _marker_ring: Line2D
var _marker_fill: Polygon2D


func setup(player_ref: CharacterBody2D) -> void:
	player = player_ref


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	z_index = 3
	# 在玩家附近的深渊位置浮现
	var px := clampf(player.global_position.x + 300.0,
		spawn_region.position.x, spawn_region.end.x)
	var py := clampf(player.global_position.y - 120.0,
		spawn_region.position.y, spawn_region.end.y)
	position = Vector2(px, py + 380.0)   # 从深处升起
	modulate.a = 0.0
	_build_visual()
	Sfx.play("boss_warn")


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	match state:
		State.EMERGING:
			_emerge_left -= delta
			position.y = move_toward(position.y, position.y - 380.0, 170.0 * delta)
			modulate.a = minf(1.0, modulate.a + delta / 2.0)
			if _emerge_left <= 0.0:
				state = State.ACTIVE
		State.ACTIVE:
			_active(delta)
		State.SINKING:
			position.y += 60.0 * delta
			modulate.a = maxf(0.0, modulate.a - delta / 1.6)
	_animate()


func _active(delta: float) -> void:
	# 玩家离开深渊区：潜回（布局提供区域判定；无判定时按横带 x 阈值兜底）
	if player == null or not is_instance_valid(player):
		state = State.SINKING
		submerged.emit()
		return
	var in_abyss := true
	if zone_check.is_valid():
		in_abyss = zone_check.call(player.global_position)
	elif player.global_position.x < MapDataRes.ZONE_B_END:
		in_abyss = false
	if not in_abyss:
		state = State.SINKING
		submerged.emit()
		return
	# 缓慢逼近（保持压力但不贴身）
	var to_player := player.global_position - position
	if to_player.length() > 320.0:
		position += to_player.normalized() * BalanceRes.BOSS_DRIFT_SPEED * delta

	# 触拍循环
	if _telegraph_left > 0.0:
		_telegraph_left -= delta
		var k := 1.0 - _telegraph_left / BalanceRes.BOSS_TELEGRAPH   # 0→1
		_marker.scale = Vector2.ONE * (0.35 + 0.65 * k)
		_marker.modulate.a = 0.35 + 0.45 * k
		if _telegraph_left <= 0.0:
			_slam()
	else:
		_slam_timer -= delta
		if _slam_timer <= 0.0:
			_marker_pos = player.global_position
			_marker.position = _marker_pos - position
			_telegraph_left = BalanceRes.BOSS_TELEGRAPH
			_slam_timer = BalanceRes.BOSS_SLAM_INTERVAL


func _slam() -> void:
	_marker.scale = Vector2.ONE
	_marker.modulate.a = 0.0
	Sfx.play("slam")
	if player != null and is_instance_valid(player) \
			and player.global_position.distance_to(_marker_pos) <= BalanceRes.BOSS_SLAM_RADIUS:
		player.take_damage(BalanceRes.BOSS_DAMAGE, _marker_pos + Vector2(0, 200))
	if player != null and is_instance_valid(player):
		player.shake(0.25)


func take_damage(amount: int, _from_pos: Vector2) -> void:
	if state != State.ACTIVE:
		return
	hp = maxi(0, hp - amount)
	_flash = 0.18
	Sfx.play("stab", -3.0)
	if hp <= 0:
		dead = true
		state = State.SINKING
		Sfx.play("boss_die")
		defeated.emit(global_position)


func is_threatening() -> bool:
	return state == State.ACTIVE


func _animate() -> void:
	_visual.modulate = Color(1, 0.4, 0.4) if _flash > 0.0 else Color.WHITE
	for i in _tentacles.size():
		var pivot: Node2D = _tentacles[i]
		pivot.rotation = sin(_t * 1.3 + i * 1.7) * 0.13
	_eye.modulate = Color(1, 1, 1) if state == State.ACTIVE \
		else Color(0.6, 0.6, 0.7, 0.8)
	# 预警圈呼吸
	if _telegraph_left <= 0.0 and _marker != null:
		_marker.modulate.a = maxf(0.0, _marker.modulate.a - get_physics_process_delta_time() * 4.0)


func _build_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)

	# 巨大暗影躯体
	var body := Polygon2D.new()
	body.polygon = _ellipse(190.0, 110.0, 22)
	body.color = Color(0.03, 0.05, 0.09, 0.92)
	_visual.add_child(body)

	# 触手（锥形，摆动）
	for i in 5:
		var pivot := Node2D.new()
		pivot.position = Vector2(-120 + i * 60.0, 60.0)
		var tent := Polygon2D.new()
		var w := 16.0 - i % 2 * 4.0
		tent.polygon = PackedVector2Array([
			Vector2(-w, 0), Vector2(w, 0), Vector2(w * 0.35, 210.0), Vector2(-w * 0.35, 210.0)])
		tent.color = Color(0.04, 0.06, 0.1, 0.9)
		pivot.add_child(tent)
		_visual.add_child(pivot)
		_tentacles.append(pivot)

	# 苍白的巨眼
	_eye = Polygon2D.new()
	_eye.polygon = _ellipse(26.0, 18.0, 14)
	_eye.position = Vector2(-30, -30)
	_eye.color = Color(0.82, 0.88, 0.8, 0.95)
	_visual.add_child(_eye)
	var pupil := Polygon2D.new()
	pupil.polygon = _ellipse(9.0, 12.0, 10)
	pupil.position = Vector2(-30, -26)
	pupil.color = Color(0.08, 0.07, 0.06)
	_visual.add_child(pupil)

	# 触拍预警圈
	_marker = Node2D.new()
	_marker.modulate.a = 0.0
	_marker_fill = Polygon2D.new()
	_marker_fill.polygon = _ellipse(BalanceRes.BOSS_SLAM_RADIUS, BalanceRes.BOSS_SLAM_RADIUS, 24)
	_marker_fill.color = Color(0.9, 0.2, 0.15, 0.16)
	_marker.add_child(_marker_fill)
	_marker_ring = Line2D.new()
	var ring_pts := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		ring_pts.append(Vector2(cos(a), sin(a)) * BalanceRes.BOSS_SLAM_RADIUS)
	_marker_ring.points = ring_pts
	_marker_ring.width = 3.0
	_marker_ring.default_color = Color(0.95, 0.25, 0.2, 0.8)
	_marker_ring.closed = true
	_marker.add_child(_marker_ring)
	add_child(_marker)


static func _ellipse(rx: float, ry: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
