extends SceneTree
## Bulut bot testi: 8 bot, hızlandırılmış maçlar. Rapor: docs/BOT_RAPORU.md
## godot --headless -s res://tests/bot_testi.gd -- --mac=3 --sure=240
## Ders (Komando): her derlemede botlarla oyna, sayılarla ölç (takılma, isabet, skor dengesi); hissiyatla değil.

const Dunya = preload("res://scripts/dunya.gd")


func _initialize() -> void:
	var mac := 3
	var sure := 240.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mac="):
			mac = int(a.split("=")[1])
		if a.begins_with("--sure="):
			sure = float(a.split("=")[1])
	var satirlar: Array = []
	var hata := 0
	var t0 := Time.get_ticks_msec()
	for m in mac:
		var d := Dunya.new()
		d.kip = "kurucu"
		d.ses_acik = false
		root.add_child(d)
		d.baslat(1000 + m * 37, [])
		var atis := 0
		var isabet := 0
		var bomba := 0
		var dt := 1.0 / 30.0
		var n := int(sure / dt)
		for i in n:
			d.adim(dt)
			for e in d._bekleyen:
				if e[0] == "a":
					atis += 1
					isabet += e[6]
				elif e[0] == "b":
					bomba += 1
			d._bekleyen.clear()
			if d.bitti:
				break
		var takilma := 0
		var sinif_old := [0, 0, 0, 0]
		for a in d.askerler.values():
			takilma += a.bot.takilma
			sinif_old[a.sinif] += a.oldurme
		var toplam: int = d.skor[0] + d.skor[1]
		var oran := float(isabet) / maxf(1.0, atis)
		satirlar.append("| %d | %d | %d – %d | %.0f sn | %d | %d (%%%.0f) | %d | %d | %s |" % [m + 1, d.tohum, d.skor[0], d.skor[1],
			d.zaman, toplam, atis, oran * 100.0, bomba, takilma, str(sinif_old)])
		if toplam < 4:
			hata += 1
			printerr("UYARI: maç %d çok az öldürme (%d)" % [m + 1, toplam])
		if takilma > 120:
			hata += 1
			printerr("UYARI: maç %d çok takılma (%d)" % [m + 1, takilma])
		d.queue_free()
	var md := "# Bot testi raporu\n\nTarih: %s — %d maç, maç başı en çok %.0f sn (8 bot, 4'e 4). Süre: %.1f sn gerçek.\n\n" % [
		Time.get_datetime_string_from_system(), mac, sure, (Time.get_ticks_msec() - t0) / 1000.0]
	md += "| Maç | Harita | Skor (Müt–Mih) | Süre | Öldürme | Atış (isabet) | Bomba | Takılma | Sınıf öldürme [Piy, Mak, Kes, Ağır] |\n|---|---|---|---|---|---|---|---|---|\n"
	md += "\n".join(satirlar) + "\n"
	print(md)
	var f := FileAccess.open("res://docs/BOT_RAPORU.md", FileAccess.WRITE)
	if f:
		f.store_string(md)
	quit(1 if hata > 0 else 0)
