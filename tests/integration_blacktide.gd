extends SceneTree
## V0.5 黑潮号残骸关卡集成测试。
## godot --headless -s res://tests/integration_blacktide.gd
## 校验：双路线可走通、隐藏密室可进入、船长金库可获取、背包限制生效、
## 鲨鱼视线掩体、返航捷径缩短路程、成功/失败结算、全局状态还原（存档保护）。

var failures := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [通过] " + msg)
	else:
		failures += 1
		print("  [失败] " + msg)


static func _lane_clear(uw, pts: Array, radius := 30.0) -> bool:
	var solids: Array = uw.all_solids()
	for p in pts:
		if not MapData.circle_clear(p, radius, solids):
			print("    阻塞点：%s" % p)
			return false
	return true


static func _polyline_len(pts: Array) -> float:
	var total := 0.0
	for i in range(1, pts.size()):
		total += (pts[i] - pts[i - 1]).length()
	return total


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset_defaults()
	var save_path: String = root.get_node("SaveManager").save_path
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	change_scene_to_file("res://scenes/level_blacktide.tscn")
	await process_frame
	await process_frame
	var uw = current_scene
	var player = uw.get_node("Player")

	# ---------- 关卡加载 ----------
	print("[关卡加载]")
	_check(uw.name == "BlacktideLevel", "黑潮号关卡加载")
	_check(player != null and not player.dead, "玩家就位（%s）" % player.global_position)
	_check(not uw.EXTRACT_RECT.has_point(player.global_position), "出生点不在撤离区内")
	_check(uw.get_zone_label() != "", "区域标签接口工作（%s）" % uw.get_zone_label())
	_check(uw._sharks.size() == 3, "甲板 3 条鲨鱼巡逻")

	# ---------- 路线：船底（安全） ----------
	print("[路线一：船底破口（安全）]")
	var safe_lane: Array = [Vector2(240, 420), Vector2(660, 900), Vector2(860, 940),
		Vector2(930, 950),
		Vector2(1180, 780), Vector2(1650, 740), Vector2(2130, 985), Vector2(2300, 900),
		Vector2(2520, 740), Vector2(2800, 860), Vector2(2890, 665), Vector2(3015, 700),
		Vector2(3015, 900), Vector2(3130, 990)]
	_check(_lane_clear(uw, safe_lane), "撤离点→破口→货舱→轮机舱→舱壁顶门→船长货舱全程畅通")

	# ---------- 路线：甲板（危险） ----------
	print("[路线二：上层甲板（危险）]")
	var deck_lane: Array = [Vector2(240, 420), Vector2(600, 300), Vector2(1000, 430), Vector2(1640, 380),
		Vector2(2200, 430), Vector2(2450, 420), Vector2(2612, 285), Vector2(2900, 420),
		Vector2(3120, 520), Vector2(3015, 700), Vector2(3015, 900)]
	_check(_lane_clear(uw, deck_lane), "水面→甲板（掩体间穿行）→桅杆断口→直落船长货舱全程畅通")
	_check(_polyline_len(deck_lane) < _polyline_len(safe_lane),
		"甲板路线更短（%.0f < %.0f）" % [_polyline_len(deck_lane), _polyline_len(safe_lane)])

	# ---------- 龙骨夹层：捷径 ----------
	print("[返航捷径：龙骨夹层]")
	_check(not MapData.circle_clear(Vector2(2100, 1110), 30.0, uw.all_solids()),
		"解锁前坍塌封死夹层")
	_check(not MapData.circle_clear(Vector2(3010, 1090), 30.0, uw.all_solids()),
		"解锁前龙骨活门关闭")
	player.global_position = Vector2(3185, 985)
	player.velocity = Vector2.ZERO
	await create_timer(0.3).timeout
	_check(player.focus_target != null and player.focus_target.prompt_text == "应急绞盘",
		"靠近后聚焦应急绞盘")
	Input.action_press("interact")
	await create_timer(0.2).timeout
	Input.action_release("interact")
	await create_timer(0.3).timeout
	_check(uw.shortcut_open, "摇动绞盘打开捷径")
	var crawl_lane: Array = [Vector2(3015, 1090), Vector2(2800, 1110), Vector2(2400, 1110),
		Vector2(2100, 1110), Vector2(1700, 1110), Vector2(1060, 1110), Vector2(1060, 960)]
	_check(_lane_clear(uw, crawl_lane), "船长货舱→夹层→前货舱船底口爬行道畅通")

	# 捷径缩短返程：对比两条返航折线
	var rooms_return: Array = [Vector2(3130, 985), Vector2(3015, 900), Vector2(3015, 700),
		Vector2(2890, 665), Vector2(2800, 860), Vector2(2520, 740), Vector2(2300, 900),
		Vector2(2130, 985), Vector2(1650, 740), Vector2(1180, 780), Vector2(930, 950),
		Vector2(660, 900), Vector2(240, 420), Vector2(190, 230)]
	var shortcut_return: Array = [Vector2(3130, 985), Vector2(3015, 1035), Vector2(3015, 1110),
		Vector2(1060, 1110), Vector2(1060, 960), Vector2(930, 950),
		Vector2(660, 900), Vector2(240, 420), Vector2(190, 230)]
	_check(_lane_clear(uw, shortcut_return), "捷径返航折线全程畅通")
	_check(_polyline_len(shortcut_return) < _polyline_len(rooms_return) - 300.0,
		"捷径返航更短（%.0f < %.0f - 300）" % [_polyline_len(shortcut_return), _polyline_len(rooms_return)])

	# ---------- 船长金库与背包限制 ----------
	print("[船长金库与背包]")
	var vault = null
	for n in get_nodes_in_group("interactables"):
		if "container_kind" in n and n.container_name == "船长金库":
			vault = n
			break
	_check(vault != null, "船长金库存在")
	if vault != null:
		var loot: Array = vault.collect_loot()
		var has_sextant := false
		var has_cup := false
		for e in loot:
			has_sextant = has_sextant or (e["id"] == "gold_sextant" and e["quality"] == "pristine")
			has_cup = has_cup or (e["id"] == "gold_cup" and e["quality"] == "fine")
		_check(has_sextant and has_cup, "金库开出完美六分仪 + 精良金杯（6 格重型宝物）")
	gs.dive_bag = []
	for i in 3:
		gs.dive_bag.append({"id": "silver_platter", "quality": "standard"})
	_check(not gs.can_carry(3) and gs.can_carry(2),
		"背包 6/8 时装不下 3 格六分仪、装得下 2 格物品")

	# ---------- 隐藏密室 ----------
	print("[隐藏密室]")
	_check(not MapData.circle_clear(Vector2(3270, 930), 30.0, uw.all_solids()), "解锁前暗门封死")
	player.global_position = Vector2(3225, 935)
	player.velocity = Vector2.ZERO
	await create_timer(0.3).timeout
	_check(player.focus_target != null and player.focus_target.prompt_text == "船尾神龛",
		"靠近后聚焦船尾神龛")
	Input.action_press("interact")
	await create_timer(0.2).timeout
	Input.action_release("interact")
	await create_timer(0.3).timeout
	_check(uw.secret_open, "神龛推开暗门")
	_check(MapData.circle_clear(Vector2(3270, 930), 30.0, uw.all_solids()), "暗门通道打开")
	var relic = null
	for n in get_nodes_in_group("interactables"):
		if "container_kind" in n and n.container_name == "密室圣龛":
			relic = n
			break
	_check(relic != null, "密室圣龛可到达")
	if relic != null:
		var relic_loot: Array = relic.collect_loot()
		_check(relic_loot.size() == 1 and relic_loot[0]["id"] == "figurehead_blacktide",
			"密室藏独特遗物：黑潮号船首像")
		gs.dive_bag = []
		_check(gs.add_dive_item("figurehead_blacktide", "pristine"),
			"船首像（4 格）可入背包")

	# ---------- 货舱木箱开箱（长按搜索 → 拾取面板） ----------
	print("[搜刮流程]")
	var crate_chest = null
	for n in get_nodes_in_group("interactables"):
		if "container_kind" in n and n.container_name == "货舱木箱":
			crate_chest = n
			break
	if crate_chest != null:
		gs.dive_bag = []
		player.invincible_left = 99999.0
		player.global_position = crate_chest.global_position + Vector2(0, -4)
		player.velocity = Vector2.ZERO
		await create_timer(0.4).timeout
		Input.action_press("interact")
		await create_timer(3.2).timeout
		Input.action_release("interact")
		await create_timer(0.3).timeout
		_check(crate_chest.looted, "长按搜索完成开箱")
		_check(uw.loot_panel.visible, "弹出拾取界面")
		uw.loot_panel.take_all_and_close()
		await process_frame
		_check(gs.dive_bag.size() >= 1, "战利品进入背包（%d 件）" % gs.dive_bag.size())
	else:
		_check(false, "找到货舱木箱")

	# ---------- 鲨鱼视线掩体 ----------
	print("[鲨鱼视线与掩体]")
	for s in get_nodes_in_group("sharks"):
		s.take_damage(99, s.global_position + Vector2(0, 60))   # 只留一条
	var shark = null
	for s in get_nodes_in_group("sharks"):
		if not s.dead:
			shark = s
	if shark == null:
		shark = uw._sharks[0]
		shark.hp = 3
	# 断桅两侧：视线被桅杆截断
	shark.setup(2500.0, 2560.0, 430.0, player)
	shark.global_position = Vector2(2540, 430)
	player.global_position = Vector2(2680, 430)
	player.velocity = Vector2.ZERO
	await create_timer(0.4).timeout
	_check(shark._see_player() == false, "断桅阻断鲨鱼视线")
	var hp_before: int = player.hp
	await create_timer(1.6).timeout
	_check(player.hp == hp_before, "掩体后未被咬")
	# 开阔水域恢复视线
	player.global_position = Vector2(600, 600)
	shark.global_position = Vector2(600, 440)
	shark.setup(400.0, 800.0, 440.0, player)
	shark.velocity = Vector2.ZERO
	await create_timer(1.4).timeout
	_check(shark._see_player(), "开阔水域鲨鱼恢复视线锁定")

	# ---------- 海面换气 ----------
	player.global_position = Vector2(600, 55)
	player.velocity = Vector2.ZERO
	player.stamina = 50.0
	await create_timer(1.2).timeout
	_check(player.breathing, "贴近海面进入换气")
	_check(player.stamina > 56.0, "换气恢复体力（%.1f）" % player.stamina)

	# ---------- 撤离成功结算 ----------
	print("[撤离成功结算]")
	gs.dive_bag = [{"id": "pearl", "quality": "fine"}]
	player.global_position = uw.EXTRACT_RECT.get_center()
	player.velocity = Vector2.ZERO
	await create_timer(0.4).timeout
	_check(uw.in_extraction, "进入撤离区触发撤离提示")
	Input.action_press("interact")
	await create_timer(0.3).timeout
	Input.action_release("interact")
	await create_timer(0.3).timeout
	_check(uw.ended and uw.results_panel.visible, "按 E 撤离成功，弹出结算")
	_check(gs.island_stock.size() == 1, "战利品转入岛上库存")
	paused = false

	# ---------- 撤离失败结算 ----------
	print("[撤离失败结算]")
	change_scene_to_file("res://scenes/level_blacktide.tscn")
	await process_frame
	await process_frame
	uw = current_scene
	player = uw.get_node("Player")
	gs.dive_bag = [{"id": "gold_cup", "quality": "standard"}]
	player.stamina = 0.05
	await create_timer(2.2).timeout
	_check(uw.ended and uw.results_panel.visible, "体力耗尽弹出失败结算")
	_check(gs.lost_cache.has("items") and not (gs.lost_cache["items"] as Array).is_empty(),
		"失败掉落进入遗落物缓存（可找回）")
	paused = false

	# ---------- 存档保护：离开关卡后全局状态还原 ----------
	print("[存档保护]")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	_check(gs.island_stock.is_empty(), "离开关卡后岛上库存还原")
	_check(gs.lost_cache.is_empty(), "遗落物缓存还原")
	_check(gs.bag_tier == 0 and not gs.has_harpoon, "背包档位/鱼叉还原")

	if failures == 0:
		print("=== 黑潮号关卡集成测试全部通过 ===")
	else:
		print("=== 黑潮号关卡集成测试共 %d 项失败 ===" % failures)
	quit(1 if failures > 0 else 0)
