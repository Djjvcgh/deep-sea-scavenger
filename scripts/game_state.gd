extends Node
## 全局状态（autoload: GameState）。
## 永久进度：交易额度 / 岛上库存 / 材料 / 升级 / 造船。
## 单次下潜临时数据：dive_bag（不写入存档，撤离成功才转入永久库存）。
## 只负责数据与规则，不直接操作 UI；UI 通过信号刷新。

signal credits_changed(value: int)
signal island_stock_changed
signal materials_changed
signal upgrades_changed
signal boat_changed
signal dive_bag_changed
signal boat_completed_signal

const ItemDBRes := preload("res://scripts/item_db.gd")

# ---- 永久进度 ----
var credits := 0
var island_stock: Array = []            # 岛上待出售宝物 id 列表
var materials := {"wood": 0, "iron": 0, "canvas": 0}
var upgrades := {"bag": false, "fins": false, "amulet": false}
var boat_invested := {"wood": 0, "iron": 0, "canvas": 0}
var boat_completed := false

# ---- 单次下潜临时数据 ----
var dive_bag: Array = []                # 本次潜水携带的宝物 id 列表


func reset_defaults() -> void:
	credits = 0
	island_stock = []
	materials = {"wood": 0, "iron": 0, "canvas": 0}
	upgrades = {"bag": false, "fins": false, "amulet": false}
	boat_invested = {"wood": 0, "iron": 0, "canvas": 0}
	boat_completed = false
	dive_bag = []


# ---------------- 存档 ----------------

func serialize() -> Dictionary:
	return {
		"version": 1,
		"credits": credits,
		"island_stock": island_stock.duplicate(),
		"materials": materials.duplicate(),
		"upgrades": upgrades.duplicate(),
		"boat_invested": boat_invested.duplicate(),
		"boat_completed": boat_completed,
	}


func apply_save(data: Dictionary) -> void:
	# 对缺失、损坏、类型不符的字段做安全处理，其余保持默认值。
	reset_defaults()
	credits = maxi(0, int(data.get("credits", 0)))
	var stock = data.get("island_stock", [])
	if stock is Array:
		for id in stock:
			if ItemDBRes.TREASURES.has(id):
				island_stock.append(id)
	_apply_dict(data.get("materials", {}), materials, false)
	_apply_dict(data.get("boat_invested", {}), boat_invested, false)
	var up = data.get("upgrades", {})
	if up is Dictionary:
		for k in upgrades.keys():
			upgrades[k] = bool(up.get(k, false))
	boat_completed = bool(data.get("boat_completed", false))


func _apply_dict(src: Variant, dst: Dictionary, as_bool: bool) -> void:
	if src is Dictionary:
		for k in dst.keys():
			if src.has(k):
				dst[k] = maxi(0, int(src[k])) if not as_bool else bool(src[k])


# ---------------- 装备与派生数值 ----------------

func max_stamina() -> float:
	return 125.0 if upgrades["amulet"] else 100.0


func bag_capacity() -> int:
	return 12 if upgrades["bag"] else 8


func speed_mult() -> float:
	return 1.2 if upgrades["fins"] else 1.0


func bag_used_slots() -> int:
	var used := 0
	for id in dive_bag:
		used += int(ItemDBRes.TREASURES[id]["slots"])
	return used


func bag_free_slots() -> int:
	return bag_capacity() - bag_used_slots()


func can_carry(slots: int) -> bool:
	return bag_used_slots() + slots <= bag_capacity()


func weight_speed_mult() -> float:
	return 0.9 if bag_used_slots() >= 6 else 1.0


func weight_drain_mult() -> float:
	return 1.2 if bag_used_slots() >= 6 else 1.0


func has_curse_idol() -> bool:
	return dive_bag.has("cursed_idol")


func dive_total_value() -> int:
	var total := 0
	for id in dive_bag:
		total += int(ItemDBRes.TREASURES[id]["value"])
	return total


func count_dive_item(id: String) -> int:
	return dive_bag.count(id)


func count_island_item(id: String) -> int:
	return island_stock.count(id)


# ---------------- 下潜临时背包 ----------------

func add_dive_item(id: String) -> bool:
	if not ItemDBRes.TREASURES.has(id):
		return false
	if not can_carry(int(ItemDBRes.TREASURES[id]["slots"])):
		return false
	dive_bag.append(id)
	dive_bag_changed.emit()
	return true


func remove_dive_item(id: String) -> bool:
	var idx := dive_bag.find(id)
	if idx < 0:
		return false
	dive_bag.remove_at(idx)
	dive_bag_changed.emit()
	return true


func start_dive() -> void:
	dive_bag = []
	dive_bag_changed.emit()


func end_dive(success: bool) -> void:
	if success:
		island_stock.append_array(dive_bag)
		island_stock_changed.emit()
	dive_bag = []
	dive_bag_changed.emit()


# ---------------- 经济行为 ----------------

func buy_upgrade(id: String) -> bool:
	if not ItemDBRes.UPGRADES.has(id) or upgrades[id]:
		return false
	var cost := int(ItemDBRes.UPGRADES[id]["cost"])
	if credits < cost:
		return false
	credits -= cost
	upgrades[id] = true
	credits_changed.emit(credits)
	upgrades_changed.emit()
	return true


func sell_one(id: String) -> bool:
	var idx := island_stock.find(id)
	if idx < 0 or not ItemDBRes.TREASURES.has(id):
		return false
	island_stock.remove_at(idx)
	credits += int(ItemDBRes.TREASURES[id]["value"])
	island_stock_changed.emit()
	credits_changed.emit(credits)
	return true


func sell_all_of(id: String) -> int:
	var value := int(ItemDBRes.TREASURES[id]["value"]) if ItemDBRes.TREASURES.has(id) else 0
	var n := 0
	while island_stock.has(id):
		island_stock.erase(id)
		n += 1
	if n > 0:
		credits += value * n
		island_stock_changed.emit()
		credits_changed.emit(credits)
	return n


func buy_material(id: String) -> bool:
	if not ItemDBRes.MATERIALS.has(id):
		return false
	var price := int(ItemDBRes.MATERIALS[id]["price"])
	if credits < price:
		return false
	credits -= price
	materials[id] += 1
	credits_changed.emit(credits)
	materials_changed.emit()
	return true


## 把最多 amount 个材料投入造船，返回实际投入数量。
func invest_material(id: String, amount: int) -> int:
	if boat_completed or not ItemDBRes.MATERIALS.has(id) or amount <= 0:
		return 0
	var missing: int = int(ItemDBRes.BOAT_REQUIREMENT[id]) - int(boat_invested[id])
	var moved := mini(mini(amount, materials[id]), maxi(0, missing))
	if moved <= 0:
		return 0
	materials[id] -= moved
	boat_invested[id] += moved
	materials_changed.emit()
	boat_changed.emit()
	if _boat_done():
		boat_completed = true
		boat_completed_signal.emit()
		boat_changed.emit()
	return moved


func _boat_done() -> bool:
	for id in ItemDBRes.BOAT_REQUIREMENT:
		if boat_invested[id] < int(ItemDBRes.BOAT_REQUIREMENT[id]):
			return false
	return true


func boat_progress() -> float:
	var need := 0
	var got := 0
	for id in ItemDBRes.BOAT_REQUIREMENT:
		need += int(ItemDBRes.BOAT_REQUIREMENT[id])
		got += mini(int(boat_invested[id]), int(ItemDBRes.BOAT_REQUIREMENT[id]))
	return float(got) / float(need) if need > 0 else 0.0
