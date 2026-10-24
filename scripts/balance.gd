class_name Balance
## 全局数值配置：所有可调参数集中在此，便于平衡调整。

# ---- 玩家移动 ----
const SWIM_SPEED := 95.0          # 正常游泳速度 px/s
const SPRINT_SPEED := 155.0       # 冲刺游泳速度 px/s
const WALK_SPEED := 220.0         # 岛上行走速度 px/s
const SWIM_ACCEL := 620.0         # 水中加速度
const SWIM_FRICTION := 480.0      # 水中减速度
const WALK_ACCEL := 1600.0        # 地面加速度

# ---- 潜水体力 ----
const STAMINA_MAX := 100.0
const DRAIN_IDLE := 0.25          # 原地停留 每秒消耗
const DRAIN_SWIM := 0.45          # 正常游泳 每秒消耗
const DRAIN_SEARCH := 0.45        # 搜索宝箱期间按游泳消耗计
const DRAIN_SPRINT := 1.10        # 冲刺游泳 每秒消耗
const HEAVY_SLOTS := 6            # 背包占用达到该格数触发负重惩罚
const HEAVY_SPEED_MULT := 0.9     # 负重时移动速度 ×0.9
const HEAVY_DRAIN_MULT := 1.2     # 负重时体力消耗 ×1.2
const LOW_STAMINA_RATIO := 0.35   # 低于35%：提示返航
const CRIT_STAMINA_RATIO := 0.20  # 低于20%：红色危险警告

# ---- 生命 ----
const MAX_HP := 3
const INVINCIBLE_TIME := 2.0      # 受伤后无敌时间（秒）

# ---- 交互 ----
const INTERACT_RANGE := 78.0      # 交互判定半径 px

# ---- 鲨鱼 ----
const SHARK_PATROL_SPEED := 70.0
const SHARK_ALERT_SPEED := 45.0
const SHARK_CHASE_SPEED := 120.0
const SHARK_DETECT_RANGE := 180.0      # 普通发现范围 px
const SHARK_DETECT_CURSE_MULT := 1.5   # 携带诅咒神像时 ×1.5 = 270
const SHARK_ALERT_TIME := 0.55         # 警戒持续时间，之后进入追逐
const SHARK_LOSE_SIGHT_TIME := 2.2     # 丢失视线多久后放弃追逐
const SHARK_GIVEUP_DIST_MULT := 1.35   # 玩家距离超过发现范围×该值时放弃
const SHARK_DAMAGE := 1
const SHARK_ATTACK_COOLDOWN := 1.0

# ---- 下潜刷新 ----
const SPAWN_A_ACTIVE := 3         # 区域A每次激活的宝物点数
const SPAWN_B_ACTIVE := 3         # 区域B
const SPAWN_C_ACTIVE := 2         # 区域C
const SPAWN_EXTRA := 2            # 剩余点位中再随机激活的数量

# ---- 节奏 ----
const FAIL_RESULT_DELAY := 0.7    # 失败后延迟多少秒弹出结算
