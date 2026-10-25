class_name ItemDB
## 宝物 / 品质 / 物资 / 容器 / 背包档位 / 升级 / 造船 / 刷新权重 数据表。
## 所有经济数值集中在此，不要在拾取、交易逻辑中硬编码。

## 品质体系（三角洲式摸金）：实例价值 = 基础价值 × 品质倍率
const QUALITIES := {
	"worn": {"name": "破损", "mult": 0.6, "color": Color(0.55, 0.55, 0.6)},
	"standard": {"name": "标准", "mult": 1.0, "color": Color(0.92, 0.92, 0.88)},
	"fine": {"name": "精良", "mult": 1.4, "color": Color(0.4, 0.75, 0.95)},
	"pristine": {"name": "完美", "mult": 2.0, "color": Color(0.95, 0.78, 0.25)},
}

const TREASURES := {
	"old_coin": {
		"name": "旧硬币", "value": 10, "slots": 1, "search_time": 1.0,
		"color": Color(0.62, 0.55, 0.42), "rare": false,
	},
	"pearl": {
		"name": "珍珠", "value": 18, "slots": 1, "search_time": 1.2,
		"color": Color(0.9, 0.82, 0.88), "rare": false,
	},
	"bronze_coins": {
		"name": "古铜币包", "value": 25, "slots": 1, "search_time": 1.5,
		"color": Color(0.72, 0.55, 0.3), "rare": false,
	},
	"silver_platter": {
		"name": "银质餐盘", "value": 70, "slots": 2, "search_time": 3.0,
		"color": Color(0.78, 0.82, 0.88), "rare": false,
	},
	"gold_cup": {
		"name": "沉船金杯", "value": 140, "slots": 3, "search_time": 5.0,
		"color": Color(0.95, 0.78, 0.25), "rare": true,
	},
	"cursed_idol": {
		"name": "诅咒神像", "value": 280, "slots": 5, "search_time": 7.0,
		"color": Color(0.62, 0.32, 0.78), "rare": true,
	},
}

## 材料价格；leather 只能从海底获得也可回售/回购
const MATERIALS := {
	"wood": {"name": "木材", "price": 100},
	"iron": {"name": "铁件", "price": 180},
	"canvas": {"name": "帆布", "price": 160},
	"leather": {"name": "皮革", "price": 120},
}

## 材料回售比例（商人物物交换的折损）
const MATERIAL_SELL_RATE := 0.8

## 可搜索容器："@材料id" 表示掉落材料
const CONTAINERS := {
	"chest": {"name": "沉船宝箱", "search_time": 3.0},
	"shell": {
		"name": "海贝", "search_time": 1.2,
		"loot_pool": {"old_coin": 45, "pearl": 28, "@leather": 15, "bronze_coins": 12},
	},
	"trash_bag": {
		"name": "垃圾袋", "search_time": 2.0,
		"loot_pool": {"old_coin": 30, "@leather": 28, "bronze_coins": 20,
			"pearl": 12, "silver_platter": 10},
	},
	"cache": {"name": "遗落物袋", "search_time": 2.0},
}

## 宝箱开出件数权重（区域越深件数越多）
const CHEST_COUNT_WEIGHTS := {
	"A": {1: 55, 2: 35, 3: 10, 4: 0},
	"B": {1: 35, 2: 40, 3: 20, 4: 5},
	"C": {1: 25, 2: 35, 3: 25, 4: 15},
}

## 宝箱品质权重（区域越深品质越好）
const CHEST_QUALITY_WEIGHTS := {
	"A": {"worn": 35, "standard": 45, "fine": 18, "pristine": 2},
	"B": {"worn": 25, "standard": 45, "fine": 25, "pristine": 5},
	"C": {"worn": 15, "standard": 40, "fine": 30, "pristine": 15},
}

## 小型容器的品质偏旧
const CONTAINER_QUALITY_WEIGHTS := {"worn": 50, "standard": 40, "fine": 9, "pristine": 1}

## 背包档位：通过搜索材料在工作台打造
const BAG_TIERS := [
	{"name": "标准潜水包", "capacity": 8, "cost": {}},
	{"name": "皮革背包", "capacity": 10, "cost": {"leather": 2}},
	{"name": "加固背包", "capacity": 12, "cost": {"leather": 2, "iron": 1}},
]

const UPGRADES := {
	"fins": {"name": "改良脚蹼", "cost": 160, "desc": "游泳与冲刺速度 +20%"},
	"amulet": {"name": "潜水护符", "cost": 220, "desc": "最大体力 100 → 125"},
}

const BOAT_REQUIREMENT := {"wood": 2, "iron": 1, "canvas": 1}

## 兵器打造（工作台）
const HARPOON_CRAFT := {"iron": 2, "wood": 1}

## 鲨鱼击杀掉落
const SHARK_DROP := "leather"

## 深渊巨影击杀掉落
const BOSS_LOOT := [
	{"id": "cursed_idol", "quality": "pristine"},
	{"id": "gold_cup", "quality": "fine"},
	{"mat": "leather"},
	{"mat": "leather"},
]

# 各区域宝物出现权重（宝箱内物品的类型分布，区域按 x 坐标划分）
const ZONE_WEIGHTS := {
	"A": {"old_coin": 0.10, "bronze_coins": 0.55, "silver_platter": 0.35},
	"B": {"bronze_coins": 0.15, "silver_platter": 0.45, "gold_cup": 0.40},
	"C": {"silver_platter": 0.10, "gold_cup": 0.50, "cursed_idol": 0.40},
}
