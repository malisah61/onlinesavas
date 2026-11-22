extends RefCounted
## Kodla üretilen sesler (Komando ses.gd dersi: lisans sorunu yok, dosya yok, telefonda hafif; ilk kullanımda bir kez üretilir).

static var _onbellek := {}
static var acik := true


static func _uret(tur: String) -> AudioStreamWAV:
	var hz := 22050
	var sure: float = {"tufek": 0.7, "makineli": 0.16, "keskin": 1.0, "agir": 0.2, "patlama": 1.4, "vurus": 0.12,
		"al": 0.25, "dolum": 0.45, "bos": 0.08}.get(tur, 0.2)
	var n := int(hz * sure)
	var veri := PackedByteArray()
	veri.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tur)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / hz
		var v := 0.0
		match tur:
			"tufek", "keskin":
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.55)
				var g := 1.0 if tur == "tufek" else 1.25
				v = lp * exp(-t * 55.0) * 1.4 * g + sin(TAU * 68.0 * t) * exp(-t * 13.0) * 0.6 \
					+ lp * exp(-maxf(t - 0.1, 0.0) * 5.0) * 0.16 * smoothstep(0.08, 0.13, t)
			"makineli", "agir":
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.6)
				var f := 95.0 if tur == "agir" else 130.0
				v = lp * exp(-t * 70.0) * 1.2 + sin(TAU * f * t) * exp(-t * 30.0) * 0.55
			"patlama":
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.2)
				lp2 = lerpf(lp2, lp, 0.1)
				v = lp * exp(-t * 9.0) * 1.2 + lp2 * exp(-t * 2.5) * 2.0 + sin(TAU * 45.0 * t) * exp(-t * 6.0) * 0.7
			"vurus":
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.3)
				v = lp * exp(-t * 40.0) + sin(TAU * 140.0 * t) * exp(-t * 35.0) * 0.5
			"al":
				v = sin(TAU * (520.0 + 500.0 * t) * t) * exp(-t * 8.0) * 0.5
			"dolum":
				if t < 0.03 or (t > 0.3 and t < 0.33):
					v = sin(TAU * 1700.0 * t) * 0.4 + rng.randf_range(-0.3, 0.3)
			"bos":
				v = sin(TAU * 2200.0 * t) * exp(-t * 60.0) * 0.4
		veri.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = hz
	w.data = veri
	return w


static func cal(ebeveyn: Node, tur: String, konum: Vector2, ses_db := -8.0) -> void:
	if not acik or DisplayServer.get_name() == "headless":
		return
	if not _onbellek.has(tur):
		_onbellek[tur] = _uret(tur)
	var p := AudioStreamPlayer2D.new()
	p.stream = _onbellek[tur]
	p.position = konum
	p.max_distance = 1400.0
	p.attenuation = 1.6
	p.volume_db = ses_db
	p.pitch_scale = randf_range(0.93, 1.07)
	ebeveyn.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
