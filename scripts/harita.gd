extends Node2D
## Savaş alanı: tohumdan (seed) üretilir; herkes aynı tohumla aynı haritayı kurar (ağdan harita gönderilmez).
## Nokta simetrili (180° döndürme): iki takım için de adil. Çarpışma, görüş hattı ve yol bulma saf matematikle
## (fizik motoru yok): kurucu, istemci ve bulut bot testi aynı sonucu verir.
##
## Engel türleri:
##   ev     – yürünmez, mermi ve görüş geçmez
##   tas    – (taş duvar) ev gibi ama ince
##   kum    – kum torbası: yürünmez, görüş geçer, mermiyi hedefe yakınsa %55 tutar (Komando'daki siper dersi)
##   sandik – kum gibi, küçük
##   tank   – enkaz: yürünmez, mermi geçmez, görüş geçer (alçak gövde) — taret yuvarlağı
##   agac   – gövde yürünmez (küçük daire), mermi/görüş geçer

const W := 2560.0
const H := 1536.0
const HUCRE := 32.0
const YARICAP := 15.0      # asker çarpışma yarıçapı

var tohum := 0
var engeller: Array = []   # {"tur", "r": Rect2, "yuksek": bool, "mermi": float (0..1 tutma)}
var agaclar: Array = []    # {"p": Vector2, "r": float}
var yollar: Array = []     # toprak yol çokgenleri (yalnız görünüm)
var dogus: Array = [[], []]
var toplanan: Array = []   # sağlık/bomba noktaları
var astar: AStarGrid2D
var _dokular := {}
var _uretilen := {}


func kur(t: int) -> void:
	tohum = t
	for deneme in 20:
		_uret(t + deneme * 7919)
		if _bagli_mi():
			break
	_astar_kur()
	queue_redraw()


func _uret(t: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = t
	engeller.clear()
	agaclar.clear()
	yollar.clear()
	toplanan.clear()
	dogus = [[], []]
	var yarim: Array = []   # sol yarıdaki engeller (sonra 180° aynalanır)
	# Merkez parça: tank enkazı (tek, simetrik)
	var tw := 150.0
	var th := 86.0
	engeller.append({"tur": "tank", "r": Rect2(W * 0.5 - tw * 0.5, H * 0.5 - th * 0.5, tw, th), "yuksek": false, "mermi": 1.0})
	# Evler: 3-4 ev, üsten (x < 380) ve merkezden uzak
	var ev_say := rng.randi_range(3, 4)
	for i in 60:
		if ev_say <= 0:
			break
		var w := rng.randf_range(150, 250)
		var h := rng.randf_range(120, 190)
		var r := Rect2(rng.randf_range(420, W * 0.5 - w - 60), rng.randf_range(80, H - h - 80), w, h)
		if _cakisir(r.grow(110), yarim) or r.grow(80).intersects(Rect2(W * 0.5 - 140, H * 0.5 - 110, 280, 220)):
			continue
		yarim.append({"tur": "ev", "r": r, "yuksek": true, "mermi": 1.0})
		ev_say -= 1
	# Taş duvar parçaları
	for i in rng.randi_range(2, 3):
		for k in 30:
			var dikey := rng.randf() < 0.5
			var r := Rect2(rng.randf_range(450, W * 0.5 - 120), rng.randf_range(100, H - 200), 26 if dikey else rng.randf_range(140, 220), rng.randf_range(140, 220) if dikey else 26)
			if not _cakisir(r.grow(90), yarim):
				yarim.append({"tur": "tas", "r": r, "yuksek": true, "mermi": 1.0})
				break
	# Kum torbaları (alçak siper) — evlerin önlerine ve açık alanlara
	for i in rng.randi_range(9, 12):
		for k in 30:
			var dikey := rng.randf() < 0.45
			var uz := rng.randf_range(80, 140)
			var r := Rect2(rng.randf_range(330, W * 0.5 - 40), rng.randf_range(70, H - 150), 26 if dikey else uz, uz if dikey else 26)
			if not _cakisir(r.grow(64), yarim) and not r.grow(40).intersects(Rect2(W * 0.5 - 120, H * 0.5 - 90, 240, 180)):
				yarim.append({"tur": "kum", "r": r, "yuksek": false, "mermi": 0.55})
				break
	# Sandıklar
	for i in rng.randi_range(4, 6):
		for k in 30:
			var s := rng.randf_range(34, 46)
			var r := Rect2(rng.randf_range(380, W * 0.5 - 60), rng.randf_range(80, H - 120), s, s)
			if not _cakisir(r.grow(56), yarim):
				yarim.append({"tur": "sandik", "r": r, "yuksek": false, "mermi": 0.7})
				break
	for e in yarim:
		engeller.append(e)
		var r: Rect2 = e["r"]
		var e2: Dictionary = e.duplicate()
		e2["r"] = Rect2(W - r.end.x, H - r.end.y, r.size.x, r.size.y)
		engeller.append(e2)
	# Ağaçlar
	var ag_yarim: Array = []
	for i in rng.randi_range(8, 12):
		for k in 30:
			var p := Vector2(rng.randf_range(300, W * 0.5 - 30), rng.randf_range(50, H - 50))
			if not _cakisir(Rect2(p - Vector2(50, 50), Vector2(100, 100)), engeller) and not _agaca_yakin(p, ag_yarim, 120):
				ag_yarim.append({"p": p, "r": rng.randf_range(34, 50)})
				break
	for a in ag_yarim:
		agaclar.append(a)
		agaclar.append({"p": Vector2(W, H) - a["p"], "r": a["r"]})
	# Toprak yol: üslerden merkeze kıvrımlı şerit
	var nok: Array = []
	var y0 := rng.randf_range(H * 0.3, H * 0.7)
	for i in 9:
		var x := lerpf(0, W * 0.5, i / 8.0)
		nok.append(Vector2(x, lerpf(y0, H * 0.5, i / 8.0) + sin(i * 1.3 + rng.randf()) * 70.0 * (1.0 - i / 8.0)))
	var tam: Array = nok.duplicate()
	for i in range(nok.size() - 2, -1, -1):
		tam.append(Vector2(W, H) - nok[i])
	yollar.append(tam)
	# Doğuş noktaları (sol üs: Müttefik)
	for i in 6:
		var p := Vector2(rng.randf_range(80, 250), lerpf(200, H - 200, i / 5.0) + rng.randf_range(-40, 40))
		dogus[0].append(p)
		dogus[1].append(Vector2(W, H) - p)
	# Toplanacaklar: 3 sağlık + 1 bomba her yarıda
	for i in 4:
		for k in 40:
			var p := Vector2(rng.randf_range(500, W * 0.5 - 80), rng.randf_range(100, H - 100))
			if not yuruyemez(p, 30.0):
				var tur := "bomba" if i == 3 else "saglik"
				toplanan.append({"tur": tur, "p": p})
				toplanan.append({"tur": tur, "p": Vector2(W, H) - p})
				break


func _cakisir(r: Rect2, liste: Array) -> bool:
	for e in liste:
		if r.intersects(e["r"]):
			return true
	return false


func _agaca_yakin(p: Vector2, liste: Array, d: float) -> bool:
	for a in liste:
		if p.distance_to(a["p"]) < d:
			return true
	return false


# ------------------------------------------------------------------ çarpışma / görüş

func yuruyemez(p: Vector2, r := YARICAP) -> bool:
	if p.x < r or p.y < r or p.x > W - r or p.y > H - r:
		return true
	for e in engeller:
		var rr: Rect2 = e["r"]
		var q := Vector2(clampf(p.x, rr.position.x, rr.end.x), clampf(p.y, rr.position.y, rr.end.y))
		if p.distance_squared_to(q) < r * r:
			return true
	for a in agaclar:
		if p.distance_to(a["p"]) < r + a["r"] * 0.28:
			return true
	return false


func kaydir(p: Vector2, hareket: Vector2, r := YARICAP) -> Vector2:
	## Engele çarpınca duvar boyunca kayar (önce x, sonra y).
	var n := p
	var x := Vector2(p.x + hareket.x, p.y)
	if not yuruyemez(x, r):
		n = x
	var y := Vector2(n.x, n.y + hareket.y)
	if not yuruyemez(y, r):
		n = y
	return n


static func _isin_kutu(a: Vector2, b: Vector2, r: Rect2) -> float:
	## a→b ışınının kutuya ilk giriş oranı (0..1), yoksa -1. (slab yöntemi)
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for ax in 2:
		var da: float = d[ax]
		var aa: float = a[ax]
		var mn: float = r.position[ax]
		var mx: float = r.end[ax]
		if absf(da) < 1e-6:
			if aa < mn or aa > mx:
				return -1.0
		else:
			var u0 := (mn - aa) / da
			var u1 := (mx - aa) / da
			if u0 > u1:
				var s := u0
				u0 = u1
				u1 = s
			t0 = maxf(t0, u0)
			t1 = minf(t1, u1)
			if t0 > t1:
				return -1.0
	return t0


func gorus_var(a: Vector2, b: Vector2) -> bool:
	## Yüksek engeller (ev, taş duvar) görüşü keser; kum torbası, tank, ağaç kesmez.
	for e in engeller:
		if e["yuksek"] and _isin_kutu(a, b, e["r"]) >= 0.0:
			return false
	return true


func mermi_yolu(a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> float:
	## Merminin a→b doğrusunda nerede durduğu (oran). Alçak siper yalnızca hedefin yakınındaysa (son ~70 px) tutabilir.
	var en := 1.0
	var boy := a.distance_to(b)
	for e in engeller:
		var t := _isin_kutu(a, b, e["r"])
		if t < 0.0 or t >= en:
			continue
		if e["tur"] == "ev" or e["tur"] == "tas" or e["tur"] == "tank":
			en = t
		elif t > 0.02 and (1.0 - t) * boy < 70.0 and rng.randf() < float(e["mermi"]):
			en = t
	return en


# ------------------------------------------------------------------ yol bulma

func _astar_kur() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, int(W / HUCRE), int(H / HUCRE))
	astar.cell_size = Vector2(HUCRE, HUCRE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for x in astar.region.size.x:
		for y in astar.region.size.y:
			if yuruyemez(_merkez(Vector2i(x, y)), YARICAP + 3.0):
				astar.set_point_solid(Vector2i(x, y))


func _merkez(c: Vector2i) -> Vector2:
	return Vector2(c) * HUCRE + Vector2(HUCRE, HUCRE) * 0.5


func hucre(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / HUCRE), 0, int(W / HUCRE) - 1), clampi(int(p.y / HUCRE), 0, int(H / HUCRE) - 1))


func bos_hucre(p: Vector2) -> Vector2i:
	var c := hucre(p)
	if not astar.is_point_solid(c):
		return c
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var k := c + Vector2i(dx, dy)
				if astar.is_in_boundsv(k) and not astar.is_point_solid(k):
					return k
	return c


func yol(a: Vector2, b: Vector2) -> PackedVector2Array:
	var p := astar.get_point_path(bos_hucre(a), bos_hucre(b))
	var out := PackedVector2Array()
	for q in p:
		out.append(q + Vector2(HUCRE, HUCRE) * 0.5)
	return out


func _bagli_mi() -> bool:
	## Taşkın doldurma: iki üs ve tüm toplanacaklar birbirine ulaşabiliyor mu?
	var gw := int(W / HUCRE)
	var gh := int(H / HUCRE)
	var dolu := {}
	for x in gw:
		for y in gh:
			if yuruyemez(Vector2(x + 0.5, y + 0.5) * HUCRE, YARICAP + 3.0):
				dolu[Vector2i(x, y)] = true
	var bas := Vector2i(int(dogus[0][0].x / HUCRE), int(dogus[0][0].y / HUCRE))
	var gorulen := {bas: true}
	var kuyruk := [bas]
	while not kuyruk.is_empty():
		var c: Vector2i = kuyruk.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var k: Vector2i = c + d
			if k.x < 0 or k.y < 0 or k.x >= gw or k.y >= gh or dolu.has(k) or gorulen.has(k):
				continue
			gorulen[k] = true
			kuyruk.append(k)
	var serbest := gw * gh - dolu.size()
	if gorulen.size() < serbest * 0.97:
		return false
	for t in toplanan:
		if not gorulen.has(Vector2i(int(t["p"].x / HUCRE), int(t["p"].y / HUCRE))):
			return false
	for p in dogus[1]:
		if not gorulen.has(Vector2i(int(p.x / HUCRE), int(p.y / HUCRE))):
			return false
	return true


func siper_noktasi(benim: Vector2, tehdit: Vector2, menzil := 420.0) -> Variant:
	## Tehditten görünmeyen (yüksek engel) ya da alçak siperin arkasında kalan en yakın yürünebilir nokta.
	var en = null
	var en_d := INF
	for e in engeller:
		var r: Rect2 = e["r"]
		var mrk := r.get_center()
		if mrk.distance_to(benim) > menzil:
			continue
		var yon := (mrk - tehdit).normalized()
		var uzak := maxf(r.size.x, r.size.y) * 0.5 + 30.0
		if not e["yuksek"]:
			uzak = minf(r.size.x, r.size.y) * 0.5 + 22.0
		for kay in [0.0, 0.5, -0.5]:
			var p: Vector2 = mrk + yon.rotated(kay) * uzak
			if yuruyemez(p, YARICAP + 2.0):
				continue
			var gizli: bool = not gorus_var(tehdit, p) or (not e["yuksek"] and _isin_kutu(tehdit, p, r) >= 0.0)
			if not gizli:
				continue
			var d := p.distance_to(benim)
			if d < en_d:
				en_d = d
				en = p
	return en


# ------------------------------------------------------------------ görünüm

func _doku(ad: String) -> Texture2D:
	if not _dokular.has(ad):
		var yol := "res://assets/dokular/%s.jpg" % ad
		_dokular[ad] = load(yol) if ResourceLoader.exists(yol) else null
	return _dokular[ad]


func _uretilen_resim(ad: String) -> Texture2D:
	## Sprite Atölye siparişinden gelen görsel varsa onu kullan (assets/uretilen/<ad>.png).
	if not _uretilen.has(ad):
		var yol := "res://assets/uretilen/%s.png" % ad
		_uretilen[ad] = load(yol) if ResourceLoader.exists(yol) else null
	return _uretilen[ad]


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -10


func _draw() -> void:
	var cim := _doku("grass")
	if cim:
		draw_texture_rect_region(cim, Rect2(0, 0, W, H), Rect2(0, 0, W * 0.9, H * 0.9), Color(0.82, 0.9, 0.75))
	else:
		draw_rect(Rect2(0, 0, W, H), Color(0.3, 0.42, 0.24))
	# üs bölgeleri
	draw_rect(Rect2(0, 0, 290, H), Color(0.35, 0.65, 1.0, 0.06))
	draw_rect(Rect2(W - 290, 0, 290, H), Color(1.0, 0.38, 0.3, 0.06))
	# toprak yol
	var toprak := _doku("dirt")
	for y in yollar:
		var pts: Array = y
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := (b - a).normalized().orthogonal() * 46.0
			var poly := PackedVector2Array([a + n, b + n, b - n, a - n])
			var uv := PackedVector2Array()
			for q in poly:
				uv.append(q / 700.0)
			if toprak:
				draw_polygon(poly, PackedColorArray([Color(0.95, 0.9, 0.8)]), uv, toprak)
			else:
				draw_colored_polygon(poly, Color(0.45, 0.38, 0.27))
		for p in pts:
			var poly := PackedVector2Array()
			var uv := PackedVector2Array()
			for k in 16:
				var q: Vector2 = p + Vector2.RIGHT.rotated(TAU * k / 16.0) * 46.0
				poly.append(q)
				uv.append(q / 700.0)
			if toprak:
				draw_polygon(poly, PackedColorArray([Color(0.95, 0.9, 0.8)]), uv, toprak)
			else:
				draw_colored_polygon(poly, Color(0.45, 0.38, 0.27))
	# gölgeler
	for e in engeller:
		var r: Rect2 = e["r"]
		var g := 14.0 if e["yuksek"] else 6.0
		draw_rect(Rect2(r.position + Vector2(g, g), r.size), Color(0, 0, 0, 0.28))
	for a in agaclar:
		draw_circle(a["p"] + Vector2(12, 12), a["r"], Color(0, 0, 0, 0.25))
	for e in engeller:
		_engel_ciz(e)


func _engel_ciz(e: Dictionary) -> void:
	var r: Rect2 = e["r"]
	match e["tur"]:
		"ev":
			var duvar := _doku("plaster")
			if duvar:
				draw_texture_rect_region(duvar, r, Rect2(Vector2.ZERO, r.size), Color(0.85, 0.82, 0.76))
			else:
				draw_rect(r, Color(0.75, 0.72, 0.66))
			var cati := r.grow(-8)
			var kiremit := _doku("roof")
			var yatay := r.size.x >= r.size.y
			if kiremit:
				draw_texture_rect_region(kiremit, cati, Rect2(Vector2.ZERO, cati.size * 1.6), Color(0.95, 0.72, 0.62))
			else:
				draw_rect(cati, Color(0.6, 0.3, 0.22))
			# mahya (çatı sırtı) ve iki yüzün ışık farkı
			var c := cati.get_center()
			if yatay:
				draw_rect(Rect2(cati.position, Vector2(cati.size.x, cati.size.y * 0.5)), Color(1, 1, 1, 0.08))
				draw_line(Vector2(cati.position.x, c.y), Vector2(cati.end.x, c.y), Color(0.3, 0.15, 0.1), 4)
			else:
				draw_rect(Rect2(cati.position, Vector2(cati.size.x * 0.5, cati.size.y)), Color(1, 1, 1, 0.08))
				draw_line(Vector2(c.x, cati.position.y), Vector2(c.x, cati.end.y), Color(0.3, 0.15, 0.1), 4)
			draw_rect(r, Color(0.2, 0.15, 0.12), false, 2.0)
		"tas":
			var tas := _doku("stone")
			if tas:
				draw_texture_rect_region(tas, r, Rect2(r.position, r.size), Color(0.85, 0.85, 0.85))
			else:
				draw_rect(r, Color(0.5, 0.5, 0.5))
			draw_rect(r, Color(0.2, 0.2, 0.2), false, 2.0)
		"kum":
			var res := _uretilen_resim("kum_torbasi")
			if res:
				draw_texture_rect(res, r.grow(4), false)
			else:
				_kum_ciz(r)
		"sandik":
			var res := _uretilen_resim("sandik")
			if res:
				draw_texture_rect(res, r.grow(3), false)
			else:
				var tah := _doku("planks")
				if tah:
					draw_texture_rect_region(tah, r, Rect2(r.position * 2.0, r.size * 2.0), Color(0.95, 0.85, 0.65))
				else:
					draw_rect(r, Color(0.55, 0.4, 0.22))
				draw_rect(r, Color(0.25, 0.17, 0.08), false, 3.0)
				draw_line(r.position, r.end, Color(0.25, 0.17, 0.08, 0.8), 3.0)
				draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(0.25, 0.17, 0.08, 0.8), 3.0)
		"tank":
			var res := _uretilen_resim("tank_enkazi")
			if res:
				draw_texture_rect(res, r.grow(10), false)
			else:
				_tank_ciz(r)


func _kum_ciz(r: Rect2) -> void:
	var yatay := r.size.x >= r.size.y
	var uz := r.size.x if yatay else r.size.y
	var n := maxi(2, int(uz / 26.0))
	var boy := uz / n
	for i in n:
		var p: Vector2 = r.position + (Vector2(i * boy, 0) if yatay else Vector2(0, i * boy))
		var k := Rect2(p, Vector2(boy, r.size.y) if yatay else Vector2(r.size.x, boy)).grow(-1.5)
		var ton := 0.92 + 0.08 * sin(i * 2.3)
		draw_rect(k, Color(0.72 * ton, 0.63 * ton, 0.45 * ton))
		draw_rect(k, Color(0.4, 0.33, 0.2), false, 1.5)
		draw_line(k.get_center() - (Vector2(boy * 0.3, 0) if yatay else Vector2(0, boy * 0.3)),
			k.get_center() + (Vector2(boy * 0.3, 0) if yatay else Vector2(0, boy * 0.3)), Color(0.55, 0.47, 0.32), 1.0)


func _tank_ciz(r: Rect2) -> void:
	var met := _doku("metal")
	var govde := r.grow_individual(0, -12, 0, -12)
	# paletler
	draw_rect(Rect2(r.position, Vector2(r.size.x, 16)), Color(0.15, 0.14, 0.12))
	draw_rect(Rect2(Vector2(r.position.x, r.end.y - 16), Vector2(r.size.x, 16)), Color(0.15, 0.14, 0.12))
	for i in int(r.size.x / 12):
		draw_line(Vector2(r.position.x + i * 12, r.position.y), Vector2(r.position.x + i * 12, r.position.y + 16), Color(0.3, 0.28, 0.24), 2)
		draw_line(Vector2(r.position.x + i * 12, r.end.y - 16), Vector2(r.position.x + i * 12, r.end.y), Color(0.3, 0.28, 0.24), 2)
	if met:
		draw_texture_rect_region(met, govde, Rect2(Vector2.ZERO, govde.size), Color(0.45, 0.42, 0.33))
	else:
		draw_rect(govde, Color(0.33, 0.31, 0.25))
	var c := r.get_center()
	draw_circle(c, 28, Color(0.22, 0.2, 0.17))
	draw_circle(c, 24, Color(0.38, 0.35, 0.28))
	draw_line(c, c + Vector2(r.size.x * 0.55, -6), Color(0.2, 0.18, 0.15), 9)
	# yanık izleri
	draw_circle(c + Vector2(-38, 8), 14, Color(0.05, 0.05, 0.05, 0.5))
	draw_circle(c + Vector2(30, -12), 9, Color(0.05, 0.05, 0.05, 0.45))


func agaclari_ciz(ci: CanvasItem) -> void:
	## Ağaç tepeleri askerlerin üstünde çizilir (ayrı katman çağırır).
	var res := _uretilen_resim("agac")
	for a in agaclar:
		var p: Vector2 = a["p"]
		var r: float = a["r"]
		if res:
			ci.draw_texture_rect(res, Rect2(p - Vector2(r, r) * 1.25, Vector2(r, r) * 2.5), false, Color(1, 1, 1, 0.92))
			continue
		ci.draw_circle(p, r, Color(0.16, 0.3, 0.13, 0.93))
		ci.draw_circle(p + Vector2(-r * 0.3, -r * 0.25), r * 0.6, Color(0.22, 0.4, 0.17, 0.93))
		ci.draw_circle(p + Vector2(r * 0.35, r * 0.2), r * 0.45, Color(0.19, 0.36, 0.15, 0.93))
		ci.draw_circle(p + Vector2(-r * 0.4, -r * 0.35), r * 0.25, Color(0.3, 0.5, 0.22, 0.8))
