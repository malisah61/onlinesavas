extends Node2D
## Maç dünyası. İki kip:
##   "kurucu" – tüm simülasyonu yürütür (botlar dahil), anlık görüntü üretir. Tek oyunculu (botlara karşı) da budur.
##   "istemci" – yalnızca kurucudan gelen anlık görüntüleri gösterir; kendi askerini tahminle (prediction) yürütür.
## Ders (Efsane Kartlar): sonucu istemcide hesaplamak hile kapısıdır → burada hasar/ölüm/skor yalnız kurucuda.

signal mac_bitti(kazanan: int)
signal olum_oldu(katil: String, kurban: String, sinif: int)
signal mesaj(yazi: String)

const Ayar = preload("res://scripts/ayarlar.gd")
const Harita = preload("res://scripts/harita.gd")
const Asker = preload("res://scripts/asker.gd")
const Bot = preload("res://scripts/bot.gd")
const Fx = preload("res://scripts/fx.gd")
const Ses = preload("res://scripts/ses.gd")

var kip := "kurucu"
var harita: Harita
var katman: Node2D           # askerler (y sıralı)
var fx: Fx
var ustkatman: Node2D        # ağaç tepeleri
var askerler := {}           # id -> Asker
var yerel_id := ""
var zaman := 0.0
var kalan := Ayar.MAC_SURE
var skor := [0, 0]
var bitti := false
var bitis_t := 0.0
var bombalar: Array = []     # {"p","a","b","t","sahip","takim"}
var toplanacak: Array = []   # {"tur","p","var","t"}
var olaylar: Array = []      # bu görüntüde gönderilecek olaylar (yalnız ağ açıkken)
var ag_acik := false
var _bekleyen: Array = []    # kurucunun kendi ekranında gösterilecek olaylar
var rng := RandomNumberGenerator.new()
var rng_sabit := RandomNumberGenerator.new()
var bot_zorluk := 0.6
var gorunurluk := true       # takım görüşü (düşman yalnız takımın gördüğü yerde görünür)
var ses_acik := true
var _bot_say := 0
var _sayac := 0
# istemci
var _goruntu_t := 0.0        # son görüntünün kurucu zamanı
var _yerel_saat := 0.0
var _saat_fark := 0.0
var tohum := 0


func _init() -> void:
	harita = Harita.new()
	add_child(harita)
	katman = Node2D.new()
	katman.y_sort_enabled = true
	add_child(katman)
	fx = Fx.new()
	add_child(fx)
	ustkatman = Node2D.new()
	ustkatman.z_index = 5
	ustkatman.draw.connect(func(): harita.agaclari_ciz(ustkatman))
	add_child(ustkatman)


func baslat(t: int, insanlar: Array) -> void:
	## insanlar: [{"id","ad","sinif","sahip"}]
	tohum = t
	rng.seed = t
	rng_sabit.seed = t + 1
	harita.kur(t)
	ustkatman.queue_redraw()
	for a in askerler.values():
		a.queue_free()
	askerler.clear()
	bombalar.clear()
	skor = [0, 0]
	kalan = Ayar.MAC_SURE
	bitti = false
	zaman = 0.0
	toplanacak.clear()
	for x in harita.toplanan:
		toplanacak.append({"tur": x["tur"], "p": x["p"], "var": true, "t": 0.0})
	if kip != "kurucu":
		return
	var say := [0, 0]
	for i in insanlar.size():
		var h: Dictionary = insanlar[i]
		var tk := 0 if say[0] <= say[1] else 1
		if h.has("takim"):
			tk = h["takim"]
		say[tk] += 1
		_asker_ekle(h["id"], h["ad"], tk, h.get("sinif", 0), h.get("sahip", h["id"]))
	_botlari_doldur()


func _asker_ekle(id: String, ad: String, takim: int, sinif: int, sahip := "") -> Asker:
	var a := Asker.new()
	a.kur(id, ad, takim, sinif)
	a.sahip = sahip
	a.yerel = (id == yerel_id)
	katman.add_child(a)
	askerler[id] = a
	if kip == "kurucu":
		if sahip == "":
			a.bot = Bot.new(a, self, rng.randi() % 100000 + _bot_say * 7, bot_zorluk)
		_dogur(a)
	return a


func _botlari_doldur() -> void:
	for tk in 2:
		var n := 0
		for a in askerler.values():
			if a.takim == tk:
				n += 1
		while n < Ayar.TAKIM_BOYU:
			_bot_say += 1
			var ad: String = Ayar.BOT_ADLARI[(_bot_say * 5 + tk * 3) % Ayar.BOT_ADLARI.size()]
			_asker_ekle("b%d" % _bot_say, ad + " (bot)", tk, (_bot_say + tk) % Ayar.SINIFLAR.size())
			n += 1


func insan_ekle(id: String, ad: String, sinif: int) -> void:
	## Kurucu: katılan oyuncu, insanı az olan takımdaki bir botun yerini alır.
	if askerler.has(id):
		return
	var say := [0, 0]
	for a in askerler.values():
		if a.sahip != "":
			say[a.takim] += 1
	var tk := 0 if say[0] <= say[1] else 1
	for a in askerler.values():
		if a.takim == tk and a.sahip == "":
			askerler.erase(a.id)
			a.queue_free()
			break
	var yeni := _asker_ekle(id, ad, tk, sinif, id)
	_olay(["m", "%s katıldı (%s)" % [ad, Ayar.TAKIM_AD[tk]]])
	return


func insan_cikar(id: String) -> void:
	if not askerler.has(id):
		return
	var a: Asker = askerler[id]
	_olay(["m", "%s ayrıldı" % a.ad])
	askerler.erase(id)
	a.queue_free()
	_botlari_doldur()


func _dogur(a: Asker) -> void:
	var en := Vector2.ZERO
	var en_d := -1.0
	for p in harita.dogus[a.takim]:
		var md := INF
		for o in askerler.values():
			if o.takim != a.takim and not o.olu:
				md = minf(md, p.distance_to(o.position))
		md += rng.randf() * 60.0
		if md > en_d and not _dolu(p):
			en_d = md
			en = p
	if a.istenen >= 0 and a.istenen != a.sinif:
		a.sinif_ata(a.istenen)
	a.position = en
	a.olu = false
	a.hp = a.veri()["can"]
	a.sarjor = a.veri()["sarjor"]
	a.dolum_t = 0.0
	a.bomba = 2
	a.koruma_t = Ayar.KORUMA
	a.aci = 0.0 if a.takim == 0 else PI
	a.anim = Asker.BEKLE
	a.hasar_t = 10.0


func _dolu(p: Vector2) -> bool:
	for o in askerler.values():
		if not o.olu and o.position.distance_to(p) < 34.0:
			return true
	return false


# ===================================================================== kurucu simülasyonu

func adim(dt: float) -> void:
	zaman += dt
	if kip != "kurucu":
		return
	if bitti:
		bitis_t += dt
		return
	kalan -= dt
	for a in askerler.values():
		if a.bot != null:
			a.girdi = a.bot.dusun(dt)
		_asker_adim(a, dt)
	_bombalar_adim(dt)
	_toplanacak_adim(dt)
	if skor[0] >= Ayar.SKOR_HEDEF or skor[1] >= Ayar.SKOR_HEDEF or kalan <= 0.0:
		bitti = true
		bitis_t = 0.0
		var k := -1
		if skor[0] != skor[1]:
			k = 0 if skor[0] > skor[1] else 1
		_olay(["s", k])
		mac_bitti.emit(k)


func _asker_adim(a: Asker, dt: float) -> void:
	if a.olu:
		a.donus_t -= dt
		a.anim = Asker.OLUM
		if a.donus_t <= 0.0:
			_dogur(a)
		return
	var v: Dictionary = a.veri()
	var g: Dictionary = a.girdi
	a.koruma_t = maxf(0.0, a.koruma_t - dt)
	a.ates_t -= dt
	a.bomba_t -= dt
	a.hasar_t += dt
	if a.hasar_t > 5.0 and a.hp < v["can"]:
		a.hp = minf(v["can"], a.hp + 10.0 * dt)
	# hareket
	var m: Vector2 = g["m"]
	if m.length() > 1.0:
		m = m.normalized()
	var hiz: float = v["hiz"] * (0.6 if a.dolum_t > 0.0 and a.sinif == 3 else 1.0)
	var once := a.position
	a.position = harita.kaydir(a.position, m * hiz * dt)
	a.hareket = (a.position - once) / maxf(dt, 0.0001)
	a.aci = g["a"]
	# doldurma
	if a.dolum_t > 0.0:
		a.dolum_t -= dt
		if a.dolum_t <= 0.0:
			a.sarjor = v["sarjor"]
	elif (g["r"] and a.sarjor < v["sarjor"]) or a.sarjor <= 0:
		a.dolum_t = v["dolum"]
		_olay(["d", a.id])
	# ateş
	var atiyor := false
	if g["f"] and a.dolum_t <= 0.0 and a.sarjor > 0 and a.ates_t <= 0.0:
		_ates(a)
		atiyor = true
	# bomba
	if g["g"] > 0.0 and a.bomba > 0 and a.bomba_t <= 0.0:
		_bomba_at(a, g["g"])
	if a.hareket.length() > 10.0:
		a.anim = Asker.KOS if a.hareket.length() > 140.0 else Asker.YURU
	elif atiyor or a.ates_t > -0.25:
		a.anim = Asker.ATES
	else:
		a.anim = Asker.BEKLE


func _ates(a: Asker) -> void:
	var v: Dictionary = a.veri()
	a.ates_t = v["aralik"]
	a.sarjor -= 1
	a.koruma_t = 0.0
	a.son_ates = zaman
	var hareketli := a.hareket.length() > 20.0
	var sapma: float = v["sapma"] * (1.0 + (2.2 if a.sinif == 3 or a.sinif == 2 else 0.8) * float(hareketli))
	var aci: float = a.aci + rng.randfn(0.0, sapma)
	var bas := a.govde() + Vector2.RIGHT.rotated(a.aci) * 26.0
	var yon := Vector2.RIGHT.rotated(aci)
	var menzil: float = v["menzil"]
	var son := bas + yon * menzil
	var t_engel := harita.mermi_yolu(bas, son, rng)
	var vurulan = null
	var t_en := t_engel
	for o in askerler.values():
		if o.takim == a.takim or o.olu:
			continue
		var t := _isin_daire(bas, son, o.govde(), Asker.GOVDE_R)
		if t >= 0.0 and t < t_en:
			t_en = t
			vurulan = o
	var bitis := bas.lerp(son, t_en)
	_olay(["a", int(bas.x), int(bas.y), int(bitis.x), int(bitis.y), a.sinif, 1 if vurulan != null else 0, a.id])
	if vurulan != null:
		var mes := t_en * menzil
		var dus := 1.0 - clampf((mes - menzil * 0.6) / (menzil * 0.4), 0.0, 1.0) * 0.5
		_hasar(vurulan, v["hasar"] * dus, a)
	# ses: yakındaki botlar duyar
	for o in askerler.values():
		if o.bot != null and o.takim != a.takim and o.position.distance_to(a.position) < 650.0:
			o.bot.duy(a.position)


static func _isin_daire(a: Vector2, b: Vector2, c: Vector2, r: float) -> float:
	var d := b - a
	var f := a - c
	var aa := d.dot(d)
	var bb := 2.0 * f.dot(d)
	var cc := f.dot(f) - r * r
	var disk := bb * bb - 4.0 * aa * cc
	if disk < 0.0:
		return -1.0
	var t := (-bb - sqrt(disk)) / (2.0 * aa)
	return t if t >= 0.0 and t <= 1.0 else -1.0


func _hasar(o: Asker, miktar: float, kaynak: Asker) -> void:
	if o.olu or o.koruma_t > 0.0:
		return
	o.hp -= miktar
	o.hasar_t = 0.0
	o.vuran = kaynak.id if kaynak else ""
	if o.bot != null and kaynak != null and o.bot.hedef == null:
		o.bot.duy(kaynak.position)
		o.bot.son_gorulen = kaynak.position
		o.bot.son_gorulen_t = zaman
	if o.hp <= 0.0:
		o.hp = 0.0
		o.olu = true
		o.olum += 1
		o.donus_t = Ayar.DONUS_SURE
		o.anim = Asker.OLUM
		var ks := -1
		if kaynak != null and kaynak.takim != o.takim:
			kaynak.oldurme += 1
			skor[kaynak.takim] += 1
			ks = kaynak.sinif
		_olay(["o", kaynak.id if kaynak else "", o.id, ks])
		olum_oldu.emit(kaynak.id if kaynak else "", o.id, ks)


func _bomba_at(a: Asker, mesafe: float) -> void:
	a.bomba -= 1
	a.bomba_t = 1.0
	a.koruma_t = 0.0
	var bas := a.govde()
	var hedef := bas + Vector2.RIGHT.rotated(a.aci) * clampf(mesafe, 90.0, 380.0)
	bombalar.append({"p": bas, "a": bas, "b": hedef, "t": 0.0, "sahip": a.id, "takim": a.takim})
	_olay(["t", a.id])


func _bombalar_adim(dt: float) -> void:
	for b in bombalar:
		b["t"] += dt
		var k := clampf(b["t"] / 0.65, 0.0, 1.0)
		var yeni: Vector2 = b["a"].lerp(b["b"], k)
		if k < 1.0:
			# yüksek duvara çarparsa olduğu yerde düşer
			for e in harita.engeller:
				if e["yuksek"] and (e["r"] as Rect2).has_point(yeni):
					b["b"] = b["p"]
					b["a"] = b["p"]
					b["t"] = 0.65
					yeni = b["p"]
					break
		b["p"] = yeni
		if b["t"] >= 1.9:
			_patlat(b)
	bombalar = bombalar.filter(func(b): return b["t"] < 1.9)


func _patlat(b: Dictionary) -> void:
	var p: Vector2 = b["p"]
	_olay(["b", int(p.x), int(p.y)])
	var sahip = askerler.get(b["sahip"])
	for o in askerler.values():
		if o.olu:
			continue
		var d: float = o.govde().distance_to(p)
		if d > 150.0 or not harita.gorus_var(p, o.govde()):
			continue
		if o.takim == b["takim"] and o != sahip:
			continue
		var h := 125.0 * pow(1.0 - d / 150.0, 0.7)
		if o == sahip:
			h *= 0.5
		_hasar(o, h, sahip if sahip != o else null)
	for o in askerler.values():
		if o.bot != null and o.position.distance_to(p) < 900.0:
			o.bot.duy(p)


func _toplanacak_adim(dt: float) -> void:
	for i in toplanacak.size():
		var x: Dictionary = toplanacak[i]
		if not x["var"]:
			x["t"] -= dt
			if x["t"] <= 0.0:
				x["var"] = true
			continue
		for a in askerler.values():
			if a.olu or a.position.distance_to(x["p"]) > 30.0:
				continue
			if x["tur"] == "saglik" and a.hp < a.veri()["can"]:
				a.hp = minf(a.veri()["can"], a.hp + 60.0)
			elif x["tur"] == "bomba" and a.bomba < 3:
				a.bomba = mini(3, a.bomba + 2)
			else:
				continue
			x["var"] = false
			x["t"] = 25.0
			_olay(["p", a.id])
			break


func en_yakin_toplanan(p: Vector2, tur: String):
	var en = null
	var en_d := 900.0
	for x in toplanacak:
		if x["var"] and x["tur"] == tur:
			var d: float = p.distance_to(x["p"])
			if d < en_d:
				en_d = d
				en = x["p"]
	return en


# ===================================================================== ağ: anlık görüntü

func _olay(e: Array) -> void:
	if ag_acik:
		olaylar.append(e)
	_bekleyen.append(e)


func goruntu() -> Dictionary:
	var liste: Array = []
	for a in askerler.values():
		liste.append([a.id, int(a.position.x), int(a.position.y), int(rad_to_deg(a.aci)), a.anim, int(ceil(a.hp)), a.takim, a.sinif,
			a.ad, 1 if a.olu else 0, 1 if a.koruma_t > 0.0 else 0, a.oldurme, a.olum, a.sahip, a.sarjor, a.bomba,
			1 if a.dolum_t > 0.0 else 0, snappedf(a.donus_t, 0.1)])
	var bm: Array = []
	for b in bombalar:
		bm.append([int(b["p"].x), int(b["p"].y), int(_bomba_yukseklik(b))])
	var tp := ""
	for x in toplanacak:
		tp += "1" if x["var"] else "0"
	var g := {"z": zaman, "h": tohum, "k": int(kalan), "sk": skor, "bt": 1 if bitti else 0, "a": liste, "bm": bm, "tp": tp, "e": olaylar}
	olaylar = []
	return g


static func _bomba_yukseklik(b: Dictionary) -> float:
	var k := clampf(b["t"] / 0.65, 0.0, 1.0)
	return sin(k * PI) * 46.0


func goruntu_uygula(g: Dictionary) -> void:
	## İstemci: kurucunun gönderdiği durumu uygula.
	if int(g["h"]) != tohum:
		kip = "istemci"
		baslat(int(g["h"]), [])
	var t: float = g["z"]
	if t < _goruntu_t:
		return
	_goruntu_t = t
	var simdi := Time.get_ticks_msec() / 1000.0
	_saat_fark = lerpf(_saat_fark, t - simdi, 0.2) if _saat_fark != 0.0 else t - simdi
	zaman = t
	kalan = g["k"]
	skor = [int(g["sk"][0]), int(g["sk"][1])]
	var once_bitti := bitti
	bitti = g["bt"] == 1
	var gelen := {}
	for x in g["a"]:
		var id: String = x[0]
		gelen[id] = true
		var a: Asker = askerler.get(id)
		if a == null:
			a = Asker.new()
			a.kur(id, x[8], x[6], x[7])
			a.yerel = (id == yerel_id)
			katman.add_child(a)
			askerler[id] = a
			a.position = Vector2(x[1], x[2])
		if a.takim != x[6]:
			a.takim = x[6]
		if a.sinif != x[7]:
			a.sinif_ata(x[7])
		a.ad = x[8]
		var p := Vector2(x[1], x[2])
		var aci := deg_to_rad(x[3])
		var olmustu := a.olu
		a.olu = x[9] == 1
		if a.yerel:
			# kendi askerim: tahmin edilen konumu kurucunun konumuna yumuşakça çek
			var fark := p.distance_to(a.position)
			if fark > 90.0 or a.olu or olmustu != a.olu:
				a.position = p
			elif fark > 4.0:
				a.position = a.position.lerp(p, 0.12)
		else:
			a.tampona_ekle(t, p, aci)
			a.anim = x[4]
		var hp_once := a.hp
		a.hp = x[5]
		if a.hp < hp_once - 0.5 and not a.olu:
			a.vuruldu()
		a.koruma_t = 1.0 if x[10] == 1 else 0.0
		a.oldurme = x[11]
		a.olum = x[12]
		a.sahip = x[13]
		a.sarjor = x[14]
		a.bomba = x[15]
		a.dolum_t = 1.0 if x[16] == 1 else 0.0
		a.donus_t = x[17]
		if a.yerel:
			a.anim = x[4] if a.olu else a.anim
	for id in askerler.keys():
		if not gelen.has(id):
			askerler[id].queue_free()
			askerler.erase(id)
	fx.bombalar.clear()
	for b in g["bm"]:
		fx.bombalar.append([Vector2(b[0], b[1]), float(b[2])])
	var tp: String = g["tp"]
	for i in mini(tp.length(), toplanacak.size()):
		toplanacak[i]["var"] = tp[i] == "1"
	for e in g["e"]:
		olay_goster(e)
	if bitti and not once_bitti:
		var k := -1
		if skor[0] != skor[1]:
			k = 0 if skor[0] > skor[1] else 1
		mac_bitti.emit(k)


func olay_goster(e: Array) -> void:
	## Olayların görsel/işitsel karşılığı (kurucu kendi olaylarını da buradan gösterir).
	match e[0]:
		"a":
			var a := Vector2(e[1], e[2])
			var b := Vector2(e[3], e[4])
			var s: int = e[5]
			fx.iz(a, b, Color(1, 0.95, 0.7) if s != 2 else Color(1, 1, 1))
			fx.toz(b, (a - b).normalized(), e[6] == 1)
			var at: Asker = askerler.get(e[7])
			if at:
				at.ates_etti()
				if at.yerel or kip == "istemci":
					at.son_ates = zaman
			if ses_acik:
				Ses.cal(self, ["tufek", "makineli", "keskin", "agir"][s], a, -10.0 if s == 1 or s == 3 else -6.0)
				if e[6] == 1:
					Ses.cal(self, "vurus", b, -12.0)
		"b":
			fx.patla(Vector2(e[1], e[2]))
			if ses_acik:
				Ses.cal(self, "patlama", Vector2(e[1], e[2]), -2.0)
		"d":
			var a: Asker = askerler.get(e[1])
			if a and a.yerel and ses_acik:
				Ses.cal(self, "dolum", a.position, -8.0)
		"p":
			var a: Asker = askerler.get(e[1])
			if a and a.yerel and ses_acik:
				Ses.cal(self, "al", a.position, -6.0)
		"o":
			if kip == "istemci":
				olum_oldu.emit(e[1], e[2], e[3])
		"m":
			mesaj.emit(e[1])


func girdi_al(id: String, v: Dictionary) -> void:
	## Kurucu: ağdan gelen oyuncu girdisi. {"m":[x,y], "a":derece, "f":0/1, "g":mesafe, "r":0/1, "k":sınıf}
	var a: Asker = askerler.get(id)
	if a == null:
		return
	var m: Array = v.get("m", [0, 0])
	a.girdi = {"m": Vector2(float(m[0]), float(m[1])).limit_length(1.0), "a": deg_to_rad(float(v.get("a", 0))),
		"f": int(v.get("f", 0)) == 1, "g": float(v.get("g", 0)), "r": int(v.get("r", 0)) == 1}
	if v.has("k"):
		a.istenen = clampi(int(v["k"]), 0, Ayar.SINIFLAR.size() - 1)


func yerel_tahmin(g: Dictionary, dt: float) -> void:
	## İstemci: kendi askerimi beklemeden hareket ettir (kurucu sonra düzeltir).
	var a: Asker = askerler.get(yerel_id)
	if a == null or a.olu:
		return
	var once := a.position
	a.position = harita.kaydir(a.position, (g["m"] as Vector2).limit_length(1.0) * float(a.veri()["hiz"]) * dt)
	a.hareket = (a.position - once) / maxf(dt, 0.0001)
	a.aci = g["a"]
	if a.hareket.length() > 10.0:
		a.anim = Asker.KOS if a.hareket.length() > 140.0 else Asker.YURU
	elif g["f"]:
		a.anim = Asker.ATES
	else:
		a.anim = Asker.BEKLE


func kurucuya_gec(canli_uyeler: Dictionary) -> void:
	## Kurucu ayrıldı, ben devralıyorum: son görüntüden simülasyona devam.
	kip = "kurucu"
	for a in askerler.values():
		a._tampon.clear()
		if a.sahip == "" or not canli_uyeler.has(a.sahip):
			a.sahip = ""
			if a.bot == null:
				a.bot = Bot.new(a, self, rng.randi() % 100000, bot_zorluk)
		a.ates_t = 0.0
		a.koruma_t = 0.0
		if a.sarjor <= 0:
			a.sarjor = a.veri()["sarjor"]
	bombalar.clear()


# ===================================================================== her kare (görünüm)

func _process(dt: float) -> void:
	if kip == "istemci":
		var t := Time.get_ticks_msec() / 1000.0 + _saat_fark - 0.13   # 130 ms geride oynat (yumuşak)
		for a in askerler.values():
			if not a.yerel:
				a.ara_deger(t)
	else:
		fx.bombalar.clear()
		for b in bombalar:
			fx.bombalar.append([b["p"], _bomba_yukseklik(b)])
		for e in _bekleyen:
			if e[0] != "o":
				olay_goster(e)
		_bekleyen.clear()
		_sayac += 1
	# takım görüşü: düşman yalnızca takımdan biri görüyorsa (ya da yeni ateş ettiyse) görünür
	var ben: Asker = askerler.get(yerel_id)
	var benim_takim: int = ben.takim if ben else -1
	for a in askerler.values():
		var gor := true
		if gorunurluk and benim_takim >= 0 and a.takim != benim_takim and not a.olu:
			gor = zaman - a.son_ates < 0.35
			if not gor:
				for o in askerler.values():
					if o.takim == benim_takim and not o.olu and o.position.distance_to(a.position) < 950.0 \
							and harita.gorus_var(o.govde(), a.govde()):
						gor = true
						break
		a.gorunur = gor
		a.visible = gor or a.olu
		a.gorunum(dt)
	queue_redraw()


func _draw() -> void:
	# toplanacaklar
	for x in toplanacak:
		if not x["var"]:
			continue
		var p: Vector2 = x["p"]
		var parl := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 250.0)
		draw_circle(p + Vector2(3, 4), 15, Color(0, 0, 0, 0.3))
		if x["tur"] == "saglik":
			draw_rect(Rect2(p - Vector2(14, 11), Vector2(28, 22)), Color(0.85, 0.85, 0.8))
			draw_rect(Rect2(p - Vector2(3.5, 8), Vector2(7, 16)), Color(0.85, 0.1, 0.1))
			draw_rect(Rect2(p - Vector2(8, 3.5), Vector2(16, 7)), Color(0.85, 0.1, 0.1))
		else:
			draw_circle(p, 9, Color(0.25, 0.32, 0.18))
			draw_rect(Rect2(p + Vector2(-3, -14), Vector2(6, 6)), Color(0.5, 0.5, 0.45))
		draw_arc(p, 20, 0, TAU, 24, Color(1, 1, 0.6, 0.35 * parl), 2.0)
