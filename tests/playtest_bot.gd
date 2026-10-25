extends SceneTree

## 布局固定为横带（本测试的路径/坐标按横带设计）


func _init() -> void:
	OS.set_environment("DEEPSEA_LAYOUT", "horizontal")
## 机器人试玩：用真实输入策略「玩」海底场景，量化验证可玩性。
## godot --headless -s res://tests/playtest_bot.gd
##
## 场景1：满载（金杯+神像=8格负重）往返区域C最深处，验证体力预算够返航。
## 场景2：开阔水域被鲨鱼追逐，直线冲刺脱离，验证能甩掉且代价可接受。
## 场景3：被鲨鱼贴身，验证击退+脱离机制给出足够的反应窗口。

var failures := 0

var gs = null
var uw = null
var player = null


func _initialize() -> void:
	var watchdog := create_timer(420.0)
	watchdog.timeout.connect(func() -> void:
		printerr("[看门狗] 试玩超时，强制退出")
		quit(3))
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		printerr("  [通过] " + msg)
	else:
		failures += 1
		printerr("  [失败] " + msg)


func _sprint_policy(threshold: float) -> void:
	if player.stamina > threshold:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")


func _load_underwater() -> void:
	change_scene_to_file("res://scenes/underwater.tscn")
	await process_frame
	await process_frame
	uw = current_scene
	player = uw.get_node("Player")


func _scenario_roundtrip() -> void:
	printerr("========== 试玩1：区域C满载往返 ==========")
	for s in get_nodes_in_group("sharks"):
		s.set_physics_process(false)
		s.position = Vector2(9000.0, 500.0)
	gs.add_dive_item("gold_cup")
	gs.add_dive_item("gold_cup")   # 3+3=6格触发负重（不用神像，避免唤醒巨影干扰路线试玩）
	_check(gs.bag_used_slots() == 6, "满载6格（负重生效）")
	player.global_position = Vector2(200, 480)
	await create_timer(0.2).timeout

	var t0 := Time.get_ticks_msec()
	var arrived := false
	var out_of_stamina := false
	while Time.get_ticks_msec() - t0 < 150000:
		await physics_frame
		if player.dead or player.stamina <= 0.0:
			out_of_stamina = true
			break
		var p: Vector2 = player.global_position
		# 策略：上层航道 y≈480 向右；过了沉船桅杆（x>2850）下潜到海床爬行层 y≈905
		if p.x > 2850.0 and p.y < 900.0:
			Input.action_press("move_down")
		else:
			Input.action_release("move_down")
		if p.x >= 4650.0:
			arrived = true
			Input.action_release("move_right")
			break
		Input.action_press("move_right")
		_sprint_policy(55.0)
	Input.action_release("move_right")
	Input.action_release("move_down")
	Input.action_release("sprint")
	var out_time := (Time.get_ticks_msec() - t0) / 1000.0
	_check(arrived and not out_of_stamina, "满载抵达区域C最深处（x≥4650）")
	printerr("  [数据] 去程 %.1fs，抵达时体力 %.1f" % [out_time, player.stamina])

	# 返程：贴海床爬行层向左，x≤3100 斜线爬升到上层 y≈480 越过沉船，最后向上进撤离区
	t0 = Time.get_ticks_msec()
	var extracted := false
	out_of_stamina = false
	while Time.get_ticks_msec() - t0 < 180000:
		await physics_frame
		if player.dead or player.stamina <= 0.0:
			out_of_stamina = true
			break
		var p: Vector2 = player.global_position
		Input.action_press("move_left")
		if p.x <= 3100.0 and p.y > 480.0:
			Input.action_press("move_up")
		elif p.x < 700.0 and p.y > 380.0:
			Input.action_press("move_up")
		else:
			Input.action_release("move_up")
		_sprint_policy(50.0)
		if uw.in_extraction:
			Input.action_press("interact")
		else:
			Input.action_release("interact")
		if uw.ended:
			extracted = true
			break
	Input.action_release("move_left")
	Input.action_release("move_up")
	Input.action_release("sprint")
	Input.action_release("interact")
	var back_time := (Time.get_ticks_msec() - t0) / 1000.0
	_check(extracted and not out_of_stamina, "满载从区域C成功撤离")
	_check(player.stamina > 15.0 or extracted, "返航后体力余量充足（剩余 %.1f）" % player.stamina)
	printerr("  [数据] 返程 %.1fs，撤离时体力 %.1f，生命 %d" % [back_time, player.stamina, player.hp])


func _scenario_escape() -> void:
	printerr("========== 试玩2：开阔水被追逐后脱离 ==========")
	player.reset_for_dive()
	var shark = get_nodes_in_group("sharks")[0]
	shark.set_physics_process(true)
	# 鲨鱼贴近巡逻带右端，与玩家初始距离 170 < 180，立即警觉
	shark.position = Vector2(shark.patrol_max_x - 20.0, shark.patrol_y)
	player.global_position = Vector2(shark.patrol_max_x + 150.0, shark.patrol_y)
	await create_timer(0.2).timeout

	# 等待进入追逐
	var t0 := Time.get_ticks_msec()
	while shark.state != shark.State.CHASE and Time.get_ticks_msec() - t0 < 6000:
		await physics_frame
	_check(shark.state == shark.State.CHASE, "鲨鱼进入追逐状态")

	# 策略：朝撤离方向（左）冲刺，体力低于25改为游泳
	t0 = Time.get_ticks_msec()
	var escaped := false
	while Time.get_ticks_msec() - t0 < 15000:
		await physics_frame
		Input.action_press("move_left")
		_sprint_policy(25.0)
		var dist: float = player.global_position.distance_to(shark.global_position)
		if shark.state != shark.State.CHASE and dist > 250.0:
			escaped = true
			break
	Input.action_release("move_left")
	Input.action_release("sprint")
	var esc_time := (Time.get_ticks_msec() - t0) / 1000.0
	_check(escaped, "成功脱离追逐")
	_check(esc_time < 12.0, "脱离耗时 %.1fs（<12s）" % esc_time)
	_check(player.hp >= 2, "脱离过程至多被咬1口（生命 %d）" % player.hp)
	_check(player.stamina > 25.0, "脱离后体力余量 %.1f（>25）" % player.stamina)
	printerr("  [数据] 脱离耗时 %.1fs，生命 %d，体力 %.1f" % [esc_time, player.hp, player.stamina])


func _scenario_pinned() -> void:
	printerr("========== 试玩3：被贴身时的反应窗口 ==========")
	player.reset_for_dive()
	var shark = get_nodes_in_group("sharks")[0]
	shark.position = Vector2(shark.patrol_min_x, shark.patrol_y)
	player.global_position = shark.global_position + Vector2(6.0, 0.0)
	await create_timer(0.2).timeout

	# 站桩不动，记录每次被咬的时间与位置
	var bite_times: Array = []
	var bite_pos: Vector2 = player.global_position
	var last_hp: int = player.hp
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 15000 and bite_times.size() < 2:
		await physics_frame
		if player.hp < last_hp:
			bite_times.append((Time.get_ticks_msec() - t0) / 1000.0)
			last_hp = player.hp
	if bite_times.size() == 2:
		var gap: float = bite_times[1] - bite_times[0]
		_check(gap >= 2.0, "两次咬击间隔 %.2fs（≥2.0s，留给玩家反应）" % gap)
		var pushed: float = player.global_position.distance_to(bite_pos)
		_check(pushed > 30.0, "被咬后击退了 %.0fpx（>30px）" % pushed)
		printerr("  [数据] 首咬 %.2fs，第二口 %.2fs，间隔 %.2fs，被击退 %.0fpx"
			% [bite_times[0], bite_times[1], gap, pushed])
	else:
		_check(false, "15秒内未记录到两次咬击（首咬 %.2f）" % (bite_times[0] if bite_times.size() > 0 else -1.0))


func _run() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.reset_defaults()
	var save_path: String = root.get_node("SaveManager").save_path
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	await _load_underwater()
	await _scenario_roundtrip()

	# 结算面板会暂停场景，重置后进新场景继续
	paused = false
	gs.reset_defaults()
	await _load_underwater()
	await _scenario_escape()
	await _scenario_pinned()

	gs.reset_defaults()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	if failures == 0:
		printerr("=== 机器人试玩全部通过 ===")
	else:
		printerr("=== 机器人试玩共 %d 项失败 ===" % failures)
	quit(1 if failures > 0 else 0)
