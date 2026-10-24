extends SceneTree
## 一次性开发工具：程序生成占位音效到 assets/audio/。
## 运行：godot --headless -s res://tools/gen_audio.gd

const RATE := 22050


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/audio")

	_write("ui_click.wav", _tone(880.0, 0.05, 0.3))
	_write("pickup.wav", _mix([
		[_tone(660.0, 0.09, 0.4), 0.0],
		[_tone(990.0, 0.12, 0.4), 0.08]]))
	_write("rare_pickup.wav", _mix([
		[_tone(523.0, 0.09, 0.4), 0.0],
		[_tone(659.0, 0.09, 0.4), 0.09],
		[_tone(784.0, 0.09, 0.4), 0.18],
		[_tone(1047.0, 0.16, 0.45), 0.27],
		[_tone(2093.0, 0.15, 0.18), 0.36]]))
	_write("alert.wav", _mix([
		[_tone(620.0, 0.12, 0.32, "saw", 0.005, 0.05, 380.0), 0.0],
		[_tone(620.0, 0.12, 0.32, "saw", 0.005, 0.05, 380.0), 0.18]]))
	_write("hurt.wav", _mix([
		[_noise(0.15, 0.5, 0.5), 0.0],
		[_tone(140.0, 0.25, 0.4), 0.0]]))
	_write("sell.wav", _mix([
		[_tone(1318.0, 0.08, 0.32), 0.0],
		[_tone(1760.0, 0.12, 0.32), 0.07]]))
	_write("build_complete.wav", _mix([
		[_tone(523.0, 0.55, 0.28), 0.0],
		[_tone(659.0, 0.5, 0.28), 0.08],
		[_tone(784.0, 0.45, 0.28), 0.16],
		[_tone(1046.0, 0.6, 0.32), 0.24]]))
	_write("fail.wav", _tone(300.0, 0.6, 0.35, "saw", 0.01, 0.2, 110.0))
	_write("exhaust.wav", _mix([
		[_tone(220.0, 0.12, 0.32, "square", 0.005, 0.04), 0.0],
		[_tone(220.0, 0.12, 0.32, "square", 0.005, 0.04), 0.2]]))
	_write("ambient_underwater.wav", _mix([
		[_ambient_base(4.0, 0.05, 0.22), 0.0],
		[_wobble_sine(58.0, 4.0, 0.07), 0.0]]))
	_write("ambient_island.wav", _mix([
		[_ambient_base(4.0, 0.09, 0.14), 0.0],
		[_wobble_sine(220.0, 4.0, 0.03), 0.0]]))

	print("音效生成完成")
	quit(0)


func _tone(freq: float, dur: float, vol := 0.5, shape := "sine", attack := 0.005,
		release := 0.06, sweep_to := 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := freq if sweep_to <= 0.0 else lerpf(freq, sweep_to, t / dur)
		phase += TAU * f / RATE
		var s := 0.0
		match shape:
			"sine":
				s = sin(phase)
			"saw":
				s = fmod(phase / TAU, 1.0) * 2.0 - 1.0
			"square":
				s = 1.0 if sin(phase) >= 0.0 else -1.0
		var env := 1.0
		if t < attack:
			env = t / attack
		elif t > dur - release:
			env = maxf(0.0, (dur - t) / release)
		out[i] = s * env * vol
	return out


func _noise(dur: float, vol := 0.4, cutoff := 0.3) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var last := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in n:
		var white := rng.randf_range(-1.0, 1.0)
		last = last + cutoff * (white - last)
		var t := float(i) / RATE
		var env := minf(t / 0.01, 1.0) * minf((dur - t) / (dur * 0.4), 1.0)
		out[i] = last * env * vol
	return out


## 循环环境声：首尾 0.08s 淡入淡出，弱化接缝。
func _ambient_base(dur: float, cutoff: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var last := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 67890
	for i in n:
		var white := rng.randf_range(-1.0, 1.0)
		last = last + cutoff * (white - last)
		var t := float(i) / RATE
		var edge := minf(t / 0.08, 1.0) * minf((dur - t) / 0.08, 1.0)
		out[i] = last * edge * vol
	return out


## 振幅按整周期缓慢起伏的正弦（时长内整数个周期，利于循环）。
func _wobble_sine(freq: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var cycles := 2.0
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * freq * t) * (0.6 + 0.4 * sin(TAU * cycles * t / dur)) * vol
	return out


func _mix(parts: Array) -> PackedFloat32Array:
	var total := 0
	for p in parts:
		total = maxi(total, int(p[1] * RATE) + (p[0] as PackedFloat32Array).size())
	var out := PackedFloat32Array()
	out.resize(total)
	for p in parts:
		var samples: PackedFloat32Array = p[0]
		var offset := int(p[1] * RATE)
		for i in samples.size():
			out[offset + i] += samples[i]
	return out


func _write(name: String, samples: PackedFloat32Array) -> void:
	var data_size := samples.size() * 2
	var buf := StreamPeerBuffer.new()
	buf.put_data("RIFF".to_ascii_buffer())
	buf.put_32(36 + data_size)
	buf.put_data("WAVE".to_ascii_buffer())
	buf.put_data("fmt ".to_ascii_buffer())
	buf.put_32(16)
	buf.put_16(1)
	buf.put_16(1)
	buf.put_32(RATE)
	buf.put_32(RATE * 2)
	buf.put_16(2)
	buf.put_16(16)
	buf.put_data("data".to_ascii_buffer())
	buf.put_32(data_size)
	for s in samples:
		buf.put_16(int(clampf(s, -1.0, 1.0) * 32000.0))
	var f := FileAccess.open("res://assets/audio/" + name, FileAccess.WRITE)
	if f == null:
		push_error("无法写入 " + name)
		return
	f.store_buffer(buf.data_array)
	f.close()
	print("生成 %s（%.2f 秒）" % [name, samples.size() / float(RATE)])
