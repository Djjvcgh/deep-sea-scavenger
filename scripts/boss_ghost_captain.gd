extends Node2D
## 幽灵船长（沉船主题 Boss）：玩家进入沉船长室/舱内时显形。
## 行为：显形 → 循环（缓慢逼近 + 红线预警 → 短距冲刺）→ 生命归零沉没掉船长遗物；
## 玩家远离沉船出生点则遁回（可重新进入再次触发）。偶尔放出无害的幽灵投影迷惑玩家。

signal defeated(pos: Vector2)
signal submerged

const BalanceRes := preload("res://scripts/balance.gd")
const ItemDBRes := preload("res://scripts/item_db.gd")

enum State { EMERGING, ACTIVE, TELEGRAPH, DASHING, SINKING }

var boss_name := "幽灵船长"
var state: int = State.EMERGING
var hp: int = BalanceRes.CAPTAIN_HP
var hp_max: int = BalanceRes.CAPTAIN_HP
var player: CharacterBody2D = null
var dead := false
var hit_radius := 40.0
var loot_items: Array = ItemDBRes.CAPTAIN_LOOT.duplicate(true)

var _emerge_left := 1.6
var _dash_timer := 2.6
var _telegraph_left := 0.0
var _dash_left := 0.0
var _dash_dir := Vector2.RIGHT
var _dash_hit := false
var _home := Vector2.ZERO
var _flash := 0.0
var _t := 0.0
var _ghost_cd := 7.0
var _ghosts: Array = []

var _visual: Node2D
var _coat: Polygon2D
var _warning: Line2D
var _mark: Polygon2D


func setup(player_ref: CharacterBody2D) -> void:
	player = player_ref


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	z_index = 3
	_home = position
	_build_visual()
	Sfx.play("boss_warn")


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	match state:
		State.EMERGING:
			_emerge_left -= delta
			position.y -= 40.0 * delta
			modulate.a = minf(1.0, modulate.a + delta / 1.2)
			if _emerge_left <= 0.0:
				state = State.ACTIVE
		State.ACTIVE:
			_active(delta)
		State.TELEGRAPH:
			_telegraph_left -= delta
			_warning.modulate.a = 0.35 + 0.5 * (1.0 - _telegraph_left / BalanceRes.CAPTAIN_DASH_TELEGRAPH)
			if _telegraph_left <= 0.0:
				_warning.visible = false
				_dash_hit = false
				_dash_left = BalanceRes.CAPTAIN_DASH_TIME
				state = State.DASHING
				Sfx.play("slam", -4.0)
		State.DASHING:
			position += _dash_dir * BalanceRes.CAPTAIN_DASH_SPEED * delta
			# 冲刺路径接触伤害（每次冲刺至多一次）
			if not _dash_hit and player != null and is_instance_valid(player) \
					and global_position.distance_to(player.global_position) < hit_radius + 26.0:
				_dash_hit = true
				player.take_damage(BalanceRes.CAPTAIN_DAMAGE, global_position)
			_dash_left -= delta
			if _dash_left <= 0.0:
				_dash_timer = BalanceRes.CAPTAIN_DASH_INTERVAL
				state = State.ACTIVE
		State.SINKING:
			position.y += 55.0 * delta
			modulate.a = maxf(0.0, modulate.a - delta / 1.4)
	_animate()


func _active(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.dead:
		return
	# 玩家远离沉船：遁回
	if global_position.distance_to(_home) > 40.0 \
			and player.global_position.distance_to(_home) > BalanceRes.CAPTAIN_LEASH:
		state = State.SINKING
		submerged.emit()
		return
	# 缓慢逼近，保持压迫但不贴身
	var to_player := player.global_position - global_position
	if to_player.length() > BalanceRes.CAPTAIN_KEEP_DIST:
		position += to_player.normalized() * BalanceRes.CAPTAIN_DRIFT_SPEED * delta
	# 幽灵投影：周期性放出两个无害的幻影
	_ghost_cd -= delta
	if _ghost_cd <= 0.0:
		_ghost_cd = 8.0
		_spawn_ghosts()
	# 冲刺循环
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_dash_dir = to_player.normalized() if to_player.length() > 1.0 else Vector2.RIGHT
		_warning.points = PackedVector2Array([
			Vector2.ZERO, _dash_dir * BalanceRes.CAPTAIN_DASH_RANGE])
		_warning.visible = true
		_warning.modulate.a = 0.35
		_telegraph_left = BalanceRes.CAPTAIN_DASH_TELEGRAPH
		state = State.TELEGRAPH
		Sfx.play("alert", -2.0)


## 幽灵投影：纯视觉欺骗，不造成伤害。
func _spawn_ghosts() -> void:
	for i in 2:
		var ghost := Node2D.new()
		ghost.position = position + Vector2(-70.0 + i * 140.0, 30.0)
		ghost.z_index = 2
		ghost.modulate = Color(0.5, 0.9, 0.85, 0.0)
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(-14, 20), Vector2(14, 20), Vector2(10, -14), Vector2(0, -22), Vector2(-10, -14)])
		body.color = Color(0.6, 0.95, 0.9, 0.4)
		ghost.add_child(body)
		add_child(ghost)
		_ghosts.append({"node": ghost, "life": 4.0})
		var tw := ghost.create_tween()
		tw.tween_property(ghost, "modulate:a", 0.5, 0.6)


func take_damage(amount: int, _from_pos: Vector2) -> void:
	if state == State.EMERGING or state == State.SINKING:
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
	return state in [State.ACTIVE, State.TELEGRAPH, State.DASHING]


func _animate() -> void:
	_visual.modulate = Color(0.6, 1.0, 0.95) if _flash > 0.0 else Color.WHITE
	# 幻影漂移与消散
	for g in _ghosts.duplicate():
		var node: Node2D = g["node"]
		if not is_instance_valid(node):
			_ghosts.erase(g)
			continue
		g["life"] -= get_physics_process_delta_time()
		if player != null and is_instance_valid(player):
			node.position += (player.global_position - node.position).normalized() * 30.0 \
				* get_physics_process_delta_time()
		if g["life"] <= 0.0:
			node.queue_free()
			_ghosts.erase(g)
	_mark.visible = state == State.TELEGRAPH
	if _mark.visible:
		_mark.position.y = -52.0 + sin(_t * 12.0) * 3.0
	_coat.modulate.a = 0.85 + 0.15 * sin(_t * 2.2)


func _build_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	modulate.a = 0.0

	# 幽蓝薄雾
	var mist := Polygon2D.new()
	mist.polygon = _ellipse(52.0, 46.0, 16)
	mist.color = Color(0.35, 0.7, 0.8, 0.14)
	_visual.add_child(mist)

	# 长外套
	_coat = Polygon2D.new()
	_coat.polygon = PackedVector2Array([
		Vector2(-20, 34), Vector2(20, 34), Vector2(15, -16), Vector2(0, -24), Vector2(-15, -16)])
	_coat.color = Color(0.1, 0.24, 0.3, 0.92)
	_visual.add_child(_coat)

	# 三角帽 + 苍白面孔 + 幽灵眼
	var face := Polygon2D.new()
	face.polygon = _ellipse(9.0, 9.0, 10)
	face.position = Vector2(0, -28)
	face.color = Color(0.75, 0.88, 0.86, 0.9)
	_visual.add_child(face)
	var hat := Polygon2D.new()
	hat.polygon = PackedVector2Array([
		Vector2(-20, -34), Vector2(20, -34), Vector2(0, -48)])
	hat.color = Color(0.05, 0.1, 0.13)
	_visual.add_child(hat)
	for ex in [-4.0, 4.0]:
		var eye := Polygon2D.new()
		eye.polygon = _ellipse(2.2, 2.2, 8)
		eye.position = Vector2(ex, -28)
		eye.color = Color(0.5, 1.0, 0.95)
		_visual.add_child(eye)

	# 军刀
	var saber := Line2D.new()
	saber.points = PackedVector2Array([Vector2(16, 6), Vector2(34, -14)])
	saber.width = 3.0
	saber.default_color = Color(0.8, 0.95, 0.95, 0.85)
	_visual.add_child(saber)

	# 冲刺预警线
	_warning = Line2D.new()
	_warning.width = 4.0
	_warning.default_color = Color(0.4, 1.0, 0.9, 0.6)
	_warning.visible = false
	add_child(_warning)

	# 预警标记
	_mark = Polygon2D.new()
	_mark.visible = false
	_mark.polygon = PackedVector2Array([Vector2(-5, -12), Vector2(5, -12), Vector2(2, -2), Vector2(-2, -2),
		Vector2(2, 2), Vector2(-2, 2)])
	_mark.color = Color(0.4, 1.0, 0.9)
	add_child(_mark)


static func _ellipse(rx: float, ry: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
