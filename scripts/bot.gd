extends RefCounted
## Bot beyni. Oyuncuyla AYNI girdiyi üretir (hareket, nişan, ateş, bomba): botlar hile yapamaz, insanla yer değiştirebilir.
## Komando guard.gd'den alınan dersler:
##  - Algı: görüş konisi + görüş hattı (has_los) + koni dışında yakından fark etme + silah sesini duyma.
##  - Tepki gecikmesi ve nişan hatası zamanla azalır (ilk görüşte ölümcül değil: oyuncuya kaçma şansı).
##  - Yaralanınca siper alır (siper_noktasi), herkes aynı noktaya koşmaz (kusatma yönü "flank").
##  - Hedefi kaybedince son görülen yere ve hareket yönüne doğru arar (tahminli arama).
##  - Takılma tespiti: istediği halde ilerleyemiyorsa yan adım + yeniden yol.
##  - El bombası: hedef alçak siperin arkasındaysa ya da düşmanlar toplu duruyorsa.

const Ayar = preload("res://scripts/ayarlar.gd")

var a                       # Asker
var d                       # Dunya
var rng := RandomNumberGenerator.new()
var zorluk := 0.6           # 0..1
var hedef = null
var son_gorulen := Vector2.ZERO
var son_yon := Vector2.ZERO
var son_gorulen_t := -100.0
var duyulan := Vector2.ZERO
var duyulan_t := -100.0
var tepki_t := 0.0
var maruz_t := 0.0          # hedefe nişan alma süresi (hata azalır)
var yol := PackedVector2Array()
var yol_i := 0
var yol_hedef := Vector2.INF
var yol_t := 0.0
var serit := 0.5            # haritada hangi şeritten ilerler (y oranı)
var flank := 0.0
var yan := 1.0
var yan_t := 0.0
var siper = null
var siper_t := 0.0
var takili_t := 0.0
var son_p := Vector2.ZERO
var kacis_t := 0.0
var kacis_yon := Vector2.ZERO
var bomba_bekle := 0.0
var amac := Vector2.ZERO
var amac_t := 0.0
# istatistik (bot testi)
var takilma := 0


func _init(asker, dunya, tohum: int, _zorluk := 0.6) -> void:
	a = asker
	d = dunya
	rng.seed = tohum
	zorluk = _zorluk
	serit = [0.2, 0.5, 0.8, 0.35, 0.65][tohum % 5]
	flank = rng.randf_range(-1.0, 1.0)


func _istenen_mesafe() -> float:
	return [360.0, 190.0, 640.0, 420.0][a.sinif]


func _gorus_menzili() -> float:
	return 1000.0 if a.sinif == 2 else 760.0


func dusun(dt: float) -> Dictionary:
	var g := {"m": Vector2.ZERO, "a": a.aci, "f": false, "g": 0.0, "r": false}
	if a.olu:
		return g
	tepki_t -= dt
	yan_t -= dt
	yol_t -= dt
	siper_t -= dt
	bomba_bekle -= dt
	amac_t -= dt
	var ben: Vector2 = a.govde()
	# ---------------------------------------------------------------- algı
	var en = null
	var en_puan := INF
	for o in d.askerler.values():
		if o.takim == a.takim or o.olu:
			continue
		var p: Vector2 = o.govde()
		var mes := ben.distance_to(p)
		if mes > _gorus_menzili():
			continue
		var konide := absf(angle_difference(a.aci, (p - ben).angle())) < 1.15
		var yakin: bool = mes < 170.0 or (d.zaman - o.son_ates < 0.6 and mes < 520.0)
		if not (konide or yakin or o == hedef):
			continue
		if not d.harita.gorus_var(ben, p):
			continue
		var puan: float = mes + o.hp * 1.5 + (0.0 if o == hedef else 120.0)
		if puan < en_puan:
			en_puan = puan
			en = o
	if en != null:
		if en != hedef:
			tepki_t = rng.randf_range(0.18, 0.42) * (1.5 - zorluk)
			maruz_t = 0.0
		hedef = en
		son_yon = (en.position - son_gorulen).normalized() if son_gorulen != Vector2.ZERO else Vector2.ZERO
		son_gorulen = en.position
		son_gorulen_t = d.zaman
	elif hedef != null and (hedef.olu or d.zaman - son_gorulen_t > 0.4):
		hedef = null
	# ---------------------------------------------------------------- karar
	var hp_oran: float = a.hp / float(a.veri()["can"])
	var hedef_nokta := Vector2.INF
	var nisan: float = a.aci
	if hedef != null:
		var hp_: Vector2 = hedef.govde()
		var mes := ben.distance_to(hp_)
		maruz_t += dt
		var hata := lerpf(0.22, 0.02, clampf(maruz_t / (1.6 - zorluk), 0.0, 1.0)) * (1.25 - zorluk * 0.6)
		var on_tahmin: Vector2 = hedef.hareket * clampf(mes / 1600.0, 0.0, 0.25)   # hareketli hedefin önüne
		nisan = (hp_ + on_tahmin - ben).angle() + sin(d.zaman * 3.1 + flank * 7.0) * hata
		# yaralı: siper al
		if hp_oran < 0.45 and siper_t <= 0.0:
			siper = d.harita.siper_noktasi(a.position, hedef.position)
			siper_t = 2.5
		if siper != null and hp_oran < 0.6 and a.position.distance_to(siper) > 18.0:
			hedef_nokta = siper
		else:
			# çatışma hareketi: istenen mesafeyi koru, yanlara kay (strafe), kuşatma yönüne kay
			var dik := (hp_ - ben).normalized()
			if yan_t <= 0.0:
				yan = -yan if rng.randf() < 0.7 else yan
				yan_t = rng.randf_range(0.7, 1.6)
			var ileri := 0.0
			var ist := _istenen_mesafe()
			if mes > ist * 1.15:
				ileri = 1.0
			elif mes < ist * 0.7:
				ileri = -0.8
			var m := dik * ileri + dik.orthogonal() * (yan * 0.75 + flank * 0.25)
			if a.sinif == 2 and a.ates_t > 0.0 or a.sinif == 3 and mes < ist:
				m *= 0.25   # keskin nişancı ve ağır silah ateş ederken durur
			g["m"] = _engelden_kac(m.normalized() if m.length() > 0.01 else Vector2.ZERO)
		var dogru := absf(angle_difference(a.aci, nisan)) < 0.12 + (0.2 if a.sinif == 1 else 0.0)
		g["f"] = tepki_t <= 0.0 and mes < float(a.veri()["menzil"]) * 1.02 and dogru
		# bomba
		if a.bomba > 0 and bomba_bekle <= 0.0 and mes > 150.0 and mes < 380.0:
			var siperde: bool = d.harita.mermi_yolu(ben, hp_, d.rng_sabit) < 0.98
			var toplu := 0
			for o in d.askerler.values():
				if o.takim != a.takim and not o.olu and o.position.distance_to(hedef.position) < 130.0:
					toplu += 1
			if (siperde or toplu >= 2) and rng.randf() < 0.5:
				g["g"] = mes
				nisan = (hp_ - ben).angle()
			bomba_bekle = rng.randf_range(3.0, 7.0)
		if a.sarjor == 0:
			g["r"] = true
	else:
		if a.sarjor < int(a.veri()["sarjor"]) * 0.5:
			g["r"] = true   # sakinken doldur
		if d.zaman - son_gorulen_t < 6.0:
			hedef_nokta = son_gorulen + son_yon * 120.0   # tahminli arama
		elif d.zaman - duyulan_t < 5.0:
			hedef_nokta = duyulan
		else:
			if hp_oran < 0.5:
				var s = d.en_yakin_toplanan(a.position, "saglik")
				if s != null:
					hedef_nokta = s
			if hedef_nokta == Vector2.INF:
				if amac_t <= 0.0 or a.position.distance_to(amac) < 70.0:
					amac = _yeni_amac()
					amac_t = rng.randf_range(6.0, 12.0)
				hedef_nokta = amac
	if hedef_nokta != Vector2.INF:
		g["m"] = _yola_git(hedef_nokta)
		if hedef == null and g["m"].length() > 0.1:
			nisan = lerp_angle(a.aci, g["m"].angle(), 0.12)
	# takımdaşlardan ayrış (topaklanmasın)
	for o in d.askerler.values():
		if o != a and o.takim == a.takim and not o.olu:
			var f: Vector2 = a.position - o.position
			if f.length() < 46.0 and f.length() > 0.1:
				g["m"] += f.normalized() * (46.0 - f.length()) / 46.0
	# takılma
	var istiyor: bool = g["m"].length() > 0.3
	if istiyor and a.position.distance_to(son_p) < 1.2 * 60.0 * dt:
		takili_t += dt
	else:
		takili_t = maxf(0.0, takili_t - dt)
	son_p = a.position
	if takili_t > 0.9:
		takili_t = 0.0
		takilma += 1
		kacis_t = 0.5
		kacis_yon = Vector2.RIGHT.rotated(rng.randf() * TAU)
		yol_t = 0.0
		yol_hedef = Vector2.INF
	if kacis_t > 0.0:
		kacis_t -= dt
		g["m"] = kacis_yon
	if g["m"].length() > 1.0:
		g["m"] = g["m"].normalized()
	g["a"] = rotate_toward(a.aci, nisan, dt * lerpf(4.5, 9.0, zorluk))   # insan gibi dönüş hızı
	return g


func _yeni_amac() -> Vector2:
	var W: float = d.harita.W
	var H: float = d.harita.H
	var ileri := W * rng.randf_range(0.55, 0.85)
	var x := ileri if a.takim == 0 else W - ileri
	var y := clampf(H * serit + rng.randf_range(-160, 160), 80, H - 80)
	if rng.randf() < 0.3:
		return Vector2(W * 0.5, H * 0.5) + Vector2(rng.randf_range(-260, 260), rng.randf_range(-200, 200))
	return Vector2(x, y)


func _yola_git(p: Vector2) -> Vector2:
	if yol_t <= 0.0 or yol_hedef.distance_to(p) > 96.0 or yol_i >= yol.size():
		yol = d.harita.yol(a.position, p)
		yol_i = 1 if yol.size() > 1 else 0
		yol_hedef = p
		yol_t = 1.5
	while yol_i < yol.size() and a.position.distance_to(yol[yol_i]) < 22.0:
		yol_i += 1
	# görüşü açık sonraki noktaya kestirme (köşe kırpma)
	while yol_i + 1 < yol.size() and d.harita.gorus_var(a.position, yol[yol_i + 1]) and \
			not d.harita.yuruyemez(a.position.lerp(yol[yol_i + 1], 0.5), 17.0) and a.position.distance_to(yol[yol_i + 1]) < 200.0:
		yol_i += 1
	if yol_i >= yol.size():
		var f: Vector2 = p - a.position
		return f.normalized() if f.length() > 12.0 else Vector2.ZERO
	return (yol[yol_i] - a.position).normalized()


func _engelden_kac(m: Vector2) -> Vector2:
	if m == Vector2.ZERO:
		return m
	if not d.harita.yuruyemez(a.position + m * 30.0, 15.0):
		return m
	for aci in [0.6, -0.6, 1.2, -1.2, 2.0, -2.0]:
		var r := m.rotated(aci)
		if not d.harita.yuruyemez(a.position + r * 30.0, 15.0):
			return r
	return Vector2.ZERO


func duy(p: Vector2) -> void:
	if hedef == null:
		duyulan = p
		duyulan_t = d.zaman
