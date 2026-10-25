extends CharacterBody2D
## 鲨鱼 AI：巡逻 → 警戒 → 追逐 → 返回 的有限状态机。
## 用 RayCast2D 视线检测实现掩体躲避；接触玩家时造成伤害。

signal state_changed(new_state: int)
signal died(pos: Vector2)

enum State { PATROL, ALERT, CHASE, RETURN, FLEE }

const BalanceRes := preload("res://scripts/balance.gd")

var patrol_min_x := 0.0
var patrol_max_x := 600.0
var patrol_y := 500.0
var state: int = State.PATROL
var player: CharacterBody2D = null
var hp: int = BalanceRes.SHARK_HP
var dead := false
var hit_radius := 44.0

var _dir := 1.0
var _alert_left := 0.0
var _lose_sight_left := 0.0
var _attack_cd := 0.0
var _retreat_left := 0.0
var _flee_left := 0.0
var _flee_dir := Vector2.ZERO
var _flash_left := 0.0
var _anim_t := 0.0

@onready var los: RayCast2D = $Los
@onready var bite: Area2D = $Bite
@onready var visual: Node2D = $Visual

var _tail: Node2D
var _mark: Node2D


func setup(min_x: float, max_x: float, y: float, player_ref: CharacterBody2D) -> void:
	patrol_min_x = min_x
	patrol_max_x = max_x
	patrol_y = y
	player = player_ref


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	los.collision_mask = 1
	los.collide_with_areas = false
	bite.collision_mask = 2
	add_to_group("sharks")
	add_to_group("enemies")
	_build_visual()


## 鱼叉刺击命中。生命归零时死亡（由海底场景生成掉落）。
func take_damage(amount: int, from_pos: Vector2) -> void:
	if dead:
		return
	hp -= amount
	_flash_left = 0.2
	if hp <= 0:
		dead = true
		state = State.PATROL   # 停止 AI 决策（_physics_process 开头拦截）
		collision_layer = 0
		bite.monitoring = false
		died.emit(global_position)
		return
	# 受击逃窜：背向来伤方向高速脱离
	_flee_dir = (global_position - from_pos).normalized()
	if _flee_dir == Vector2.ZERO:
		_flee_dir = Vector2.RIGHT
	_flee_left = BalanceRes.SHARK_FLEE_TIME
	_enter(State.FLEE)


func _physics_process(delta: float) -> void:
	if dead:
		# 死亡下沉：缓缓坠落并淡出
		position.y += 30.0 * delta
		modulate.a = maxf(0.0, modulate.a - delta / 1.5)
		rotation += delta * 0.4
		return
	_anim_t += delta
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_retreat_left = maxf(0.0, _retreat_left - delta)
	_flash_left = maxf(0.0, _flash_left - delta)
	var target_valid: bool = player != null and is_instance_valid(player) and not player.dead
	var can_see: bool = target_valid and _see_player()
	var dist := global_position.distance_to(player.global_position) if target_valid else INF
	var detect := BalanceRes.SHARK_DETECT_RANGE \
		* (BalanceRes.SHARK_DETECT_CURSE_MULT if GameState.has_curse_idol() else 1.0)

	match state:
		State.PATROL:
			velocity.x = _dir * BalanceRes.SHARK_PATROL_SPEED
			velocity.y = (patrol_y - global_position.y) * 2.0
			if global_position.x > patrol_max_x:
				_dir = -1.0
			elif global_position.x < patrol_min_x:
				_dir = 1.0
			if can_see and dist < detect:
				_alert_left = BalanceRes.SHARK_ALERT_TIME
				Sfx.play("alert", -4.0)
				_enter(State.ALERT)
		State.ALERT:
			if target_valid:
				var to_player := (player.global_position - global_position).normalized()
				velocity = velocity.move_toward(to_player * BalanceRes.SHARK_ALERT_SPEED, BalanceRes.SHARK_CHASE_TURN * delta)
			_alert_left -= delta
			if _alert_left <= 0.0:
				if can_see and dist < detect * 1.2:
					_lose_sight_left = BalanceRes.SHARK_LOSE_SIGHT_TIME
					_enter(State.CHASE)
				else:
					_enter(State.PATROL)
		State.CHASE:
			if target_valid:
				if _retreat_left > 0.0:
					# 咬人后的强制脱离：背向玩家游走，给玩家脱身窗口
					var away := (global_position - player.global_position).normalized()
					velocity = velocity.move_toward(away * BalanceRes.SHARK_PATROL_SPEED, 400.0 * delta)
				else:
					var to_player := (player.global_position - global_position).normalized()
					velocity = velocity.move_toward(to_player * BalanceRes.SHARK_CHASE_SPEED, BalanceRes.SHARK_CHASE_TURN * delta)
			if can_see and dist < detect * 1.4:
				_lose_sight_left = BalanceRes.SHARK_LOSE_SIGHT_TIME
			else:
				_lose_sight_left -= delta
			if not target_valid or _lose_sight_left <= 0.0 \
					or dist > detect * BalanceRes.SHARK_GIVEUP_DIST_MULT:
				_enter(State.RETURN)
		State.RETURN:
			var home_x := patrol_min_x \
				if absf(global_position.x - patrol_min_x) < absf(global_position.x - patrol_max_x) \
				else patrol_max_x
			var to_home := (Vector2(home_x, patrol_y) - global_position).normalized()
			velocity = velocity.move_toward(to_home * BalanceRes.SHARK_PATROL_SPEED, 300.0 * delta)
			if absf(global_position.x - home_x) < 26.0 and absf(global_position.y - patrol_y) < 26.0:
				_dir = 1.0 if home_x == patrol_min_x else -1.0
				_enter(State.PATROL)
			elif can_see and dist < detect * 0.7:
				_alert_left = BalanceRes.SHARK_ALERT_TIME
				Sfx.play("alert", -4.0)
				_enter(State.ALERT)
		State.FLEE:
			# 受击逃窜：无视视线，背向玩家高速脱离
			velocity = velocity.move_toward(_flee_dir * BalanceRes.SHARK_CHASE_SPEED * 0.9, 500.0 * delta)
			_flee_left -= delta
			if _flee_left <= 0.0:
				_lose_sight_left = BalanceRes.SHARK_LOSE_SIGHT_TIME
				_enter(State.RETURN)

	move_and_slide()

	# 咬击：与玩家接触且冷却结束（脱离期/逃窜期不咬）。
	if _attack_cd <= 0.0 and _retreat_left <= 0.0 and state != State.FLEE \
			and target_valid and bite.overlaps_body(player):
		_attack_cd = BalanceRes.SHARK_ATTACK_COOLDOWN
		_retreat_left = BalanceRes.SHARK_BITE_RETREAT
		player.take_damage(BalanceRes.SHARK_DAMAGE, global_position)

	_animate()


## 外部事件惊动（如祭祀宝物被扰动）：立刻进入警戒游向玩家。
func disturb() -> void:
	if dead or state == State.CHASE or state == State.FLEE:
		return
	_alert_left = BalanceRes.SHARK_ALERT_TIME
	Sfx.play("alert", -4.0)
	_enter(State.ALERT)


func _enter(s: int) -> void:
	if state == s:
		return
	state = s
	state_changed.emit(s)


func _see_player() -> bool:
	los.target_position = los.to_local(player.global_position)
	los.force_raycast_update()
	return not los.is_colliding()


func is_threatening() -> bool:
	return state == State.ALERT or state == State.CHASE


func _animate() -> void:
	if dead:
		visual.modulate = Color(0.5, 0.45, 0.5, 0.8)
		return
	if absf(velocity.x) > 8.0:
		visual.scale.x = signf(velocity.x)
	var rate := 10.0 if state == State.CHASE else 6.0
	_tail.rotation = sin(_anim_t * rate) * 0.45
	_mark.visible = is_threatening()
	if _mark.visible:
		_mark.position.y = -40.0 + sin(_anim_t * 8.0) * 3.0
	if _flash_left > 0.0:
		visual.modulate = Color(1, 0.25, 0.25)
	elif state == State.CHASE:
		visual.modulate = Color(1.0, 0.55, 0.55)
	elif state == State.ALERT:
		visual.modulate = Color(1.0, 0.8, 0.55)
	else:
		visual.modulate = Color.WHITE


func _build_visual() -> void:
	var body := Polygon2D.new()
	body.polygon = _ellipse(30.0, 10.0)
	body.color = Color(0.32, 0.38, 0.44)
	visual.add_child(body)

	var belly := Polygon2D.new()
	belly.polygon = _ellipse(24.0, 6.0)
	belly.position = Vector2(-2, 4)
	belly.color = Color(0.55, 0.6, 0.64)
	visual.add_child(belly)

	var dorsal := Polygon2D.new()
	dorsal.polygon = PackedVector2Array([Vector2(-6, -9), Vector2(2, -22), Vector2(10, -9)])
	dorsal.color = Color(0.26, 0.31, 0.36)
	visual.add_child(dorsal)

	_tail = Node2D.new()
	_tail.position = Vector2(-28, 0)
	var tail_poly := Polygon2D.new()
	tail_poly.polygon = PackedVector2Array([Vector2(0, -11), Vector2(0, 11), Vector2(-20, 0)])
	tail_poly.color = Color(0.26, 0.31, 0.36)
	_tail.add_child(tail_poly)
	visual.add_child(_tail)

	var eye := Polygon2D.new()
	eye.polygon = _ellipse(2.5, 2.5, 8)
	eye.position = Vector2(19, -4)
	eye.color = Color(0.05, 0.05, 0.05)
	visual.add_child(eye)

	_mark = Node2D.new()
	_mark.visible = false
	var bar := Polygon2D.new()
	bar.polygon = PackedVector2Array([Vector2(-2.5, -18), Vector2(2.5, -18), Vector2(2.5, -5), Vector2(-2.5, -5)])
	bar.color = Color(0.95, 0.3, 0.25)
	_mark.add_child(bar)
	var dot := Polygon2D.new()
	dot.polygon = _ellipse(2.8, 2.8, 8)
	dot.position = Vector2(0, 2)
	dot.color = Color(0.95, 0.3, 0.25)
	_mark.add_child(dot)
	visual.add_child(_mark)


static func _ellipse(rx: float, ry: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
