extends SceneTree
## Canlı Supabase Realtime testi (CI'da, internet gerekir): iki bağlantı aynı odaya girer,
## presence ile birbirini görür, broadcast mesajı karşıya ulaşır, RPC'ler çalışır.

const Ag = preload("res://scripts/ag.gd")

var a: Ag
var b: Ag
var t := 0.0
var oda := ""
var sonuc := {"rpc": false, "a_bagli": false, "b_bagli": false, "katilan": false, "mesaj": false, "ayrilan": false}
var asama := 0


func _initialize() -> void:
	oda = "T" + str(randi() % 10000).pad_zeros(4)
	a = Ag.new()
	a.kimlik = "testa" + str(randi() % 1000)
	b = Ag.new()
	b.kimlik = "testb" + str(randi() % 1000)
	root.add_child(a)
	root.add_child(b)
	a.baglandi.connect(func(): sonuc["a_bagli"] = true)
	b.baglandi.connect(func(): sonuc["b_bagli"] = true)
	a.katilan.connect(func(id, bilgi): if id == b.kimlik: sonuc["katilan"] = true)
	a.mesaj_geldi.connect(func(olay, veri, kimden): if olay == "g" and kimden == b.kimlik and veri.get("deneme") == 61: sonuc["mesaj"] = true)
	a.ayrilan.connect(func(id): if id == b.kimlik: sonuc["ayrilan"] = true)
	_rpc.call_deferred()


func _rpc() -> void:
	var s = await a.rpc_cagir("os_siralama", {})
	sonuc["rpc"] = typeof(s) == TYPE_ARRAY
	print("RPC os_siralama: ", "tamam" if sonuc["rpc"] else "HATA " + str(s))
	a.baglan(oda, {"ad": "TestA", "sinif": 0, "giris": 1.0})
	b.baglan(oda, {"ad": "TestB", "sinif": 1, "giris": 2.0})


func _process(dt: float) -> bool:
	t += dt
	if asama == 0 and sonuc["a_bagli"] and sonuc["b_bagli"] and t > 3.0:
		asama = 1
		for i in 5:
			b.yayinla("g", {"deneme": 61})
	if asama == 1 and sonuc["mesaj"] and sonuc["katilan"]:
		asama = 2
		print("kurucu_kim (A olmalı): ", a.kurucu_kim(), " / ", b.kurucu_kim())
		b.kapat()
	if asama == 2 and sonuc["ayrilan"] or t > 25.0:
		print("Sonuç: ", sonuc, "  gönderilen A/B: %d/%d alınan A/B: %d/%d" % [a.gonderilen, b.gonderilen, a.alinan, b.alinan])
		var iyi := true
		for k in sonuc:
			if not sonuc[k]:
				iyi = false
				print("BAŞARISIZ: ", k)
		print("CANLI TEST: ", "BAŞARILI" if iyi else "BAŞARISIZ")
		quit(0 if iyi else 1)
	return false
