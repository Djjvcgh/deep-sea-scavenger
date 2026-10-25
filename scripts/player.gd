extends CharacterBody2D
## 玩家：水下游泳（SWIM）/ 荒岛行走（WALK）两种模式。
## 负责移动、体力、生命、交互（长按搜索宝箱 / 按键触发交互点）与视觉反馈。

signal hp_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal hurt
signal died
signal exhausted
signal notice(text: String, color: Color)
signal loot_collected(entries: Array, container: Area2D)

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
var breathing := false            # 正在开放海面换气（停耗+恢复）
var control_locked := false        # 搜索宝箱时锁定移动
var focus_target: Area2D = null    # 当前可交互目标（供 HUD 显示提示）
var active_chest: Area2D = null    # 正在搜索的宝箱

var _anim_t := 0.0
var _flash_left := 0.0
var _attack_cd := 0.0
var _shake_left := 0.0

@onready var interact_area: Area2D = $InteractRange
@onready var camera: Camera2D = $Camera2D
@onready var visual: Node2D = $Visual

var _fin_a: Node2D
var _fin_b: Node2D
var _leg_a: Node2D
var _leg_b: Node2D

## V0.5 纠偏：默认相机缩放。1.0 时角色过小、危险预判距离过剩；
## 经 1.3/1.5/1.7 对比（见 docs/art_direction/screens/zoom/）取 1.5。
const CAM_ZOOM := 1.5


func _ready() -> void:
	max_hp = BalanceRes.MAX_HP
	hp = max_hp
	max_stamina = GameState.max_stamina()
	stamina = max_stamina
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING if mode == Mode.SWIM \
		else CharacterBody2D.MOTION_MODE_GROUNDED
	camera.zoom = Vector2.ONE * CAM_ZOOM
	_build_visual()
	if mode == Mode.SWIM:
		_add_dive_light()


## 潜水灯：配合区域C的黑暗（CanvasModulate），能见度即风险。
func _add_dive_light() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color.WHITE, Color(0.55, 0.55, 0.55), Color.BLACK])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var light := PointLight2D.new()
	light.texture = tex
	light.texture_scale = 2.6
	light.energy = 1.15
	light.color = Color(0.8, 0.88, 1.0)
	light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(light)


func _physics_process(delta: float) -> void:
	_anim_t += delta
	invincible_left = maxf(0.0, invincible_left - delta)
	_flash_left = maxf(0.0, _flash_left - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 9.0 * (_shake_left / 0.25)
	else:
		camera.offset = Vector2.ZERO
	_animate()
	if dead:
		velocity = velocity.move_toward(Vector2(0, -26), 200.0 * delta)
		move_and_slide()
		return
	if mode == Mode.SWIM:
		_swim(delta)
		_update_attack()
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
	# 海面换气：贴近开放水面（上方与天空相通）时停止消耗并恢复体力
	breathing = global_position.y <= BalanceRes.BREATH_DEPTH and _sky_above()
	if breathing:
		stamina = minf(max_stamina, stamina + BalanceRes.SURFACE_REGEN * delta)
		stamina_changed.emit(stamina, max_stamina)
		return
	# 体力消耗（搜索期间按游泳消耗计）
	var drain := BalanceRes.DRAIN_IDLE
	if sprinting:
		drain = BalanceRes.DRAIN_SPRINT
	elif control_locked:
		drain = BalanceRes.DRAIN_SEARCH
	elif dir != Vector2.ZERO:
		drain = BalanceRes.DRAIN_SWIM
	_drain_stamina(drain * GameState.weight_drain_mult() * delta)


## 上方直到天空之间是否有实体遮挡（洞穴顶盖 / 岩层 / 沉船甲板下方不算海面）。
func _sky_above() -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, Vector2(global_position.x, BalanceRes.SURFACE_Y - 300.0), 1)
	return space.intersect_ray(query).is_empty()


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
			and focus_target.has_method("begin_search") and not focus_target.looted:
		active_chest = focus_target
		active_chest.begin_search()
		control_locked = true

	if active_chest == null and not control_locked and focus_target != null \
			and Input.is_action_just_pressed("interact"):
		# 已打开且仍有剩余的容器：按 E 重新打开取物
		if focus_target.has_method("begin_search") and focus_target.looted \
				and focus_target.is_available():
			var entries: Array = focus_target.collect_loot()
			if not entries.is_empty():
				control_locked = true
				loot_collected.emit(entries, focus_target)
		elif focus_target.has_method("interact"):
			focus_target.interact(self)


func _cancel_search() -> void:
	if active_chest != null and is_instance_valid(active_chest):
		active_chest.cancel_search()
	active_chest = null
	control_locked = false


## 搜索完成：容器生成掉落并弹出拾取面板；面板关闭前保持移动锁定。
func _complete_loot() -> void:
	var chest := active_chest
	active_chest = null
	if chest == null or not is_instance_valid(chest):
		control_locked = false
		return
	var entries: Array = chest.collect_loot()
	if entries.is_empty():
		control_locked = false
		return
	loot_collected.emit(entries, chest)




func is_searching() -> bool:
	return active_chest != null


# ---------------- 鱼叉刺击 ----------------

func shake(strength := 0.25) -> void:
	_shake_left = strength


## 空格刺击：自动瞄准 150px 内最近的敌人，无目标则朝面朝方向。
func _update_attack() -> void:
	if Input.is_action_just_pressed("attack"):
		try_attack()


## 执行一次刺击（输入层与测试共用的入口）；返回是否真正出手。
func try_attack() -> bool:
	if dead or control_locked or not GameState.has_harpoon:
		return false
	if _attack_cd > 0.0 or stamina < BalanceRes.HARPOON_STAMINA:
		return false
	_attack_cd = BalanceRes.HARPOON_COOLDOWN
	_drain_stamina(BalanceRes.HARPOON_STAMINA)

	var aim_dir := Vector2.RIGHT * visual.scale.x
	var best_d := BalanceRes.HARPOON_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.get("dead"):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			aim_dir = (e.global_position - global_position).normalized()

	var hit_point := global_position + aim_dir * BalanceRes.HARPOON_REACH
	# 沿刺击线段的胶囊判定：敌人中心到线段距离 ≤ 其判定半径即命中
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.get("dead"):
			continue
		var to_e: Vector2 = e.global_position - global_position
		var along := clampf(to_e.dot(aim_dir), 0.0, BalanceRes.HARPOON_REACH)
		var closest := global_position + aim_dir * along
		if e.global_position.distance_to(closest) <= e.hit_radius:
			e.take_damage(BalanceRes.HARPOON_DAMAGE, global_position)

	velocity += aim_dir * 90.0
	_spawn_stab_visual(aim_dir, hit_point)
	Sfx.play("stab")
	return true


func _spawn_stab_visual(aim_dir: Vector2, hit_point: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([
		global_position + aim_dir * 14.0,
		global_position.lerp(hit_point, 0.6) + aim_dir * 20.0])
	line.width = 3.5
	line.default_color = Color(0.85, 0.88, 0.95, 0.9)
	line.z_index = 6
	get_parent().add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.16)
	tw.tween_callback(line.queue_free)


# ---------------- 生命与伤害 ----------------

func take_damage(amount: int, from_pos: Variant = null) -> void:
	if dead or invincible_left > 0.0:
		return
	hp = maxi(0, hp - amount)
	invincible_left = BalanceRes.INVINCIBLE_TIME
	_flash_left = 0.25
	_cancel_search()
	# 被咬击退：制造脱身动量
	if from_pos != null:
		var away: Vector2 = (global_position - from_pos).normalized()
		if away.length_squared() > 0.0001:
			velocity = away * BalanceRes.BITE_KNOCKBACK
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
	breathing = false
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
	if mode == Mode.SWIM:
		# 镜像到水平朝向；倾角补偿镜像（面朝 -x 时角度差 PI），任何方向都头朝前
		if absf(velocity.x) > 5.0:
			visual.scale.x = signf(velocity.x)
		var target_rot := 0.0
		if speed > 12.0:
			target_rot = velocity.angle() if visual.scale.x > 0.0 else velocity.angle() - PI
		visual.rotation = lerp_angle(visual.rotation, target_rot, 8.0 * get_physics_process_delta_time())
	elif mode == Mode.WALK:
		visual.rotation = 0.0
		if absf(velocity.x) > 5.0:
			visual.scale.x = signf(velocity.x)
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


## 潜水姿态：水平，头在右（面朝 +x）、脚蹼在左；
## 游动时镜像到水平朝向并按速度倾角旋转，保证任何方向都是头朝前。
func _build_swim_visual() -> void:
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = _ellipse(16.0, 7.0)
	body.color = Color(0.13, 0.19, 0.25)
	visual.add_child(body)

	var head := Polygon2D.new()
	head.polygon = _ellipse(7.0, 6.5)
	head.position = Vector2(15, -2)
	head.color = Color(0.45, 0.31, 0.21)
	visual.add_child(head)

	var mask := Polygon2D.new()
	mask.polygon = PackedVector2Array([Vector2(13, -6), Vector2(22, -5), Vector2(22, 0), Vector2(13, -1)])
	mask.color = Color(0.35, 0.8, 0.85)
	visual.add_child(mask)

	var tank := Polygon2D.new()
	tank.polygon = PackedVector2Array([Vector2(-4, -8), Vector2(8, -8), Vector2(8, -4), Vector2(-4, -4)])
	tank.color = Color(0.55, 0.58, 0.62)
	visual.add_child(tank)

	_fin_a = _make_fin(Vector2(-14, -3))
	_fin_b = _make_fin(Vector2(-14, 4))


func _make_fin(pivot_pos: Vector2) -> Node2D:
	var pivot := Node2D.new()
	pivot.position = pivot_pos
	var fin := Polygon2D.new()
	fin.polygon = PackedVector2Array([Vector2(0, -2), Vector2(-17, 2), Vector2(0, 3)])
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
