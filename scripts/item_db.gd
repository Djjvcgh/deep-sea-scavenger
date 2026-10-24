class_name ItemDB
## 宝物 / 物资 / 升级 / 造船 / 刷新权重 数据表。
## 所有经济数值集中在此，不要在拾取、交易逻辑中硬编码。

const TREASURES := {
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

const MATERIALS := {
	"wood": {"name": "木材", "price": 100},
	"iron": {"name": "铁件", "price": 180},
	"canvas": {"name": "帆布", "price": 160},
}

const UPGRADES := {
	"bag": {"name": "扩容背包", "cost": 180, "desc": "背包容量 8 格 → 12 格"},
	"fins": {"name": "改良脚蹼", "cost": 160, "desc": "游泳与冲刺速度 +20%"},
	"amulet": {"name": "潜水护符", "cost": 220, "desc": "最大体力 100 → 125"},
}

const BOAT_REQUIREMENT := {"wood": 2, "iron": 1, "canvas": 1}

# 各区域宝物出现权重（区域按宝物点 x 坐标划分，见 map_data.gd）
const ZONE_WEIGHTS := {
	"A": {"bronze_coins": 0.65, "silver_platter": 0.35},
	"B": {"bronze_coins": 0.15, "silver_platter": 0.45, "gold_cup": 0.40},
	"C": {"silver_platter": 0.10, "gold_cup": 0.50, "cursed_idol": 0.40},
}
