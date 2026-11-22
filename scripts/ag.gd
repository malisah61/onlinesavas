extends Node
## Supabase bağlantısı:
##  - HTTP RPC (os_hizli_mac, os_oda_ac, os_oda_bul, os_oda_guncelle, os_mac_sonucu, os_siralama)
##  - Realtime (Phoenix kanal protokolü, WebSocket): oda kanalı "os-<KOD>" üzerinde broadcast + presence.
## Web'de ve Android'de aynı kod çalışır (Godot WebSocketPeer + HTTPRequest).
## Kurucu otoriteli: istemciler yalnız girdi yollar ("g"), kurucu anlık görüntü yollar ("s").
## Kurucu ayrılırsa kalan en küçük kimlikli oyuncu kurucu olur (son görüntüden devam eder).

signal baglandi
signal koptu(neden: String)
signal mesaj_geldi(olay: String, veri: Dictionary, kimden: String)
signal katilan(id: String, bilgi: Dictionary)
signal ayrilan(id: String)

const Ayar = preload("res://scripts/ayarlar.gd")

var ws := WebSocketPeer.new()
var kimlik := ""            # bu cihazın oyundaki kimliği
var oda := ""
var konu := ""
var bagli := false
var katildi := false
var uyeler := {}            # presence: id -> bilgi
var _ref := 0
var _kalp_t := 0.0
var _durum := WebSocketPeer.STATE_CLOSED
var _bilgi := {}
var gonderilen := 0
var alinan := 0


func _ready() -> void:
	ws.inbound_buffer_size = 1 << 20
	ws.outbound_buffer_size = 1 << 20


# ------------------------------------------------------------------ HTTP RPC

func rpc_cagir(ad: String, govde: Dictionary) -> Variant:
	## await ile kullanılır: var sonuc = await ag.rpc_cagir("os_siralama", {})
	var h := HTTPRequest.new()
	h.timeout = 12.0
	add_child(h)
	var basliklar := PackedStringArray(["apikey: " + Ayar.SUPABASE_ANON, "Authorization: Bearer " + Ayar.SUPABASE_ANON,
		"Content-Type: application/json"])
	var hata := h.request(Ayar.SUPABASE_URL + "/rest/v1/rpc/" + ad, basliklar, HTTPClient.METHOD_POST, JSON.stringify(govde))
	if hata != OK:
		h.queue_free()
		return null
	var s: Array = await h.request_completed
	h.queue_free()
	if s[0] != HTTPRequest.RESULT_SUCCESS or s[1] >= 300:
		push_warning("RPC %s hata: %s %s" % [ad, s[1], (s[3] as PackedByteArray).get_string_from_utf8().left(200)])
		return null
	var metin: String = (s[3] as PackedByteArray).get_string_from_utf8()
	if metin == "":
		return {}
	return JSON.parse_string(metin)


# ------------------------------------------------------------------ Realtime

func baglan(oda_kodu: String, bilgi: Dictionary) -> void:
	oda = oda_kodu
	konu = "realtime:os-" + oda_kodu
	_bilgi = bilgi
	uyeler.clear()
	katildi = false
	var url := Ayar.SUPABASE_URL.replace("https://", "wss://") + "/realtime/v1/websocket?apikey=" + Ayar.SUPABASE_ANON + "&vsn=1.0.0"
	var h := ws.connect_to_url(url)
	if h != OK:
		koptu.emit("Bağlantı kurulamadı (%d)" % h)


func kapat() -> void:
	if bagli:
		_gonder({"topic": konu, "event": "phx_leave", "payload": {}, "ref": _yeni_ref()})
	ws.close()
	bagli = false
	katildi = false


func _yeni_ref() -> String:
	_ref += 1
	return str(_ref)


func _gonder(m: Dictionary) -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(m))
		gonderilen += 1


func yayinla(olay: String, veri: Dictionary) -> void:
	if not katildi:
		return
	veri["_k"] = kimlik
	_gonder({"topic": konu, "event": "broadcast", "payload": {"type": "broadcast", "event": olay, "payload": veri}, "ref": _yeni_ref()})


func _process(dt: float) -> void:
	ws.poll()
	var d := ws.get_ready_state()
	if d != _durum:
		_durum = d
		if d == WebSocketPeer.STATE_OPEN:
			bagli = true
			var j := _yeni_ref()
			_gonder({"topic": konu, "event": "phx_join", "ref": j, "join_ref": j,
				"payload": {"config": {"broadcast": {"self": false, "ack": false}, "presence": {"key": kimlik}, "private": false},
					"access_token": Ayar.SUPABASE_ANON}})
		elif d == WebSocketPeer.STATE_CLOSED and bagli:
			bagli = false
			katildi = false
			koptu.emit("Sunucu bağlantısı koptu (%d)" % ws.get_close_code())
	if d != WebSocketPeer.STATE_OPEN:
		return
	_kalp_t += dt
	if _kalp_t > 25.0:
		_kalp_t = 0.0
		_gonder({"topic": "phoenix", "event": "heartbeat", "payload": {}, "ref": _yeni_ref()})
	while ws.get_available_packet_count() > 0:
		var m = JSON.parse_string(ws.get_packet().get_string_from_utf8())
		if typeof(m) != TYPE_DICTIONARY:
			continue
		alinan += 1
		_isle(m)


func _isle(m: Dictionary) -> void:
	var olay: String = m.get("event", "")
	var p = m.get("payload", {})
	match olay:
		"phx_reply":
			if typeof(p) == TYPE_DICTIONARY and p.get("status") == "ok" and not katildi and m.get("topic") == konu:
				katildi = true
				_gonder({"topic": konu, "event": "presence", "ref": _yeni_ref(),
					"payload": {"type": "presence", "event": "track", "payload": _bilgi}})
				baglandi.emit()
			elif typeof(p) == TYPE_DICTIONARY and p.get("status") == "error":
				koptu.emit("Kanala katılamadı: %s" % str(p.get("response", "")))
		"broadcast":
			var v: Dictionary = p.get("payload", {})
			mesaj_geldi.emit(p.get("event", ""), v, v.get("_k", ""))
		"presence_state":
			for k in p:
				_uye_ekle(k, p[k])
		"presence_diff":
			for k in p.get("joins", {}):
				_uye_ekle(k, p["joins"][k])
			for k in p.get("leaves", {}):
				if uyeler.has(k):
					uyeler.erase(k)
					ayrilan.emit(k)
		"phx_error", "phx_close":
			if m.get("topic") == konu:
				koptu.emit("Kanal kapandı")
		"system":
			if typeof(p) == TYPE_DICTIONARY and p.get("status") == "error":
				push_warning("Realtime: " + str(p.get("message", "")))


func _uye_ekle(k: String, v) -> void:
	var metas: Array = v.get("metas", []) if typeof(v) == TYPE_DICTIONARY else []
	var bilgi: Dictionary = metas[0] if metas.size() > 0 else {}
	if not uyeler.has(k):
		uyeler[k] = bilgi
		if k != kimlik:
			katilan.emit(k, bilgi)
	else:
		uyeler[k] = bilgi


func kurucu_kim() -> String:
	## Kurucu ayrılırsa: odadaki en eski (en küçük "giris" zamanı) üye kurucu olur. Herkes aynı sonuca varır.
	var en := ""
	var en_t := INF
	for k in uyeler:
		var t := float(uyeler[k].get("giris", 0.0))
		if t < en_t or (t == en_t and k < en):
			en_t = t
			en = k
	return en
