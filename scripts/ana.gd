extends Node
## Ana akış: menü → (online / botlara karşı) maç → maç sonu → yeni maç.
## Arayüz tamamen koddan kurulur (Efsane Kartlar dersi: tek sahne, kolay bakım).

const Ayar = preload("res://scripts/ayarlar.gd")
const Dunya = preload("res://scripts/dunya.gd")
const Hud = preload("res://scripts/hud.gd")
const Ag = preload("res://scripts/ag.gd")
const Ses = preload("res://scripts/ses.gd")

const PROFIL := "user://profil.json"

var profil := {"ad": "", "cihaz": "", "sinif": 0, "ses": true}
var ag: Ag
var dunya: Dunya
var hud: Hud
var kamera: Camera2D
var menu: Control
var durum: Label
var ad_kutu: LineEdit
var kod_kutu: LineEdit
var sinif_btn: Array = []
var siralama_panel: PanelContainer

var oyunda := false
var online := false
var kurucu := false
var oda := ""
var kurucu_id := ""
var _goruntu_t := 0.0
var _girdi_t := 0.0
var _son_girdi := {}
var _kalp_t := 0.0
var _son_goruntu_alis := 0.0
var _yeni_mac_t := -1.0
var _rapor_gitti := false
var _baglanti_t := 0.0


func _ready() -> void:
	randomize()
	_profil_yukle()
	ag = Ag.new()
	add_child(ag)
	ag.kimlik = profil["cihaz"].left(10)
	ag.baglandi.connect(_ag_baglandi)
	ag.koptu.connect(_ag_koptu)
	ag.mesaj_geldi.connect(_ag_mesaj)
	ag.katilan.connect(_ag_katilan)
	ag.ayrilan.connect(_ag_ayrilan)
	_menu_kur()
	# bulut testleri: --bot-testi / --ag-testi ayrı betiklerde (tests/)


# ===================================================================== profil

func _profil_yukle() -> void:
	if FileAccess.file_exists(PROFIL):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PROFIL))
		if typeof(d) == TYPE_DICTIONARY:
			profil.merge(d, true)
	if profil["cihaz"] == "":
		var c := ""
		var harf := "abcdefghijkmnopqrstuvwxyz23456789"
		for i in 16:
			c += harf[randi() % harf.length()]
		profil["cihaz"] = c
	if profil["ad"] == "":
		profil["ad"] = "Asker%d" % (randi() % 9000 + 1000)
	Ses.acik = profil["ses"]
	_profil_kaydet()


func _profil_kaydet() -> void:
	var f := FileAccess.open(PROFIL, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(profil))


# ===================================================================== menü

func _menu_kur() -> void:
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var arka := ColorRect.new()
	arka.color = Color(0.11, 0.13, 0.09)
	arka.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(arka)
	var dekor := Control.new()
	dekor.set_anchors_preset(Control.PRESET_FULL_RECT)
	dekor.draw.connect(func():
		var s := dekor.size
		for i in 14:
			var x := fmod(i * 173.0, s.x)
			dekor.draw_line(Vector2(x, 0), Vector2(x - 300, s.y), Color(1, 1, 1, 0.025), 30)
		dekor.draw_rect(Rect2(0, s.y - 6, s.x * 0.5, 6), Ayar.TAKIM_RENK[0])
		dekor.draw_rect(Rect2(s.x * 0.5, s.y - 6, s.x * 0.5, 6), Ayar.TAKIM_RENK[1]))
	menu.add_child(dekor)
	var kutu := VBoxContainer.new()
	kutu.set_anchors_preset(Control.PRESET_CENTER)
	kutu.custom_minimum_size = Vector2(620, 0)
	kutu.position = Vector2(-310, -320)
	kutu.add_theme_constant_override("separation", 12)
	menu.add_child(kutu)
	var baslik := Label.new()
	baslik.text = "ONLINE SAVAŞ"
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	baslik.add_theme_font_size_override("font_size", 58)
	baslik.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	baslik.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	baslik.add_theme_constant_override("shadow_offset_y", 4)
	kutu.add_child(baslik)
	var alt := Label.new()
	alt.text = "1944 · Müttefik vs Mihver · 4'e 4 takım çatışması"
	alt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alt.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	kutu.add_child(alt)
	var ad_satir := HBoxContainer.new()
	var adl := Label.new()
	adl.text = "Adın:"
	adl.custom_minimum_size = Vector2(80, 0)
	ad_satir.add_child(adl)
	ad_kutu = LineEdit.new()
	ad_kutu.text = profil["ad"]
	ad_kutu.max_length = 14
	ad_kutu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ad_kutu.text_changed.connect(func(t): profil["ad"] = t.strip_edges(); _profil_kaydet())
	ad_satir.add_child(ad_kutu)
	kutu.add_child(ad_satir)
	var sinif_satir := HBoxContainer.new()
	sinif_satir.add_theme_constant_override("separation", 8)
	for i in Ayar.SINIFLAR.size():
		var b := Button.new()
		b.text = "%s\n%s" % [Ayar.SINIFLAR[i]["ad"], Ayar.SINIFLAR[i]["silah"]]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(148, 64)
		var k := i
		b.pressed.connect(func(): _sinif_menu(k))
		sinif_satir.add_child(b)
		sinif_btn.append(b)
	kutu.add_child(sinif_satir)
	_sinif_menu(profil["sinif"])
	kutu.add_child(_buyuk_dugme("HIZLI MAÇ  (online)", _hizli_mac, Color(0.32, 0.45, 0.22)))
	var oda_satir := HBoxContainer.new()
	oda_satir.add_theme_constant_override("separation", 8)
	var kur_b := _buyuk_dugme("ODA KUR", _oda_kur, Color(0.25, 0.32, 0.4))
	kur_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oda_satir.add_child(kur_b)
	kod_kutu = LineEdit.new()
	kod_kutu.placeholder_text = "ODA KODU"
	kod_kutu.max_length = 5
	kod_kutu.custom_minimum_size = Vector2(130, 0)
	kod_kutu.alignment = HORIZONTAL_ALIGNMENT_CENTER
	oda_satir.add_child(kod_kutu)
	var kat_b := _buyuk_dugme("KATIL", _koda_katil, Color(0.25, 0.32, 0.4))
	kat_b.custom_minimum_size.x = 120
	oda_satir.add_child(kat_b)
	kutu.add_child(oda_satir)
	kutu.add_child(_buyuk_dugme("BOTLARA KARŞI  (internetsiz)", _botlara_karsi, Color(0.4, 0.3, 0.2)))
	var alt_satir := HBoxContainer.new()
	alt_satir.add_theme_constant_override("separation", 8)
	var sir := _buyuk_dugme("SIRALAMA", _siralama_goster, Color(0.3, 0.3, 0.3))
	sir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alt_satir.add_child(sir)
	var ses_b := _buyuk_dugme("SES: " + ("AÇIK" if profil["ses"] else "KAPALI"), func(): pass, Color(0.3, 0.3, 0.3))
	ses_b.pressed.connect(func():
		profil["ses"] = not profil["ses"]
		Ses.acik = profil["ses"]
		ses_b.text = "SES: " + ("AÇIK" if profil["ses"] else "KAPALI")
		_profil_kaydet())
	ses_b.custom_minimum_size.x = 170
	alt_satir.add_child(ses_b)
	kutu.add_child(alt_satir)
	durum = Label.new()
	durum.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	durum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	durum.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	kutu.add_child(durum)
	var surum := Label.new()
	surum.text = "v" + Ayar.SURUM_ADI + " · PC: WASD + fare, G bomba, R doldur, Tab skor, 1-4 sınıf"
	surum.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	surum.position = Vector2(12, -34)
	surum.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	surum.add_theme_font_size_override("font_size", 13)
	menu.add_child(surum)


func _buyuk_dugme(yazi: String, f: Callable, renk: Color) -> Button:
	var b := Button.new()
	b.text = yazi
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 22)
	var st := StyleBoxFlat.new()
	st.bg_color = renk
	st.set_corner_radius_all(8)
	st.border_color = renk.lightened(0.3)
	st.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", st)
	var st2 := st.duplicate()
	st2.bg_color = renk.lightened(0.15)
	b.add_theme_stylebox_override("hover", st2)
	b.add_theme_stylebox_override("pressed", st2)
	b.pressed.connect(f)
	return b


func _sinif_menu(k: int) -> void:
	profil["sinif"] = k
	_profil_kaydet()
	for i in sinif_btn.size():
		sinif_btn[i].button_pressed = (i == k)


func _yaz(s: String) -> void:
	if durum:
		durum.text = s


# ===================================================================== maç kurulumu

func _oyun_kur(kip: String) -> void:
	menu.visible = false
	if dunya:
		dunya.queue_free()
		hud.queue_free()
	dunya = Dunya.new()
	dunya.kip = kip
	dunya.yerel_id = ag.kimlik
	dunya.ses_acik = profil["ses"]
	add_child(dunya)
	kamera = Camera2D.new()
	kamera.position_smoothing_enabled = true
	kamera.position_smoothing_speed = 7.0
	kamera.limit_left = 0
	kamera.limit_top = 0
	kamera.limit_right = int(dunya.harita.W)
	kamera.limit_bottom = int(dunya.harita.H)
	dunya.add_child(kamera)
	hud = Hud.new()
	hud.dunya = dunya
	hud.kamera = kamera
	add_child(hud)
	hud.ayarla_sinif(profil["sinif"])
	hud.cikis_istendi.connect(_menuye_don)
	hud.sinif_secildi.connect(func(k):
		profil["sinif"] = k
		_profil_kaydet()
		var ben = dunya.askerler.get(dunya.yerel_id)
		if ben and dunya.kip == "kurucu":
			ben.istenen = k)
	dunya.olum_oldu.connect(_olum)
	dunya.mac_bitti.connect(_mac_bitti)
	dunya.mesaj.connect(func(s): hud.akis_ekle(s))
	oyunda = true
	_rapor_gitti = false
	_yeni_mac_t = -1.0


func _ben() -> Dictionary:
	return {"id": ag.kimlik, "ad": _ad(), "sinif": profil["sinif"], "sahip": ag.kimlik}


func _ad() -> String:
	var a: String = profil["ad"].strip_edges()
	return a if a != "" else "Asker"


func _botlara_karsi() -> void:
	online = false
	kurucu = true
	_oyun_kur("kurucu")
	dunya.baslat(randi() % 100000, [_ben()])
	hud.mesaj("Botlara karşı! %d öldürmeye ilk ulaşan kazanır" % Ayar.SKOR_HEDEF, 4.0)


func _hizli_mac() -> void:
	_yaz("Oda aranıyor...")
	var s = await ag.rpc_cagir("os_hizli_mac", {"p_ad": _ad(), "p_surum": Ayar.SURUM})
	if s == null or typeof(s) != TYPE_DICTIONARY or not s.has("kod"):
		_yaz("Sunucuya ulaşılamadı. İnternetini kontrol et ya da 'Botlara karşı' oyna.")
		return
	_online_basla(s["kod"], bool(s["kurucu"]), int(s["harita"]))


func _oda_kur() -> void:
	_yaz("Oda kuruluyor...")
	var s = await ag.rpc_cagir("os_oda_ac", {"p_ad": _ad(), "p_surum": Ayar.SURUM})
	if s == null or typeof(s) != TYPE_DICTIONARY or not s.has("kod"):
		_yaz("Sunucuya ulaşılamadı.")
		return
	_online_basla(s["kod"], true, int(s["harita"]))


func _koda_katil() -> void:
	var kod := kod_kutu.text.strip_edges().to_upper()
	if kod.length() != 5:
		_yaz("5 harfli oda kodunu yaz.")
		return
	_yaz("Odaya bağlanılıyor...")
	var s = await ag.rpc_cagir("os_oda_bul", {"p_kod": kod})
	if s == null or typeof(s) != TYPE_DICTIONARY or not s.has("kod"):
		_yaz("Oda bulunamadı ya da kapanmış.")
		return
	_online_basla(s["kod"], false, int(s["harita"]))


func _online_basla(kod: String, _kurucu: bool, tohum: int) -> void:
	online = true
	kurucu = _kurucu
	oda = kod
	_yaz("Bağlanılıyor: oda %s" % kod)
	_oyun_kur("kurucu" if kurucu else "istemci")
	dunya.ag_acik = kurucu
	if kurucu:
		kurucu_id = ag.kimlik
		dunya.baslat(tohum, [_ben()])
	else:
		dunya.baslat(tohum, [])
	hud.durum_yazi = "Oda %s · bağlanıyor" % kod
	_baglanti_t = 0.0
	_son_goruntu_alis = Time.get_ticks_msec() / 1000.0
	ag.baglan(kod, {"ad": _ad(), "sinif": profil["sinif"], "giris": Time.get_unix_time_from_system() + (0.0 if kurucu else 1e6)})


# ===================================================================== ağ olayları

func _ag_baglandi() -> void:
	hud.durum_yazi = "Oda %s" % oda
	hud.mesaj("Oda %s%s" % [oda, " — arkadaşların bu kodla katılabilir" if kurucu else ""], 5.0)
	if kurucu:
		ag.rpc_cagir("os_oda_guncelle", {"p_kod": oda, "p_oyuncu": 1, "p_durum": "oynaniyor"})


func _ag_koptu(neden: String) -> void:
	if not oyunda or not online:
		return
	if kurucu:
		# kurucu internetsiz kalsa da oyun botlarla sürer
		hud.mesaj("Bağlantı koptu — botlarla devam ediliyor", 4.0)
		online = false
		dunya.ag_acik = false
	else:
		_menuye_don()
		_yaz(neden)


func _ag_katilan(id: String, bilgi: Dictionary) -> void:
	if not oyunda:
		return
	if dunya.kip == "kurucu":
		dunya.insan_ekle(id, str(bilgi.get("ad", "Asker")).left(14), int(bilgi.get("sinif", 0)))
	else:
		hud.akis_ekle("%s odada" % str(bilgi.get("ad", "Asker")))


func _ag_ayrilan(id: String) -> void:
	if not oyunda:
		return
	if dunya.kip == "kurucu":
		dunya.insan_cikar(id)
	elif id == kurucu_id or kurucu_id == "":
		_kurucu_degisti()


func _kurucu_degisti() -> void:
	var yeni := ag.kurucu_kim()
	kurucu_id = yeni
	if yeni == ag.kimlik:
		kurucu = true
		dunya.kurucuya_gec(ag.uyeler)
		dunya.ag_acik = true
		hud.mesaj("Kurucu ayrıldı — maçı sen yürütüyorsun", 4.0)
		ag.rpc_cagir("os_oda_guncelle", {"p_kod": oda, "p_oyuncu": ag.uyeler.size(), "p_durum": "oynaniyor"})
	else:
		hud.mesaj("Kurucu değişti", 3.0)


func _ag_mesaj(olay: String, veri: Dictionary, kimden: String) -> void:
	if not oyunda:
		return
	match olay:
		"s":
			if dunya.kip == "istemci":
				kurucu_id = kimden
				_son_goruntu_alis = Time.get_ticks_msec() / 1000.0
				dunya.goruntu_uygula(veri)
		"g":
			if dunya.kip == "kurucu":
				if not dunya.askerler.has(kimden) and ag.uyeler.has(kimden):
					dunya.insan_ekle(kimden, str(ag.uyeler[kimden].get("ad", "Asker")).left(14), int(veri.get("k", 0)))
				dunya.girdi_al(kimden, veri)


# ===================================================================== maç olayları

func _olum(katil: String, kurban: String, sinif: int) -> void:
	var k = dunya.askerler.get(katil)
	var o = dunya.askerler.get(kurban)
	if o == null:
		return
	var silah: String = Ayar.SINIFLAR[sinif]["silah"] if sinif >= 0 else "bomba"
	var metin := "%s  [%s]  %s" % [k.ad if k else "?", silah, o.ad] if k and k != o else "%s öldü" % o.ad
	hud.akis_ekle(metin)
	if kurban == dunya.yerel_id and k and k != o:
		hud.mesaj("%s seni vurdu" % k.ad, 2.5)
	elif katil == dunya.yerel_id:
		hud.mesaj("+1  %s" % o.ad, 1.5)


func _mac_bitti(kazanan: int) -> void:
	var ben = dunya.askerler.get(dunya.yerel_id)
	var metin := "BERABERE"
	if kazanan >= 0:
		metin = "%s KAZANDI" % Ayar.TAKIM_AD[kazanan].to_upper()
		if ben:
			metin += "  —  " + ("ZAFER!" if ben.takim == kazanan else "YENİLGİ")
	hud.bitis(metin)
	_yeni_mac_t = 12.0
	if online and ben and not _rapor_gitti:
		_rapor_gitti = true
		ag.rpc_cagir("os_mac_sonucu", {"p_cihaz": profil["cihaz"], "p_ad": _ad(), "p_oldurme": ben.oldurme,
			"p_olum": ben.olum, "p_kazandi": kazanan == ben.takim})


# ===================================================================== döngü

func _physics_process(dt: float) -> void:
	if not oyunda:
		return
	var ben = dunya.askerler.get(dunya.yerel_id)
	var g := hud.girdi_hesapla(ben)
	if dunya.kip == "kurucu":
		if ben:
			ben.girdi = g
			if ben.olu:
				ben.istenen = hud.istenen_sinif
		dunya.adim(dt)
		if online:
			_goruntu_t += dt
			if _goruntu_t >= 1.0 / Ayar.GORUNTU_HZ:
				_goruntu_t = 0.0
				ag.yayinla("s", dunya.goruntu())
			_kalp_t += dt
			if _kalp_t > 5.0:
				_kalp_t = 0.0
				var insan := 0
				for a in dunya.askerler.values():
					if a.sahip != "":
						insan += 1
				ag.rpc_cagir("os_oda_guncelle", {"p_kod": oda, "p_oyuncu": insan, "p_durum": "oynaniyor"})
		if dunya.bitti and _yeni_mac_t >= 0.0:
			_yeni_mac_t -= dt
			if _yeni_mac_t < 0.0:
				_yeni_mac()
	else:
		dunya.zaman += dt
		dunya.yerel_tahmin(g, dt)
		_girdi_t += dt
		var paket := {"m": [snappedf(g["m"].x, 0.05), snappedf(g["m"].y, 0.05)], "a": int(rad_to_deg(g["a"])),
			"f": 1 if g["f"] else 0, "g": int(g["g"]), "r": 1 if g["r"] else 0, "k": hud.istenen_sinif}
		var degisti: bool = paket.hash() != _son_girdi.hash() or g["g"] > 0.0 or g["r"]
		if _girdi_t >= 1.0 / Ayar.GIRDI_HZ and (degisti or _girdi_t > 0.3) or g["g"] > 0.0 or g["r"]:
			_girdi_t = 0.0
			_son_girdi = paket
			ag.yayinla("g", paket)
		var simdi := Time.get_ticks_msec() / 1000.0
		if simdi - _son_goruntu_alis > 8.0:
			if ag.uyeler.size() <= 1 or not ag.katildi:
				_menuye_don()
				_yaz("Kurucudan haber alınamadı. Oda kapanmış olabilir.")
				return
			_kurucu_degisti()
			_son_goruntu_alis = simdi
		if dunya.bitti:
			_yeni_mac_t = 99.0
	_kamera(ben, dt)
	if online:
		hud.durum_yazi = "Oda %s · %d oyuncu · %s" % [oda, maxi(1, ag.uyeler.size()), "kurucu" if dunya.kip == "kurucu" else "bağlı"]


func _yeni_mac() -> void:
	var insanlar: Array = []
	for a in dunya.askerler.values():
		if a.sahip != "":
			insanlar.append({"id": a.id, "ad": a.ad, "sinif": a.istenen if a.istenen >= 0 else a.sinif, "sahip": a.sahip})
	dunya.baslat(randi() % 100000, insanlar)
	hud.bitis("")
	_rapor_gitti = false
	hud.mesaj("Yeni maç!", 3.0)


func _kamera(ben, dt: float) -> void:
	if ben == null:
		return
	var ileri := Vector2.RIGHT.rotated(ben.aci) * (230.0 if ben.sinif == 2 else 110.0)
	if ben.olu:
		ileri = Vector2.ZERO
	kamera.position = ben.position + ileri
	var z := 0.8 if ben.sinif == 2 else 0.9
	var ekran := get_viewport().get_visible_rect().size
	if ekran.y < 600:
		z *= ekran.y / 600.0
	kamera.zoom = kamera.zoom.lerp(Vector2(z, z), clampf(dt * 3.0, 0, 1))
	var s: float = dunya.fx.sarsinti
	kamera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * s * 22.0


func _menuye_don() -> void:
	if online:
		if kurucu:
			if ag.uyeler.size() <= 1:
				ag.rpc_cagir("os_oda_kapat", {"p_kod": oda})
		ag.kapat()
	online = false
	oyunda = false
	if dunya:
		dunya.queue_free()
		dunya = null
	if hud:
		hud.queue_free()
		hud = null
	menu.visible = true
	_yaz("")


# ===================================================================== sıralama

func _siralama_goster() -> void:
	_yaz("Sıralama yükleniyor...")
	var s = await ag.rpc_cagir("os_siralama", {})
	if s == null or typeof(s) != TYPE_ARRAY:
		_yaz("Sıralama alınamadı.")
		return
	_yaz("")
	if siralama_panel:
		siralama_panel.queue_free()
	siralama_panel = PanelContainer.new()
	siralama_panel.set_anchors_preset(Control.PRESET_CENTER)
	siralama_panel.custom_minimum_size = Vector2(560, 520)
	siralama_panel.position = Vector2(-280, -260)
	menu.add_child(siralama_panel)
	var v := VBoxContainer.new()
	siralama_panel.add_child(v)
	var b := Label.new()
	b.text = "EN İYİ 50 ASKER"
	b.add_theme_font_size_override("font_size", 26)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	var kay := ScrollContainer.new()
	kay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(kay)
	var liste := VBoxContainer.new()
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kay.add_child(liste)
	var i := 1
	for x in s:
		var l := Label.new()
		l.text = "%2d. %-14s  puan %5d  ·  maç %d  ·  zafer %d  ·  Ö/Ö %d/%d" % [i, x["ad"], x["puan"], x["mac"], x["galibiyet"], x["oldurme"], x["olum"]]
		if x["ad"] == _ad():
			l.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		liste.add_child(l)
		i += 1
	if s.is_empty():
		var l := Label.new()
		l.text = "Henüz kimse yok — ilk online maçı sen oyna!"
		liste.add_child(l)
	var kapat := Button.new()
	kapat.text = "KAPAT"
	kapat.pressed.connect(func(): siralama_panel.queue_free(); siralama_panel = null)
	v.add_child(kapat)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if oyunda:
			_menuye_don()
		elif what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()
