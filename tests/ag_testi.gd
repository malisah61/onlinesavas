extends SceneTree
## Ağ testi (sunucusuz): kurucu + istemci aynı süreçte, mesajlar gerçekteki gibi JSON'a çevrilip geri okunur.
## Doğrular: istemcinin girdisi kurucuda askerini yürütür, anlık görüntü istemcide aynı durumu kurar,
## kurucu ayrılınca istemci devralıp simülasyona devam edebilir.

const Dunya = preload("res://scripts/dunya.gd")

var hata := 0


func _kontrol(kosul: bool, mesaj: String) -> void:
	print(("TAMAM  " if kosul else "HATA   ") + mesaj)
	if not kosul:
		hata += 1


func _initialize() -> void:
	var k := Dunya.new()
	k.kip = "kurucu"
	k.ag_acik = true
	k.ses_acik = false
	k.yerel_id = "kurucu1"
	root.add_child(k)
	k.baslat(4242, [{"id": "kurucu1", "ad": "Kurucu", "sinif": 0, "sahip": "kurucu1"}])
	var c := Dunya.new()
	c.kip = "istemci"
	c.ses_acik = false
	c.yerel_id = "ist1"
	root.add_child(c)
	c.baslat(4242, [])
	k.insan_ekle("ist1", "İstemci", 1)
	_kontrol(k.askerler.size() == 8, "kurucuda 8 asker (insan botun yerini aldı): %d" % k.askerler.size())
	var ka = k.askerler["ist1"]
	var bas: Vector2 = ka.position
	var dt := 1.0 / 30.0
	var bayt := 0
	var paket := 0
	for i in 300:
		# istemci girdisi (JSON gidiş-dönüş)
		var g := {"m": [1.0 if ka.takim == 0 else -1.0, 0.0], "a": 0, "f": 0, "g": 0, "r": 0, "k": 2}
		k.girdi_al("ist1", JSON.parse_string(JSON.stringify(g)))
		c.yerel_tahmin({"m": Vector2(g["m"][0], 0), "a": 0.0, "f": false}, dt)
		k.adim(dt)
		if i % 3 == 0:
			var s := JSON.stringify(k.goruntu())
			bayt += s.length()
			paket += 1
			c.goruntu_uygula(JSON.parse_string(s))
		k._bekleyen.clear()
	c.goruntu_uygula(JSON.parse_string(JSON.stringify(k.goruntu())))
	_kontrol(ka.position.distance_to(bas) > 150.0, "istemci girdisi kurucuda askeri yürüttü: %.0f px" % ka.position.distance_to(bas))
	_kontrol(c.askerler.size() == k.askerler.size(), "istemcide aynı asker sayısı")
	var en_fark := 0.0
	for id in k.askerler:
		var son: Array = c.askerler[id]._tampon[-1] if c.askerler[id]._tampon.size() > 0 else [0, c.askerler[id].position]
		if id == "ist1":
			continue
		en_fark = maxf(en_fark, (son[1] as Vector2).distance_to(k.askerler[id].position))
	_kontrol(en_fark < 40.0, "istemci konumları kurucuyla uyumlu (en büyük fark %.1f px)" % en_fark)
	_kontrol(c.askerler["ist1"].position.distance_to(ka.position) < 60.0, "tahmin edilen kendi konumum kurucuya yakın: %.1f px" % c.askerler["ist1"].position.distance_to(ka.position))
	_kontrol(int(c.skor[0]) == k.skor[0] and int(c.skor[1]) == k.skor[1], "skor eşit %s" % str(c.skor))
	_kontrol(k.askerler["ist1"].istenen == 2, "sınıf isteği iletildi")
	print("Ortalama görüntü boyu: %d bayt, %d paket (10 Hz ≈ %.1f KB/sn)" % [bayt / maxi(1, paket), paket, bayt / maxi(1, paket) * 10.0 / 1024.0])
	_kontrol(bayt / maxi(1, paket) < 6000, "görüntü paketi küçük (< 6 KB)")
	# kurucu ayrılır → istemci devralır
	k.queue_free()
	c.kurucuya_gec({"ist1": {}})
	var once: int = c.skor[0] + c.skor[1]
	for i in 900:
		c.adim(dt)
		c._bekleyen.clear()
	_kontrol(c.kip == "kurucu", "istemci kurucu oldu")
	_kontrol(c.askerler["kurucu1"].bot != null, "ayrılan kurucunun askeri bota devredildi")
	_kontrol(c.skor[0] + c.skor[1] > once, "devralınan maç sürüyor (skor %s → %s)" % [once, c.skor[0] + c.skor[1]])
	print("SONUÇ: %s" % ("BAŞARILI" if hata == 0 else "%d HATA" % hata))
	quit(1 if hata > 0 else 0)
