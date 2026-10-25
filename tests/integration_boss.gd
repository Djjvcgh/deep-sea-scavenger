extends SceneTree
## v0.3 战斗端到端测试：鱼叉猎鲨 → 巨影苏醒 → 触拍伤害 → 击杀掉落 → 逃离潜回。
## godot --headless -s res://tests/integration_boss.gd

var failures := 0


func _initialize() -> void:
	var watchdog := create_timer(150.0)
	watchdog.timeout.connect(func() -> void:
		printerr("[看门狗] 战斗测试超时，强制退出")
		quit(3))
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		printerr("  [通过] " + msg)
	else:
		failures += 1
		printerr("  [失败] " + msg)


func _load_underwater() -> void:
	change_scene_to_file("res://scenes/underwater.tscn")
	await process_frame
	await process_frame


func _stab(p: CharacterBody2D) -> void:
	p.try_attack()
	await create_timer(Balance.HARPOON_COOLDOWN + 0.15).timeout


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset_defaults()
	var save_path: String = root.get_node("SaveManager").save_path
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	printerr("[鱼叉猎鲨]")
	await _load_underwater()
	var uw = current_scene
	var player = uw.get_node("Player")
	player.invincible_left = 99999.0   # 免疫咬击位移：保证刺击判定确定性（不影响鲨鱼受击）

	# 打造鱼叉
	gs.materials = {"wood": 1, "iron": 2, "canvas": 0, "leather": 0}
	_check(gs.craft_harpoon() and gs.has_harpoon, "工作台打造鱼叉")
	_check(gs.materials["iron"] == 0 and gs.materials["wood"] == 0, "打造扣减材料")

	# 把一条鲨鱼拉到身边连续刺击
	var shark = get_nodes_in_group("sharks")[0]
	var hp0: int = shark.hp
	player.global_position = shark.global_position + Vector2(90, 0)
	await create_timer(0.3).timeout
	await _stab(player)
	printerr("[诊断] 攻击后: 鲨鱼hp=", shark.hp, " cd=", player._attack_cd,
		" 体力=", player.stamina, " harpoon=", gs.has_harpoon,
		" 锁=", player.control_locked, " 死=", player.dead)
	_check(shark.hp == hp0 - 1, "鱼叉刺击造成 1 点伤害")
	_check(shark.state == shark.State.FLEE, "受击后鲨鱼逃窜")
	for i in 2:
		# 追上逃窜的鲨鱼再补刀（玩家冲刺可追上）
		player.global_position = shark.global_position + Vector2(80, 0)
		await create_timer(0.25).timeout
		await _stab(player)
	_check(shark.dead, "三次刺击击杀鲨鱼")
	await create_timer(0.5).timeout
	var found_pickup := false
	for p in uw._pickups:
		if is_instance_valid(p):
			found_pickup = true
	_check(found_pickup, "鲨鱼死亡掉落皮革拾取物")

	# 拾取皮革
	var leather_before: int = gs.materials["leather"]
	for p in uw._pickups:
		if is_instance_valid(p):
			player.global_position = p.global_position
			break
	await create_timer(0.4).timeout
	_check(gs.materials["leather"] == leather_before + 1, "接触拾取皮革")
	var hp_after_fight: int = player.hp

	# ---------- 巨影 ----------
	printerr("[深渊巨影]")
	# 清场：击杀所有鲨鱼并回满状态，恢复可受伤（触拍伤害需要生效）
	player.hp = 3
	player.dead = false
	player.invincible_left = 0.0
	for s in get_nodes_in_group("sharks"):
		s.take_damage(99, s.global_position + Vector2(0, 60))
	player.global_position = Vector2(4000, 800)   # 进入区域C（巨影仅在C区活跃）
	await create_timer(0.3).timeout
	gs.add_dive_item("cursed_idol")
	_check(gs.has_curse_idol(), "携带诅咒神像")
	uw._idol_warned = true          # 跳过警告分支，直接控制苏醒倒计时
	uw._boss_awaken_left = 0.4
	await create_timer(1.0).timeout
	if uw.boss == null:
		_check(false, "巨影苏醒生成")
	else:
		_check(true, "巨影苏醒生成")
		await create_timer(3.0).timeout
		_check(uw.boss.state == uw.boss.State.ACTIVE, "巨影进入活跃状态")
		_check(uw.any_boss_active(), "HUD 判定巨影威胁")
		gs.remove_dive_item_at(0)   # 移除触发用神像，腾空背包准备接收战利品

		# 触拍伤害：站定不动必然被拍中
		var hp_before_slam: int = player.hp
		player.global_position = uw.boss.global_position + Vector2(0, -60)
		await create_timer(Balance.BOSS_SLAM_INTERVAL + Balance.BOSS_TELEGRAPH + 1.0).timeout
		_check(player.hp < hp_before_slam or player.hp <= 0, "触拍命中造成伤害")
		player.hp = 3
		player.dead = false
		player.invincible_left = 99999.0   # 免疫后续伤害：专注验证击杀掉落与拾取流程

		# 鱼叉击杀巨影（直接施加伤害模拟连续刺击）
		var boss = uw.boss
		for i in Balance.BOSS_HP:
			boss.take_damage(1, player.global_position)
		_check(boss.dead and boss.state == boss.State.SINKING, "巨影生命耗尽沉没")
		await create_timer(1.0).timeout
		var trophy = null
		for n in get_nodes_in_group("interactables"):
			if "collect_loot" in n and n.container_kind == "trophy":
				trophy = n
				break
		_check(trophy != null, "沉没处生成巨影战利品袋")
		if trophy != null:
			player.global_position = trophy.global_position + Vector2(0, -40)
			await create_timer(0.3).timeout
			Input.action_press("interact")
			await create_timer(2.5).timeout
			Input.action_release("interact")
			await create_timer(0.3).timeout
			_check(uw.loot_panel.visible, "战利品袋弹出拾取界面")
			uw.loot_panel.take_all_and_close()
			await process_frame
			var got_idol := false
			for e in gs.dive_bag:
				if e["id"] == "cursed_idol" and e["quality"] == "pristine":
					got_idol = true
			printerr("[诊断2] bag=", gs.dive_bag)
			_check(got_idol, "拾取完好品质诅咒神像")

	# ---------- 逃离区域 C：巨影潜回 ----------
	printerr("[逃离巨影]")
	await _load_underwater()
	paused = false
	var uw2 = current_scene
	var player2 = uw2.get_node("Player")
	player2.global_position = Vector2(4000, 800)   # 先进入区域C
	await create_timer(0.3).timeout
	gs.add_dive_item("cursed_idol")
	uw2._idol_warned = true
	uw2._boss_awaken_left = 0.3
	await create_timer(1.2).timeout
	if uw2.boss != null:
		_check(true, "巨影再次苏醒")
		await create_timer(2.6).timeout   # 等巨影完全活跃
		player2.global_position = Vector2(200, 480)   # 逃回浅海
		await create_timer(0.6).timeout
		_check(uw2.boss == null, "逃出区域C后巨影潜回深渊")
	else:
		_check(false, "巨影再次苏醒")

	# 清理
	paused = false
	gs.reset_defaults()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	if failures == 0:
		print("=== 战斗集成测试全部通过 ===")
	else:
		print("=== 战斗集成测试共 %d 项失败 ===" % failures)
	quit(1 if failures > 0 else 0)
