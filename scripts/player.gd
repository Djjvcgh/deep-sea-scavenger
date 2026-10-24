extends CharacterBody2D
## 玩家：水下游泳（SWIM）/ 荒岛行走（WALK）两种模式。
## 负责移动、体力、生命、交互（长按搜索宝箱 / 按键触发交互点）与视觉反馈。

signal hp_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal hurt
signal died
signal exhausted
signal notice(text: String, color: Color)

enum Mode { SWIM, WALK }

@export var mode: Mode = Mode.SWIM

const BalanceRes := preload("res://scripts/balance.gd")

var max_hp := 3
var hp := 3
var max_stamina := 100.0
var stamina := 100.0
var invincible_left := 0.0
var dead := false
var exhausted_fired := false
var control_locked := false        # 搜索宝箱时锁定移动
var focus_target: Area2D = null    # 当前可交互目标（供 HUD 显示提示）
var active_chest: Area2D = null    # 正在搜索的宝箱

var _anim_t := 0.0
var _flash_left := 0.0
var _notice_cd := 0.0

@onready var interact_area: Area2D = $InteractRange
@onready var camera: Camera2D = $Camera2D
@onready var visual: Node2D = $Visual

var _fin_a: Node2D
var _fin_b: Node2D
var _leg_a: Node2D
var _leg_b: Node2D


func _ready() -> void:
	max_hp = BalanceRes.MAX_HP
	hp = max_hp
	max_stamina = GameState.max_stamina()
	stamina = max_stamina
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING if mode == Mode.SWIM \
		else CharacterBody2D.MOTION_MODE_GROUNDED
	_build_visual()


func _physics_process(delta: float) -> void:
	_anim_t += delta
	invincible_left = maxf(0.0, invincible_left - delta)
	_flash_left = maxf(0.0, _flash_left - delta)
	_notice_cd = maxf(0.0, _notice_cd - delta)
	_animate()
	if dead:
		velocity = velocity.move_toward(Vector2(0, -26), 200.0 * delta)
		move_and_slide()
		return
	if mode == Mode.SWIM:
		_swim(delta)
	else:
		_walk(delta)
	_update_interact()


# ---------------- 移动 ----------------

func _swim(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if control_locked:
		dir = Vector2.ZERO
	var sprinting := Input.is_action_pressed("sprint") and dir != Vector2.ZERO and stamina > 1.0
	var speed := BalanceRes.SPRINT_SPEED if sprinting else BalanceRes.SWIM_SPEED
	speed *= GameState.speed_mult() * GameState.weight_speed_mult()
	var rate := BalanceRes.SWIM_ACCEL if dir != Vector2.ZERO else BalanceRes.SWIM_FRICTION
	velocity = velocity.move_toward(dir * speed, rate * delta)
	move_and_slide()
	# 水面：不允许跃出水面
	if global_position.y < 40.0:
		global_position.y = 40.0
		velocity.y = maxf(0.0, velocity.y)
	# 体力消耗（搜索期间按游泳消耗计）
	var drain := BalanceRes.DRAIN_IDLE
	if sprinting:
		drain = BalanceRes.DRAIN_SPRINT
	elif control_locked:
		drain = BalanceRes.DRAIN_SEARCH
	elif dir != Vector2.ZERO:
		drain = BalanceRes.DRAIN_SWIM
	_drain_stamina(drain * GameState.weight_drain_mult() * delta)


func _walk(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if control_locked:
		dir = 0.0
	velocity.x = move_toward(velocity.x, dir * BalanceRes.WALK_SPEED, BalanceRes.WALK_ACCEL * delta)
	if not is_on_floor():
		velocity.y += 980.0 * delta
	move_and_slide()


func _drain_stamina(amount: float) -> void:
	if mode != Mode.SWIM or dead:
		return
	stamina = maxf(0.0, stamina - amount)
	stamina_changed.emit(stamina, max_stamina)
	if stamina <= 0.0 and not exhausted_fired:
		exhausted_fired = true
		Sfx.play("exhaust")
		exhausted.emit()


# ---------------- 交互 ----------------

func _update_interact() -> void:
	focus_target = null
	var best_d := INF
	for a in interact_area.get_overlapping_areas():
		if not a.is_in_group("interactables") or not a.is_available():
			continue
		var d := global_position.distance_squared_to(a.global_position)
		if d < best_d:
			best_d = d
			focus_target = a

	var holding := Input.is_action_pressed("interact")
	if active_chest != null:
		if not holding or not is_instance_valid(active_chest) or not active_chest.is_available():
			_cancel_search()
		elif active_chest.add_search(get_physics_process_delta_time()) >= 1.0:
			_complete_loot()
	elif not control_locked and holding and focus_target != null \
			and focus_target.has_method("begin_search"):
		if focus_target.can_search(self):
			active_chest = focus_target
			active_chest.begin_search()
			control_locked = true
		elif _notice_cd <= 0.0:
			_notice_cd = 0.9
			notice.emit(focus_target.blocked_reason(), UICommon.DANGER)

	if active_chest == null and not control_locked and focus_target != null \
			and focus_target.has_method("interact") \
			and Input.is_action_just_pressed("interact"):
		focus_target.interact(self)


func _cancel_search() -> void:
	if active_chest != null and is_instance_valid(active_chest):
		active_chest.cancel_search()
	active_chest = null
	control_locked = false


func _complete_loot() -> void:
	var chest := active_chest
	_cancel_search()
	if chest == null or not is_instance_valid(chest):
		return
	var id: String = chest.treasure_id
	chest.mark_looted()
	var info: Dictionary = ItemDB.TREASURES[id]
	if not GameState.add_dive_item(id):
		notice.emit("背包空间不足", UICommon.DANGER)
		return
	Sfx.play("rare_pickup" if info["rare"] else "pickup")
	notice.emit("获得：%s（估值 %d）" % [info["name"], info["value"]],
		UICommon.GOLD if info["rare"] else UICommon.CYAN)


func is_searching() -> bool:
	return active_chest != null


# ---------------- 生命与伤害 ----------------

func take_damage(amount: int) -> void:
	if dead or invincible_left > 0.0:
		return
	hp = maxi(0, hp - amount)
	invincible_left = BalanceRes.INVINCIBLE_TIME
	_flash_left = 0.25
	_cancel_search()
	hp_changed.emit(hp, max_hp)
	hurt.emit()
	Sfx.play("hurt")
	if hp <= 0:
		dead = true
		died.emit()


func reset_for_dive() -> void:
	max_stamina = GameState.max_stamina()
	stamina = max_stamina
	hp = max_hp
	dead = false
	exhausted_fired = false
	invincible_left = 0.0
	_cancel_search()
	visual.modulate = Color.WHITE
	hp_changed.emit(hp, max_hp)
	stamina_changed.emit(stamina, max_stamina)


func set_camera_limits(left: int, top: int, right: int, bottom: int) -> void:
	camera.limit_left = left
	camera.limit_top = top
	camera.limit_right = right
	camera.limit_bottom = bottom
	camera.reset_smoothing()


# ---------------- 视觉 ----------------

func _animate() -> void:
	var speed := velocity.length()
	if mode == Mode.SWIM and speed > 12.0:
		visual.rotation = lerp_angle(visual.rotation, velocity.angle(), 8.0 * get_physics_process_delta_time())
		visual.scale.x = 1.0
	elif mode == Mode.WALK:
		visual.rotation = 0.0
		if absf(velocity.x) > 5.0:
			visual.scale.x = signf(velocity.x)
	else:
		visual.rotation = lerp_angle(visual.rotation, 0.0, 6.0 * get_physics_process_delta_time())
	var kick := sin(_anim_t * (7.0 if speed > 12.0 else 2.5))
	if _fin_a != null:
		_fin_a.rotation = kick * 0.5
		_fin_b.rotation = -kick * 0.5 + 0.3
	if _leg_a != null:
		var swing := kick * 0.5 if absf(velocity.x) > 5.0 else 0.0
		_leg_a.rotation = swing
		_leg_b.rotation = -swing
	if dead:
		visual.modulate = Color(0.62, 0.62, 0.78, 0.9)
	elif _flash_left > 0.0:
		visual.modulate = Color(1, 1, 1).lerp(Color(1, 0.2, 0.2), _flash_left / 0.25)
	elif invincible_left > 0.0:
		visual.modulate = Color(1, 1, 1, 0.55 + 0.45 * sin(_anim_t * 24.0))
	else:
		visual.modulate = Color.WHITE


func _build_visual() -> void:
	if mode == Mode.SWIM:
		_build_swim_visual()
	else:
		_build_walk_visual()


## 潜水姿态：水平，头在左、脚蹼在右。
func _build_swim_visual() -> void:
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = _ellipse(16.0, 7.0)
	body.color = Color(0.13, 0.19, 0.25)
	visual.add_child(body)

	var head := Polygon2D.new()
	head.polygon = _ellipse(7.0, 6.5)
	head.position = Vector2(-15, -2)
	head.color = Color(0.45, 0.31, 0.21)
	visual.add_child(head)

	var mask := Polygon2D.new()
	mask.polygon = PackedVector2Array([Vector2(-22, -5), Vector2(-13, -6), Vector2(-13, -1), Vector2(-22, 0)])
	mask.color = Color(0.35, 0.8, 0.85)
	visual.add_child(mask)

	var tank := Polygon2D.new()
	tank.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(4, -8), Vector2(4, -4), Vector2(-8, -4)])
	tank.color = Color(0.55, 0.58, 0.62)
	visual.add_child(tank)

	_fin_a = _make_fin(Vector2(14, -3))
	_fin_b = _make_fin(Vector2(14, 4))


func _make_fin(pivot_pos: Vector2) -> Node2D:
	var pivot := Node2D.new()
	pivot.position = pivot_pos
	var fin := Polygon2D.new()
	fin.polygon = PackedVector2Array([Vector2(0, -2), Vector2(17, 2), Vector2(0, 3)])
	fin.color = Color(0.75, 0.68, 0.3)
	pivot.add_child(fin)
	visual.add_child(pivot)
	return pivot


## 行走姿态：竖直小人。
func _build_walk_visual() -> void:
	_leg_a = _make_leg(Vector2(-3, 2))
	_leg_b = _make_leg(Vector2(3, 2))

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-6, -16), Vector2(6, -16), Vector2(7, 3), Vector2(-7, 3)])
	body.color = Color(0.16, 0.23, 0.3)
	visual.add_child(body)

	var head := Polygon2D.new()
	head.polygon = _ellipse(6.5, 7.0)
	head.position = Vector2(0, -23)
	head.color = Color(0.45, 0.31, 0.21)
	visual.add_child(head)

	var hair := Polygon2D.new()
	hair.polygon = PackedVector2Array([Vector2(-7, -25), Vector2(7, -25), Vector2(5, -30), Vector2(-5, -30)])
	hair.color = Color(0.12, 0.09, 0.07)
	visual.add_child(hair)


func _make_leg(pivot_pos: Vector2) -> Node2D:
	var pivot := Node2D.new()
	pivot.position = pivot_pos
	var leg := Polygon2D.new()
	leg.polygon = PackedVector2Array([Vector2(-2.5, 0), Vector2(2.5, 0), Vector2(2.5, 14), Vector2(-2.5, 14)])
	leg.color = Color(0.1, 0.14, 0.19)
	pivot.add_child(leg)
	visual.add_child(pivot)
	return pivot


static func _ellipse(rx: float, ry: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
