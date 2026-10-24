extends SceneTree
## 自动化检查入口：godot --headless -s res://tests/run_tests.gd
## 每个测试函数返回失败数，最后以退出码报告结果。

var failures := 0


func _initialize() -> void:
	print("=== 深海摸金 自动化检查 ===")
	_ensure_autoloads()
	failures += _test_scripts_parse()
	failures += _test_item_db()
	failures += _test_balance()
	failures += _test_game_state()
	failures += _test_save_roundtrip()
	failures += _test_map_data()
	_print_result()
	quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [通过] " + msg)
	else:
		failures += 1
		print("  [失败] " + msg)


func _print_result() -> void:
	if failures == 0:
		print("=== 全部通过 ===")
	else:
		print("=== 共 %d 项失败 ===" % failures)


## -s 脚本模式下 autoload 可能未注册，手动补齐，保证场景可实例化。
func _ensure_autoloads() -> void:
	var names := {"GameState": "game_state.gd", "SaveManager": "save_manager.gd", "Sfx": "sfx.gd"}
	for n in names:
		if not root.has_node(n):
			var node: Node = (load("res://scripts/" + names[n])).new()
			node.name = n
			root.add_child(node)


func _test_scripts_parse() -> int:
	print("[脚本解析]")
	var bad := 0
	for path in _list_scripts("res://scripts"):
		var s = load(path)
		if s == null or not s.can_instantiate():
			print("  [失败] 无法加载 " + path)
			bad += 1
	_check(bad == 0, "scripts/ 下所有 GDScript 可解析加载")
	return bad


func _list_scripts(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var p := dir_path + "/" + f
		if dir.current_is_dir():
			out.append_array(_list_scripts(p))
		elif f.ends_with(".gd"):
			out.append(p)
		f = dir.get_next()
	return out


func _test_item_db() -> int:
	print("[数据表]")
	var T = ItemDB.TREASURES
	_check(T["bronze_coins"]["value"] == 25 and T["bronze_coins"]["slots"] == 1
		and is_equal_approx(T["bronze_coins"]["search_time"], 1.5), "古铜币包 25/1格/1.5s")
	_check(T["silver_platter"]["value"] == 70 and T["silver_platter"]["slots"] == 2
		and is_equal_approx(T["silver_platter"]["search_time"], 3.0), "银质餐盘 70/2格/3s")
	_check(T["gold_cup"]["value"] == 140 and T["gold_cup"]["slots"] == 3
		and is_equal_approx(T["gold_cup"]["search_time"], 5.0), "沉船金杯 140/3格/5s")
	_check(T["cursed_idol"]["value"] == 280 and T["cursed_idol"]["slots"] == 5
		and is_equal_approx(T["cursed_idol"]["search_time"], 7.0), "诅咒神像 280/5格/7s")
	_check(ItemDB.MATERIALS["wood"]["price"] == 100
		and ItemDB.MATERIALS["iron"]["price"] == 180
		and ItemDB.MATERIALS["canvas"]["price"] == 160, "物资价格 100/180/160")
	_check(ItemDB.UPGRADES["bag"]["cost"] == 180
		and ItemDB.UPGRADES["fins"]["cost"] == 160
		and ItemDB.UPGRADES["amulet"]["cost"] == 220, "升级费用 180/160/220")
	_check(ItemDB.BOAT_REQUIREMENT["wood"] == 2 and ItemDB.BOAT_REQUIREMENT["iron"] == 1
		and ItemDB.BOAT_REQUIREMENT["canvas"] == 1, "造船需求 木2/铁1/帆1")
	# 各区域权重合计为1
	for zone in ItemDB.ZONE_WEIGHTS:
		var total := 0.0
		for id in ItemDB.ZONE_WEIGHTS[zone]:
			_check_quiet(T.has(id), "区域%s权重引用的宝物 %s 存在" % [zone, id])
			total += ItemDB.ZONE_WEIGHTS[zone][id]
		_check(is_equal_approx(total, 1.0), "区域%s 权重合计=1" % zone)
	return 0


var quiet_fail := 0
func _check_quiet(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		quiet_fail += 1
		print("  [失败] " + msg)


func _test_balance() -> int:
	print("[数值配置]")
	_check(Balance.SPRINT_SPEED > Balance.SWIM_SPEED, "冲刺速度大于游泳速度")
	_check(Balance.DRAIN_SPRINT > Balance.DRAIN_SWIM
		and Balance.DRAIN_SWIM > Balance.DRAIN_IDLE, "体力消耗：冲刺>游泳>停留")
	_check(is_equal_approx(Balance.SHARK_DETECT_RANGE * Balance.SHARK_DETECT_CURSE_MULT, 270.0),
		"诅咒感知范围 = 270")
	_check(Balance.MAX_HP == 3 and Balance.INVINCIBLE_TIME == 2.0, "生命3 / 无敌2秒")
	return 0


func _test_game_state() -> int:
	print("[全局状态]")
	var gs = root.get_node("GameState")
	gs.reset_defaults()

	# 背包容量
	_check(gs.bag_capacity() == 8, "默认背包8格")
	gs.upgrades["bag"] = true
	_check(gs.bag_capacity() == 12, "扩容后背包12格")
	gs.upgrades["bag"] = false

	# 拾取与容量
	_check(gs.add_dive_item("gold_cup"), "可以拾取金杯(3格)")
	_check(gs.add_dive_item("gold_cup"), "第二个金杯(共6格)")
	_check(not gs.add_dive_item("gold_cup"), "8格装不下第三个金杯")
	_check(gs.bag_used_slots() == 6, "占用6格")
	_check(is_equal_approx(gs.weight_speed_mult(), 0.9), "负重速度×0.9")
	_check(is_equal_approx(gs.weight_drain_mult(), 1.2), "负重消耗×1.2")
	_check(gs.remove_dive_item("gold_cup"), "丢弃金杯成功")
	_check(gs.bag_used_slots() == 3 and not is_equal_approx(gs.weight_speed_mult(), 0.9),
		"丢弃后负重解除")
	_check(gs.add_dive_item("cursed_idol"), "拾取诅咒神像(5格,共8格)")
	_check(gs.has_curse_idol(), "神像诅咒生效")
	_check(gs.remove_dive_item("cursed_idol"), "丢弃神像成功")
	_check(not gs.has_curse_idol(), "丢弃后诅咒解除")
	_check(not gs.add_dive_item("not_exist"), "无效宝物id被拒绝")
	_check(is_equal_approx(gs.dive_total_value(), 140.0), "临时背包估值 = 140")

	# 升级
	gs.credits = 170
	_check(not gs.buy_upgrade("bag"), "额度不足(170<180)不能购买升级")
	gs.credits = 200
	_check(gs.buy_upgrade("bag"), "购买扩容背包")
	_check(not gs.buy_upgrade("bag"), "已升级不能重复购买")
	_check(gs.credits == 20, "扣费正确 200-180=20")
	_check(is_equal_approx(gs.max_stamina(), 100.0), "护符未买时体力上限100")
	gs.upgrades = {"bag": false, "fins": false, "amulet": false}

	# 交易
	gs.credits = 0
	gs.island_stock = ["bronze_coins", "bronze_coins", "silver_platter"]
	_check(not gs.sell_one("gold_cup"), "库存没有该宝物时不能出售")
	_check(gs.sell_one("bronze_coins") and gs.credits == 25, "出售1件+25")
	_check(gs.sell_all_of("bronze_coins") == 1 and gs.credits == 50, "全部出售剩余铜币+25")
	_check(gs.sell_all_of("bronze_coins") == 0, "无库存时出售返回0")
	_check(not gs.buy_material("wood"), "额度不足不能购买木材")
	gs.credits = 100
	_check(gs.buy_material("wood") and gs.materials["wood"] == 1 and gs.credits == 0,
		"购买木材扣费100")
	_check(gs.credits >= 0, "交易额度永不为负")

	# 造船
	gs.materials = {"wood": 3, "iron": 1, "canvas": 1}
	_check(gs.invest_material("wood", 5) == 2, "投入木材最多按需求2")
	_check(gs.invest_material("iron", 1) == 1 and gs.invest_material("canvas", 1) == 1,
		"投入铁件与帆布")
	_check(gs.boat_completed, "材料齐全后造船完成")
	_check(is_equal_approx(gs.boat_progress(), 1.0), "造船进度=1")
	_check(gs.invest_material("wood", 1) == 0, "造船完成后不能再投入")

	# 下潜结算
	gs.reset_defaults()
	gs.island_stock = []
	gs.add_dive_item("bronze_coins")
	gs.end_dive(false)
	_check(gs.island_stock.is_empty() and gs.dive_bag.is_empty(), "失败丢失全部临时宝物")
	gs.add_dive_item("silver_platter")
	gs.end_dive(true)
	_check(gs.island_stock == ["silver_platter"], "成功撤离宝物转入岛上库存")
	return 0


func _test_save_roundtrip() -> int:
	print("[存档]")
	var gs = root.get_node("GameState")
	var sm = root.get_node("SaveManager")
	sm.set("SAVE_PATH", "user://test_save.json")
	if FileAccess.file_exists(sm.get("SAVE_PATH")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sm.get("SAVE_PATH")))

	_check(sm.load_game().is_empty(), "无存档时返回空")
	gs.reset_defaults()
	gs.credits = 333
	gs.island_stock = ["gold_cup", "cursed_idol"]
	gs.materials = {"wood": 2, "iron": 0, "canvas": 1}
	gs.upgrades = {"bag": true, "fins": false, "amulet": true}
	gs.boat_invested = {"wood": 1, "iron": 0, "canvas": 0}
	_check(sm.save_game(gs.serialize()), "存档写入成功")

	gs.reset_defaults()
	gs.apply_save(sm.load_game())
	_check(gs.credits == 333 and gs.island_stock == ["gold_cup", "cursed_idol"],
		"额度与库存读档正确")
	_check(gs.upgrades["bag"] and gs.upgrades["amulet"] and not gs.upgrades["fins"],
		"升级状态读档正确")
	_check(gs.materials["wood"] == 2 and gs.boat_invested["wood"] == 1, "材料与造船进度正确")

	# 损坏与缺字段
	var path: String = sm.get("SAVE_PATH")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{{{不是json")
	f.close()
	_check(sm.load_game().is_empty(), "损坏存档按无存档处理")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\"credits\": \"abc\", \"island_stock\": [\"bad_id\", \"gold_cup\"]}")
	f.close()
	gs.reset_defaults()
	gs.apply_save(sm.load_game())
	_check(gs.credits == 0 and gs.island_stock == ["gold_cup"], "非法字段被安全忽略")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return 0


func _test_map_data() -> int:
	print("[地图数据]")
	_check(MapData.CHEST_SPOTS.size() == 14, "宝物生成点共14个")
	var counts := {"A": 0, "B": 0, "C": 0}
	for spot in MapData.CHEST_SPOTS:
		counts[MapData.zone_at(spot.x)] += 1
		for r in MapData.SOLID_RECTS:
			var rect := Rect2(r[0] - 16, r[1] - 16, r[2] + 32, r[3] + 32)
			_check_quiet(not rect.has_point(spot), "宝物点 %s 不在实体地形内" % spot)
	_check(counts["A"] == 5 and counts["B"] == 5 and counts["C"] == 4, "区域点位 5/5/4")
	_check(quiet_fail == 0, "所有宝物点位于开阔水域")
	for p in MapData.SHARK_PATROLS:
		_check_quiet(p[1] > p[0], "鲨鱼巡逻区间有效 %s" % [p])
	_check(MapData.EXTRACT_RECT.has_point(MapData.PLAYER_SPAWN + Vector2(0, -120)),
		"撤离区可达（出生点上方在区内）")
	return 0
