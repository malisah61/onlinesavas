extends CanvasLayer
## Ekran arayüzü + girdi. Telefonda iki sanal çubuk (sol: yürü, sağ: nişan; çubuk %55'ten fazla itilince ateş),
## bomba / doldur / skor düğmeleri. PC'de WASD + fare (sol tık ateş, sağ tık ya da G bomba, R doldur, Tab skor).
## Ders (Kule Savunma): oyuncu geniş (20:9) telefonda oynuyor → her şey kenarlara çapalı, ortası boş.

signal cikis_istendi
signal sinif_secildi(s: int)

const Ayar = preload("res://scripts/ayarlar.gd")

var dunya
var kamera: Camera2D
var girdi := {"m": Vector2.ZERO, "a": 0.0, "f": false, "g": 0.0, "r": false}
var dokunmatik := false
var _sol := {"i": -1, "merkez": Vector2.ZERO, "p": Vector2.ZERO}
var _sag := {"i": -1, "merkez": Vector2.ZERO, "p": Vector2.ZERO}
var _bomba_bas := false
var _fare_bomba := false
var _skor_acik := false
var _akis: Array = []        # [metin, süre]
var _mesajlar: Array = []
var _bitis_yazi := ""
var istenen_sinif := 0
var ciz: Control
var kok: Control
var _btn_bomba: Button
var _btn_dolum: Button
var _sinif_kutu: HBoxContainer
var _sinif_btn: Array = []
var durum_yazi := ""          # sağ üst küçük (ağ durumu)
const CUBUK_R := 70.0


func _ready() -> void:
	layer = 10
	dokunmatik = DisplayServer.is_touchscreen_available()
	kok = Control.new()
	kok.set_anchors_preset(Control.PRESET_FULL_RECT)
	kok.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(kok)
	ciz = Control.new()
	ciz.set_anchors_preset(Control.PRESET_FULL_RECT)
	ciz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ciz.draw.connect(_ciz)
	kok.add_child(ciz)
	_btn_bomba = _dugme("BOMBA", Vector2(-200, -260), Vector2(96, 96), func(): _bomba_bas = true)
	_btn_dolum = _dugme("DOLDUR", Vector2(-310, -150), Vector2(92, 64), func(): girdi["r"] = true)
	_dugme("MENÜ", Vector2(-92, 12), Vector2(80, 48), func(): cikis_istendi.emit(), true)
	_dugme("SKOR", Vector2(-180, 12), Vector2(80, 48), func(): _skor_acik = not _skor_acik, true)
	_btn_bomba.visible = dokunmatik
	_btn_dolum.visible = dokunmatik
	# ölünce sınıf seçimi
	_sinif_kutu = HBoxContainer.new()
	_sinif_kutu.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sinif_kutu.position = Vector2(-330, -150)
	_sinif_kutu.add_theme_constant_override("separation", 10)
	kok.add_child(_sinif_kutu)
	for i in Ayar.SINIFLAR.size():
		var b := Button.new()
		b.text = "%s\n%s" % [Ayar.SINIFLAR[i]["ad"], Ayar.SINIFLAR[i]["silah"]]
		b.custom_minimum_size = Vector2(150, 70)
		b.add_theme_font_size_override("font_size", 17)
		b.toggle_mode = true
		var k := i
		b.pressed.connect(func(): _sinif_sec(k))
		_sinif_kutu.add_child(b)
		_sinif_btn.append(b)
	_sinif_kutu.visible = false


func _dugme(yazi: String, konum: Vector2, boy: Vector2, f: Callable, ust := false) -> Button:
	var b := Button.new()
	b.text = yazi
	b.add_theme_font_size_override("font_size", 18)
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT if ust else Control.PRESET_BOTTOM_RIGHT)
	b.position = konum
	b.size = boy
	b.focus_mode = Control.FOCUS_NONE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.12, 0.08, 0.55)
	st.set_corner_radius_all(int(boy.x * 0.5) if not ust else 10)
	st.border_color = Color(1, 1, 1, 0.35)
	st.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	b.button_down.connect(f)
	kok.add_child(b)
	return b


func _sinif_sec(k: int) -> void:
	istenen_sinif = k
	for i in _sinif_btn.size():
		_sinif_btn[i].button_pressed = (i == k)
	sinif_secildi.emit(k)


func ayarla_sinif(k: int) -> void:
	istenen_sinif = k
	for i in _sinif_btn.size():
		_sinif_btn[i].button_pressed = (i == k)


func akis_ekle(metin: String) -> void:
	_akis.append([metin, 5.0])
	if _akis.size() > 5:
		_akis.pop_front()


func mesaj(metin: String, sure := 3.0) -> void:
	_mesajlar = [[metin, sure]]


func bitis(metin: String) -> void:
	_bitis_yazi = metin


# ------------------------------------------------------------------ girdi

func _input(e: InputEvent) -> void:
	var ekran := kok.get_viewport_rect().size
	if e is InputEventScreenTouch:
		dokunmatik = true
		_btn_bomba.visible = true
		_btn_dolum.visible = true
		if e.pressed:
			if _dugme_ustunde(e.position):
				return
			if e.position.x < ekran.x * 0.45 and _sol["i"] == -1:
				_sol = {"i": e.index, "merkez": e.position, "p": e.position}
			elif e.position.x >= ekran.x * 0.45 and _sag["i"] == -1:
				_sag = {"i": e.index, "merkez": e.position, "p": e.position}
		else:
			if e.index == _sol["i"]:
				_sol["i"] = -1
			if e.index == _sag["i"]:
				_sag["i"] = -1
	elif e is InputEventScreenDrag:
		if e.index == _sol["i"]:
			_sol["p"] = e.position
		if e.index == _sag["i"]:
			_sag["p"] = e.position
	elif e is InputEventMouseButton and not dokunmatik:
		if e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			_fare_bomba = true
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_G:
				_fare_bomba = true
			KEY_R:
				girdi["r"] = true
			KEY_TAB:
				_skor_acik = not _skor_acik
			KEY_1, KEY_2, KEY_3, KEY_4:
				_sinif_sec(e.keycode - KEY_1)


func _dugme_ustunde(p: Vector2) -> bool:
	for b in [_btn_bomba, _btn_dolum]:
		if b.visible and b.get_global_rect().grow(8).has_point(p):
			return true
	for c in kok.get_children():
		if c is Button and c.visible and c.get_global_rect().has_point(p):
			return true
	if _sinif_kutu.visible and _sinif_kutu.get_global_rect().has_point(p):
		return true
	return false


func girdi_hesapla(ben) -> Dictionary:
	## Her kare: yerel oyuncunun girdisi.
	var g := {"m": Vector2.ZERO, "a": girdi["a"], "f": false, "g": 0.0, "r": girdi["r"]}
	girdi["r"] = false
	if dokunmatik:
		if _sol["i"] != -1:
			var v: Vector2 = (_sol["p"] - _sol["merkez"]) / CUBUK_R
			g["m"] = v.limit_length(1.0) if v.length() > 0.12 else Vector2.ZERO
		if _sag["i"] != -1:
			var v: Vector2 = (_sag["p"] - _sag["merkez"]) / CUBUK_R
			if v.length() > 0.15:
				g["a"] = _nisan_yardimi(ben, v.angle())
				g["f"] = v.length() > 0.55
		elif g["m"].length() > 0.2:
			g["a"] = lerp_angle(girdi["a"], g["m"].angle(), 0.15)
		if _bomba_bas:
			_bomba_bas = false
			var v: Vector2 = (_sag["p"] - _sag["merkez"]) / CUBUK_R if _sag["i"] != -1 else Vector2.ZERO
			g["g"] = 160.0 + v.limit_length(1.0).length() * 220.0
	else:
		var m := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): m.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): m.y += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): m.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): m.x += 1
		g["m"] = m.normalized()
		if ben and kamera:
			var fare := kamera.get_global_mouse_position()
			g["a"] = (fare - ben.govde()).angle()
			g["f"] = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			if _fare_bomba:
				g["g"] = fare.distance_to(ben.govde())
		_fare_bomba = false
	girdi["a"] = g["a"]
	return g


func _nisan_yardimi(ben, aci: float) -> float:
	## Dokunmatikte hafif nişan mıknatısı: 10° içindeki görünen en yakın düşmana çeker.
	if ben == null or dunya == null:
		return aci
	var en := aci
	var en_f := 0.18
	for o in dunya.askerler.values():
		if o.takim == ben.takim or o.olu or not o.gorunur:
			continue
		var y: Vector2 = o.govde() - ben.govde()
		if y.length() > float(ben.veri()["menzil"]):
			continue
		var f := absf(angle_difference(aci, y.angle()))
		if f < en_f:
			en_f = f
			en = y.angle()
	return lerp_angle(aci, en, 0.6)


func _process(dt: float) -> void:
	for x in _akis:
		x[1] -= dt
	_akis = _akis.filter(func(x): return x[1] > 0)
	for x in _mesajlar:
		x[1] -= dt
	_mesajlar = _mesajlar.filter(func(x): return x[1] > 0)
	var ben = dunya.askerler.get(dunya.yerel_id) if dunya else null
	_sinif_kutu.visible = ben != null and ben.olu and not dunya.bitti
	ciz.queue_redraw()


# ------------------------------------------------------------------ çizim

func _yazi(p: Vector2, s: String, boy := 18, renk := Color.WHITE, hiza := HORIZONTAL_ALIGNMENT_LEFT, gen := -1.0) -> void:
	var f := ThemeDB.fallback_font
	ciz.draw_string(f, p + Vector2(1.5, 1.5), s, hiza, gen, boy, Color(0, 0, 0, 0.75))
	ciz.draw_string(f, p, s, hiza, gen, boy, renk)


func _ciz() -> void:
	if dunya == null:
		return
	var ekran := ciz.size
	var ben = dunya.askerler.get(dunya.yerel_id)
	# skor
	var orta := ekran.x * 0.5
	ciz.draw_rect(Rect2(orta - 150, 8, 300, 46), Color(0, 0, 0, 0.45))
	_yazi(Vector2(orta - 145, 42), str(dunya.skor[0]), 30, Ayar.TAKIM_RENK[0], HORIZONTAL_ALIGNMENT_LEFT, 90)
	_yazi(Vector2(orta + 55, 42), str(dunya.skor[1]), 30, Ayar.TAKIM_RENK[1], HORIZONTAL_ALIGNMENT_RIGHT, 90)
	var k := maxi(0, int(dunya.kalan))
	_yazi(Vector2(orta - 60, 40), "%d:%02d" % [k / 60, k % 60], 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 120)
	_yazi(Vector2(orta - 60, 72), "Hedef %d" % Ayar.SKOR_HEDEF, 13, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 120)
	# öldürme akışı
	var y := 90.0
	for x in _akis:
		_yazi(Vector2(ekran.x - 470, y), x[0], 16, Color(1, 1, 1, clampf(x[1], 0, 1)), HORIZONTAL_ALIGNMENT_RIGHT, 450)
		y += 22
	if durum_yazi != "":
		_yazi(Vector2(ekran.x - 470, 82 - 12), durum_yazi, 12, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, 300)
	# mini harita
	_mini_harita(Rect2(12, 12, 192, 115), ben)
	# can / cephane
	if ben:
		var v: Dictionary = ben.veri()
		var cy := ekran.y - 70.0 if not dokunmatik else 150.0
		var cx := 20.0 if not dokunmatik else 220.0
		ciz.draw_rect(Rect2(cx, cy, 240, 18), Color(0, 0, 0, 0.5))
		var oran := clampf(ben.hp / float(v["can"]), 0, 1)
		ciz.draw_rect(Rect2(cx, cy, 240 * oran, 18), Color(0.3, 0.85, 0.35).lerp(Color(0.95, 0.2, 0.2), 1.0 - oran))
		_yazi(Vector2(cx + 6, cy + 15), "%d" % int(ben.hp), 15)
		var c := "DOLDURULUYOR..." if ben.dolum_t > 0.0 else "%d / %d" % [ben.sarjor, v["sarjor"]]
		_yazi(Vector2(cx, cy + 42), "%s  ·  %s   ·  Bomba ×%d" % [v["silah"], c, ben.bomba], 17)
	# sanal çubuklar
	if dokunmatik:
		for c in [_sol, _sag]:
			if c["i"] != -1:
				ciz.draw_circle(c["merkez"], CUBUK_R, Color(1, 1, 1, 0.12))
				ciz.draw_arc(c["merkez"], CUBUK_R, 0, TAU, 40, Color(1, 1, 1, 0.4), 2.0)
				if c == _sag:
					ciz.draw_arc(c["merkez"], CUBUK_R * 0.55, 0, TAU, 32, Color(1, 0.4, 0.3, 0.45), 2.0)
				ciz.draw_circle(c["merkez"] + (c["p"] - c["merkez"]).limit_length(CUBUK_R), 30, Color(1, 1, 1, 0.35))
		if _sol["i"] == -1:
			_yazi(Vector2(40, ekran.y - 30), "< yürü", 15, Color(1, 1, 1, 0.35))
		if _sag["i"] == -1:
			_yazi(Vector2(ekran.x - 170, ekran.y - 30), "nişan / ateş >", 15, Color(1, 1, 1, 0.35))
	# ölüm
	if ben and ben.olu and not dunya.bitti:
		_yazi(Vector2(0, ekran.y * 0.32), "VURULDUN", 44, Color(1, 0.4, 0.35), HORIZONTAL_ALIGNMENT_CENTER, ekran.x)
		_yazi(Vector2(0, ekran.y * 0.32 + 40), "%.1f sn sonra yeniden doğacaksın — sınıf seç:" % maxf(0.0, ben.donus_t), 20,
			Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, ekran.x)
	for x in _mesajlar:
		_yazi(Vector2(0, ekran.y * 0.22), x[0], 26, Color(1, 0.95, 0.7, clampf(x[1], 0, 1)), HORIZONTAL_ALIGNMENT_CENTER, ekran.x)
	if _skor_acik or dunya.bitti:
		_skor_tablosu(ekran)


func _mini_harita(r: Rect2, ben) -> void:
	var h = dunya.harita
	var k: float = r.size.x / h.W
	ciz.draw_rect(r, Color(0.12, 0.18, 0.1, 0.7))
	for e in h.engeller:
		var er: Rect2 = e["r"]
		ciz.draw_rect(Rect2(r.position + er.position * k, er.size * k), Color(0.7, 0.6, 0.5, 0.8) if e["yuksek"] else Color(0.6, 0.55, 0.4, 0.6))
	for a in dunya.askerler.values():
		if a.olu or not a.gorunur:
			continue
		var c: Color = Ayar.TAKIM_RENK[a.takim]
		ciz.draw_circle(r.position + a.position * k, 3.5 if a == ben else 2.5, Color.WHITE if a == ben else c)
	if kamera:
		var g: Vector2 = kamera.get_viewport_rect().size / kamera.zoom
		ciz.draw_rect(Rect2(r.position + (kamera.get_screen_center_position() - g * 0.5) * k, g * k), Color(1, 1, 1, 0.3), false, 1.0)
	ciz.draw_rect(r, Color(1, 1, 1, 0.35), false, 1.5)


func _skor_tablosu(ekran: Vector2) -> void:
	var w := 620.0
	var r := Rect2(ekran.x * 0.5 - w * 0.5, 100, w, 330)
	ciz.draw_rect(r, Color(0, 0, 0, 0.72))
	if _bitis_yazi != "" and dunya.bitti:
		_yazi(Vector2(r.position.x, r.position.y - 14), _bitis_yazi, 30, Color(1, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER, w)
	for tk in 2:
		var x := r.position.x + 20 + tk * (w * 0.5)
		_yazi(Vector2(x, r.position.y + 34), "%s  %d" % [Ayar.TAKIM_AD[tk], dunya.skor[tk]], 22, Ayar.TAKIM_RENK[tk])
		_yazi(Vector2(x + 190, r.position.y + 34), "Ö / Ö", 14, Color(1, 1, 1, 0.6))
		var liste: Array = dunya.askerler.values().filter(func(a): return a.takim == tk)
		liste.sort_custom(func(a, b): return a.oldurme > b.oldurme)
		var y := r.position.y + 66
		for a in liste:
			var renk := Color.WHITE if a.id == dunya.yerel_id else Color(0.85, 0.85, 0.85)
			_yazi(Vector2(x, y), "%s  [%s]" % [a.ad.left(16), Ayar.SINIFLAR[a.sinif]["ad"]], 16, renk)
			_yazi(Vector2(x + 190, y), "%d / %d" % [a.oldurme, a.olum], 16, renk)
			y += 26
