extends Node
## 音效管理（autoload: Sfx）。加载 assets/audio 下的程序生成音效；缺失时静默跳过。

const PATHS := {
	"click": "res://assets/audio/ui_click.wav",
	"pickup": "res://assets/audio/pickup.wav",
	"rare_pickup": "res://assets/audio/rare_pickup.wav",
	"alert": "res://assets/audio/alert.wav",
	"hurt": "res://assets/audio/hurt.wav",
	"sell": "res://assets/audio/sell.wav",
	"build": "res://assets/audio/build_complete.wav",
	"fail": "res://assets/audio/fail.wav",
	"exhaust": "res://assets/audio/exhaust.wav",
	"heartbeat": "res://assets/audio/heartbeat.wav",
	"stab": "res://assets/audio/stab.wav",
	"slam": "res://assets/audio/slam.wav",
	"boss_warn": "res://assets/audio/boss_warn.wav",
	"boss_die": "res://assets/audio/boss_die.wav",
	"ambient_underwater": "res://assets/audio/ambient_underwater.wav",
	"ambient_island": "res://assets/audio/ambient_island.wav",
	"tension": "res://assets/audio/tension.wav",
}

var _streams := {}
var _ambient_player: AudioStreamPlayer
var _ambient_key := ""
var _tension_player: AudioStreamPlayer


func _ready() -> void:
	# 暂停时音效仍可播放（结算界面、暂停菜单）。
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in PATHS:
		if ResourceLoader.exists(PATHS[key]):
			_streams[key] = load(PATHS[key])
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.volume_db = -10.0
	add_child(_ambient_player)
	_tension_player = AudioStreamPlayer.new()
	_tension_player.volume_db = -7.0
	add_child(_tension_player)


func play(key: String, volume_db := 0.0) -> void:
	if not _streams.has(key):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[key]
	p.volume_db = volume_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func play_ambient(key: String) -> void:
	if _ambient_key == key and _ambient_player.playing:
		return
	_ambient_key = key
	if not _streams.has(key):
		_ambient_player.stop()
		return
	_loop_wav(_streams[key])
	_ambient_player.stream = _streams[key]
	_ambient_player.play()


func stop_ambient() -> void:
	_ambient_key = ""
	_ambient_player.stop()


## 鲨鱼追逐期间的紧张低音循环。
func play_tension() -> void:
	if not _streams.has("tension"):
		return
	_loop_wav(_streams["tension"])
	if not _tension_player.playing:
		_tension_player.stream = _streams["tension"]
		_tension_player.play()


func stop_tension() -> void:
	_tension_player.stop()


func _loop_wav(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2  # 16bit 单声道，样本数 = 字节/2
