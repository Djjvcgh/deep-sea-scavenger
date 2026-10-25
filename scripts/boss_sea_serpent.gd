extends Node2D
## 洞穴海蛇（洞穴主题 Boss）：潜伏在深海危险洞穴中。
## 行为：半透明潜伏 → 玩家靠近时锁定方向红线预警 → 沿该方向高速突袭 → 回洞喘息；
## 玩家远离巢穴则潜回（可重新靠近再次触发）。击杀掉深海蛇珠等遗物。

signal defeated(pos: Vector2)
signal submerged

const BalanceRes := preload("res://scripts/balance.gd")
const ItemDBRes := preload("res://scripts/item_db.gd")

enum State { HIDING, TELEGRAPH, LUNGING, COOLDOWN, SINKING }

var boss_name := "洞穴海蛇"
var state: int = State.HIDING
var hp: int = BalanceRes.SERPENT_HP
var hp_max: int = BalanceRes.SERPENT_HP
var player: CharacterBody2D = null
var dead := false
var hit_radius := 36.0
var loot_items: Array = ItemDBRes.SERPENT_LOOT.duplicate(true)

var _lair := Vector2.ZERO
var _aim := Vector2.RIGHT
var _telegraph_left := 0.0
var _lunge_left := 0.0
var _cooldown_left := 0.0
var _lunge_hit := false
var _flash := 0.0
var _t := 0.0

var _visual: Node2D
var _segments: Array = []
var _warning: Line2D
var _eye: Polygon2D


func setup(player_ref: CharacterBody2D) -> void:
	player = player_ref


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	z_index = 3
	_lair = position
	_build_visual()
	modulate.a = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	match state:
		State.HIDING:
			# 半透明潜伏在巢穴，玩家靠近即锁定突袭方向
			modulate.a = maxf(0.35, modulate.a - delta * 2.0)
			if player != null and is_instance_valid(player) \
					and global_position.distance_to(player.global_position) < BalanceRes.SERPENT_AWAKE_DIST:
				_aim = (player.global_position - global_position).normalized()
				_warning.points = PackedVector2Array([Vector2.ZERO, _aim * 460.0])
				_warning.visible = true
				_telegraph_left = BalanceRes.SERPENT_LUNGE_TELEGRAPH
				state = State.TELEGRAPH
				Sfx.play("boss_warn", -4.0)
		State.TELEGRAPH:
			_telegraph_left -= delta
			_warning.modulate.a = 0.3 + 0.6 * (1.0 - _telegraph_left / BalanceRes.SERPENT_LUNGE_TELEGRAPH)
			# 蓄力后仰
			position -= _aim * 40.0 * delta
			if _telegraph_left <= 0.0:
				_warning.visible = false
				_lunge_hit = false
				_lunge_left = BalanceRes.SERPENT_LUNGE_TIME
				state = State.LUNGING
				Sfx.play("slam", -6.0)
		State.LUNGING:
			modulate.a = minf(1.0, modulate.a + delta * 5.0)
			position += _aim * BalanceRes.SERPENT_LUNGE_SPEED * delta
			# 突袭路径接触伤害（每次突袭至多一次）
			if not _lunge_hit and player != null and is_instance_valid(player) \
					and global_position.distance_to(player.global_position) < hit_radius + 22.0:
				_lunge_hit = true
				player.take_damage(BalanceRes.SERPENT_DAMAGE, global_position)
			_lunge_left -= delta
			if _lunge_left <= 0.0:
				_cooldown_left = BalanceRes.SERPENT_COOLDOWN
				state = State.COOLDOWN
		State.COOLDOWN:
			# 缓缓退回巢穴
			position = position.move_toward(_lair, 70.0 * delta)
			_cooldown_left -= delta
			if _cooldown_left <= 0.0:
				state = State.HIDING
		State.SINKING:
			position = position.move_toward(_lair + Vector2(0, 120), 60.0 * delta)
			modulate.a = maxf(0.0, modulate.a - delta / 1.2)
	_animate()


func take_damage(amount: int, _from_pos: Vector2) -> void:
	if state == State.SINKING:
		return
	hp = maxi(0, hp - amount)
	_flash = 0.18
	modulate.a = 1.0
	Sfx.play("stab", -3.0)
	if hp <= 0:
		dead = true
		state = State.SINKING
		Sfx.play("boss_die")
		defeated.emit(global_position)


func is_threatening() -> bool:
	return state in [State.TELEGRAPH, State.LUNGING]


func _animate() -> void:
	_visual.modulate = Color(1.0, 0.45, 0.5) if _flash > 0.0 else Color.WHITE
	_eye.modulate = Color(1, 0.85, 0.3) if state != State.HIDING else Color(0.5, 0.7, 0.6, 0.6)
	# 蛇身节段波动跟随
	var prev := global_position
	for i in _segments.size():
		var seg: Node2D = _segments[i]
		var target := prev - _aim_head_dir() * 22.0
		seg.global_position = seg.global_position.lerp(target, minf(1.0, 9.0 * get_physics_process_delta_time()))
		seg.position += Vector2(sin(_t * 5.0 + i * 1.1), cos(_t * 4.0 + i * 0.9)) * 0.6
		prev = seg.global_position


## 头部朝向：突袭时沿突袭方向，平时朝向玩家
func _aim_head_dir() -> Vector2:
	if state == State.LUNGING:
		return _aim
	if player != null and is_instance_valid(player):
		var to_p := player.global_position - global_position
		if to_p.length() > 1.0:
			return to_p.normalized()
	return _aim


func _build_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)

	# 蛇身：6 个渐小的节段（暗青绿）
	for i in 6:
		var seg := Node2D.new()
		seg.position = Vector2(-24.0 * (i + 1), 0)
		var r := 15.0 - i * 1.6
		var disc := Polygon2D.new()
		disc.polygon = _ellipse(r, r * 0.82, 12)
		disc.color = Color(0.09, 0.3, 0.27, 0.95)
		seg.add_child(disc)
		var fin := Polygon2D.new()
		fin.polygon = PackedVector2Array([Vector2(-2, -r), Vector2(2, -r), Vector2(0, -r - 7.0)])
		fin.color = Color(0.13, 0.42, 0.36, 0.9)
		seg.add_child(fin)
		_visual.add_child(seg)
		_segments.append(seg)

	# 头部
	var head := Polygon2D.new()
	head.polygon = _ellipse(19.0, 14.0, 14)
	head.color = Color(0.11, 0.36, 0.32)
	_visual.add_child(head)
	var jaw := Polygon2D.new()
	jaw.polygon = PackedVector2Array([Vector2(6, 6), Vector2(22, 2), Vector2(6, 12)])
	jaw.color = Color(0.75, 0.78, 0.6, 0.9)
	_visual.add_child(jaw)
	_eye = Polygon2D.new()
	_eye.polygon = _ellipse(4.0, 4.0, 8)
	_eye.position = Vector2(7, -5)
	_eye.color = Color(1, 0.85, 0.3)
	_visual.add_child(_eye)

	# 突袭预警线（从蛇头指向锁定方向）
	_warning = Line2D.new()
	_warning.width = 4.0
	_warning.default_color = Color(1.0, 0.45, 0.3, 0.6)
	_warning.visible = false
	add_child(_warning)


static func _ellipse(rx: float, ry: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
