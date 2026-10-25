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

# ---- 海面换气 ----
const SURFACE_Y := 40.0           # 水面高度（玩家 y 最低被限制在此）
const BREATH_DEPTH := 70.0        # 距水面多深内可换气（需上方与天空相通）
const SURFACE_REGEN := 8.0        # 换气每秒恢复的体力（不超过当前上限）

# ---- 生命 ----
const MAX_HP := 3
const INVINCIBLE_TIME := 2.0      # 受伤后无敌时间（秒）

# ---- 交互 ----
const INTERACT_RANGE := 78.0      # 交互判定半径 px

# ---- 鲨鱼 ----
const SHARK_PATROL_SPEED := 70.0
const SHARK_ALERT_SPEED := 45.0
const SHARK_CHASE_SPEED := 120.0
const SHARK_CHASE_TURN := 240.0        # 追逐转向加速度：较低让玩家可以横向走位甩开
const SHARK_DETECT_RANGE := 180.0      # 普通发现范围 px
const SHARK_DETECT_CURSE_MULT := 1.5   # 携带诅咒神像时 ×1.5 = 270
const SHARK_ALERT_TIME := 0.55         # 警戒持续时间，之后进入追逐
const SHARK_LOSE_SIGHT_TIME := 2.2     # 丢失视线多久后放弃追逐
const SHARK_GIVEUP_DIST_MULT := 1.25   # 玩家距离超过发现范围×该值时放弃
const SHARK_DAMAGE := 1
const SHARK_ATTACK_COOLDOWN := 1.6     # 同一条鲨鱼两次咬击的最小间隔
const SHARK_BITE_RETREAT := 1.1        # 咬人后强制脱离时间（给玩家脱身窗口）
const SHARK_HP := 3                    # 鲨鱼生命（鱼叉 3 次刺击击杀）
const SHARK_FLEE_TIME := 1.5           # 被刺后的逃窜时间
const BITE_KNOCKBACK := 260.0          # 被咬时玩家的击退速度

# ---- 下潜刷新 ----
const ACTIVE_PER_DIVE := {"A": 4, "B": 4, "C": 3}      # 每次下潜各区域激活的宝箱点数（种子随机挑点）
const CONTAINER_COUNTS := {"A": 6, "B": 5, "C": 4}     # 小型容器（海贝/垃圾袋）散布数量

# ---- 节奏 ----
const FAIL_RESULT_DELAY := 0.7    # 失败后延迟多少秒弹出结算
const DIVE_TIME_LIMIT := 900.0    # 每次下潜时限（秒），归零 = 撤离窗口关闭

# ---- 兵器（鱼叉） ----
const HARPOON_DAMAGE := 1
const HARPOON_COOLDOWN := 0.7     # 刺击间隔（秒）
const HARPOON_STAMINA := 2.5      # 每次刺击体力消耗
const HARPOON_RANGE := 150.0      # 自动瞄准的搜索半径
const HARPOON_REACH := 120.0      # 刺击判定中心距离

# ---- 深渊巨影（克苏鲁级 Boss） ----
const BOSS_AWAKEN_DELAY := 12.0   # 携带神像后多少秒苏醒
const BOSS_HP := 16
const BOSS_SLAM_INTERVAL := 4.5   # 触拍间隔（秒）
const BOSS_TELEGRAPH := 1.1       # 预警圈持续时间（秒）
const BOSS_SLAM_RADIUS := 110.0   # 触拍伤害半径
const BOSS_DAMAGE := 1
const BOSS_DRIFT_SPEED := 26.0    # 巨影逼近速度

# ---- 幽灵船长（沉船主题 Boss） ----
const CAPTAIN_HP := 10
const CAPTAIN_DRIFT_SPEED := 42.0     # 缓慢逼近
const CAPTAIN_KEEP_DIST := 240.0      # 逼近到此距离内则停住蓄力
const CAPTAIN_DASH_INTERVAL := 4.0    # 冲刺循环间隔
const CAPTAIN_DASH_TELEGRAPH := 0.9   # 冲刺预警时间
const CAPTAIN_DASH_SPEED := 520.0
const CAPTAIN_DASH_TIME := 0.5
const CAPTAIN_DASH_RANGE := 340.0     # 预警线长度（也是冲刺距离参考）
const CAPTAIN_DAMAGE := 1
const CAPTAIN_LEASH := 850.0          # 玩家离开出生点该距离即遁回

# ---- 洞穴海蛇（洞穴主题 Boss） ----
const SERPENT_HP := 12
const SERPENT_AWAKE_DIST := 430.0     # 玩家靠近洞穴深处即触发突袭
const SERPENT_LUNGE_TELEGRAPH := 1.0  # 突袭预警时间
const SERPENT_LUNGE_SPEED := 460.0
const SERPENT_LUNGE_TIME := 0.45
const SERPENT_COOLDOWN := 2.2         # 突袭后回洞喘息时间
const SERPENT_DAMAGE := 1
const SERPENT_LEASH := 900.0          # 玩家离开巢穴该距离即潜回
