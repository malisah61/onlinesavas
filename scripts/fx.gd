extends Node2D
## Efektler: mermi izi, kan/toz, patlama, el bombası yayı, ölüm izi. Tamamen kodla çizilir (dosya yok).

var izler: Array = []      # [a, b, t, renk]
var parcalar: Array = []   # [p, v, t, ömür, renk, boy]
var patlamalar: Array = [] # [p, t]
var bombalar: Array = []   # dünyadan: [konum]
var lekeler: Array = []    # kalıcı-ish yanık/kan lekeleri [p, r, renk, t]
var sarsinti := 0.0


func iz(a: Vector2, b: Vector2, renk := Color(1, 0.9, 0.55)) -> void:
	izler.append([a, b, 0.0, renk])


func toz(p: Vector2, yon: Vector2, kan := false) -> void:
	for i in (7 if kan else 5):
		var v := (yon.rotated(randf_range(-0.9, 0.9)) * randf_range(40, 160))
		var r := Color(0.6, 0.05, 0.05) if kan else Color(0.55, 0.5, 0.4)
		parcalar.append([p, v, 0.0, randf_range(0.25, 0.5), r, randf_range(1.5, 3.2)])
	if kan:
		lekeler.append([p + Vector2(randf_range(-6, 6), randf_range(8, 16)), randf_range(4, 8), Color(0.35, 0.02, 0.02, 0.55), 0.0])


func patla(p: Vector2) -> void:
	patlamalar.append([p, 0.0])
	sarsinti = maxf(sarsinti, 0.35)
	lekeler.append([p, 46.0, Color(0.05, 0.04, 0.03, 0.55), 0.0])
	for i in 26:
		var v := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80, 340)
		parcalar.append([p, v, 0.0, randf_range(0.35, 0.9), Color(0.35, 0.3, 0.25) if i % 2 else Color(1, 0.6, 0.15), randf_range(2, 4.5)])


func _process(dt: float) -> void:
	for x in izler:
		x[2] += dt
	izler = izler.filter(func(x): return x[2] < 0.09)
	for x in parcalar:
		x[2] += dt
		x[0] += x[1] * dt
		x[1] *= 0.9
	parcalar = parcalar.filter(func(x): return x[2] < x[3])
	for x in patlamalar:
		x[1] += dt
	patlamalar = patlamalar.filter(func(x): return x[1] < 0.6)
	for x in lekeler:
		x[3] += dt
	lekeler = lekeler.filter(func(x): return x[3] < 40.0)
	if lekeler.size() > 120:
		lekeler = lekeler.slice(lekeler.size() - 120)
	sarsinti = maxf(0.0, sarsinti - dt)
	queue_redraw()


func _draw() -> void:
	for x in lekeler:
		var a: float = x[2].a * clampf((40.0 - x[3]) / 8.0, 0.0, 1.0)
		draw_circle(x[0], x[1], Color(x[2], a))
	for b in bombalar:
		var p: Vector2 = b[0]
		var h: float = b[1]   # havadaki yükseklik (yay)
		draw_circle(p + Vector2(3, 3), 5, Color(0, 0, 0, 0.35))
		draw_circle(p - Vector2(0, h), 5.5, Color(0.22, 0.28, 0.15))
		draw_circle(p - Vector2(1.5, h + 1.5), 2.0, Color(0.5, 0.55, 0.35))
		if h <= 0.5 and int(Time.get_ticks_msec() / 120) % 2 == 0:
			draw_arc(p, 140, 0, TAU, 40, Color(1, 0.3, 0.2, 0.25), 2.0)
	for x in izler:
		var k: float = 1.0 - x[2] / 0.09
		draw_line(x[0], x[1], Color(x[3], 0.75 * k), 2.0)
		draw_line(x[0].lerp(x[1], 0.6), x[1], Color(1, 1, 0.9, 0.9 * k), 1.2)
	for x in parcalar:
		var k: float = 1.0 - x[2] / x[3]
		draw_circle(x[0], x[5], Color(x[4], k))
	for x in patlamalar:
		var t: float = x[1]
		var r := 30.0 + t * 260.0
		draw_circle(x[0], minf(r, 150.0) * 0.8, Color(1, 0.75, 0.3, maxf(0.0, 0.7 - t * 2.2)))
		draw_circle(x[0], minf(r, 150.0) * 0.45, Color(1, 1, 0.8, maxf(0.0, 0.9 - t * 4.0)))
		draw_arc(x[0], r, 0, TAU, 48, Color(1, 1, 1, maxf(0.0, 0.5 - t)), 3.0)
		draw_circle(x[0] + Vector2(0, -t * 60), 40.0 + t * 50.0, Color(0.2, 0.2, 0.2, maxf(0.0, 0.45 - t * 0.7)))
