extends Node2D
## Bir asker: hem simülasyon durumu (kurucuda) hem görünüm (herkeste).
## Konum = ayak noktası (Komando sprite pivotu). Gövde merkezi = konum + GOVDE.

const Ayar = preload("res://scripts/ayarlar.gd")
const Sayfa = preload("res://scripts/sprite_sayfa.gd")
const GOVDE := Vector2(0, -24)
const GOVDE_R := 15.0
enum { BEKLE, YURU, KOS, ATES, OLUM }
const ANIM := [&"idle", &"walk", &"run", &"shoot", &"death"]

var id := ""
var ad := ""
var takim := 0
var sinif := 0
var sahip := ""            # insan oyuncunun ağ kimliği; bot ise ""
var bot = null             # Bot beyni (yalnız kurucuda)
var hp := 100.0
var olu := false
var donus_t := 0.0
var koruma_t := 0.0
var sarjor := 0
var dolum_t := 0.0
var ates_t := 0.0
var son_ates := -10.0      # en son ateş anı (dunya.zaman): botlar ses olarak duyar
var bomba := 2
var bomba_t := 0.0
var oldurme := 0
var olum := 0
var vuran := ""
var istenen := -1          # bir sonraki doğuşta geçilecek sınıf
var hasar_t := 0.0         # son hasardan beri (yenilenme)
var aci := 0.0             # nişan yönü
var anim := BEKLE
var hareket := Vector2.ZERO
var girdi := {"m": Vector2.ZERO, "a": 0.0, "f": false, "g": 0.0, "r": false}

# görünüm
var spr: AnimatedSprite2D
var yerel := false          # bu cihazın oyuncusu
var gorunur := true
var _tampon: Array = []     # istemci: [zaman, konum, aci]
var _ates_flas := 0.0
var _vurulma := 0.0
var _sprite_ad := ""


func veri() -> Dictionary:
	return Ayar.SINIFLAR[sinif]


func kur(_id: String, _ad: String, _takim: int, _sinif: int) -> void:
	id = _id
	ad = _ad
	takim = _takim
	sinif_ata(_sinif)
	hp = veri()["can"]
	sarjor = veri()["sarjor"]


func sinif_ata(s: int) -> void:
	sinif = clampi(s, 0, Ayar.SINIFLAR.size() - 1)
	var aday: Array = Ayar.SINIFLAR[sinif]["sprite"][takim]
	var yeni := Sayfa.sec(aday)
	if yeni != _sprite_ad:
		_sprite_ad = yeni
		if spr:
			spr.queue_free()
		spr = Sayfa.ekle(self, yeni, 1.3)
		spr.position = Vector2.ZERO


func govde() -> Vector2:
	return position + GOVDE


func canli() -> bool:
	return not olu


func tampona_ekle(t: float, p: Vector2, a: float) -> void:
	_tampon.append([t, p, a])
	while _tampon.size() > 8:
		_tampon.pop_front()


func ara_deger(t: float) -> void:
	## İstemci: iki anlık görüntü arasında yumuşak geçiş (interpolasyon).
	if _tampon.is_empty():
		return
	if t <= _tampon[0][0]:
		position = _tampon[0][1]
		aci = _tampon[0][2]
		return
	for i in range(_tampon.size() - 1):
		var a: Array = _tampon[i]
		var b: Array = _tampon[i + 1]
		if t >= a[0] and t <= b[0]:
			var k: float = (t - a[0]) / maxf(0.001, b[0] - a[0])
			position = a[1].lerp(b[1], k)
			aci = lerp_angle(a[2], b[2], k)
			return
	var son: Array = _tampon[_tampon.size() - 1]
	# kısa süre ileri tahmin (paket gecikirse donmasın)
	if _tampon.size() >= 2:
		var on: Array = _tampon[_tampon.size() - 2]
		var v: Vector2 = (son[1] - on[1]) / maxf(0.001, son[0] - on[0])
		position = son[1] + v * minf(t - son[0], 0.15)
	else:
		position = son[1]
	aci = son[2]


func ates_etti() -> void:
	_ates_flas = 0.07


func vuruldu() -> void:
	_vurulma = 0.15


func gorunum(dt: float) -> void:
	_ates_flas = maxf(0.0, _ates_flas - dt)
	_vurulma = maxf(0.0, _vurulma - dt)
	if spr:
		var a: StringName = ANIM[anim]
		var yon := aci
		if anim == YURU or anim == KOS:
			if hareket.length() > 1.0 and absf(angle_difference(hareket.angle(), aci)) > 1.6:
				yon = hareket.angle()   # geri geri yürürken sprite hareket yönüne baksın
		if anim == ATES or (_ates_flas > 0.0 and anim == BEKLE):
			a = &"shoot"
		Sayfa.oynat(spr, a, yon)
		spr.modulate = Color(1, 0.55, 0.55) if _vurulma > 0.0 else (Color(1, 1, 1, 0.55) if koruma_t > 0.0 else Color.WHITE)
	z_index = 0 if not olu else -1
	queue_redraw()


func _draw() -> void:
	if not gorunur:
		return
	var renk: Color = Ayar.TAKIM_RENK[takim]
	if olu:
		return
	# ayak halkası (takım rengi), yerel oyuncu kalın
	draw_arc(Vector2.ZERO, 20, 0, TAU, 24, Color(renk, 0.85 if yerel else 0.55), 3.0 if yerel else 2.0)
	if koruma_t > 0.0:
		draw_arc(GOVDE, 32, 0, TAU, 28, Color(1, 1, 1, 0.5), 2.0)
	# namlu ateşi
	if _ates_flas > 0.0:
		var u := GOVDE + Vector2.RIGHT.rotated(aci) * 30.0
		draw_circle(u, 7.0, Color(1, 0.85, 0.4, 0.9))
		draw_circle(u, 3.5, Color(1, 1, 0.85))
	# can çubuğu + ad
	var oran := clampf(hp / float(veri()["can"]), 0.0, 1.0)
	var y := -86.0
	draw_rect(Rect2(-20, y, 40, 5), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-20, y, 40 * oran, 5), renk.lerp(Color(1, 0.2, 0.2), 1.0 - oran) if oran < 0.5 else renk)
	var f := ThemeDB.fallback_font
	var yazi := ad
	var gen := f.get_string_size(yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(f, Vector2(-gen * 0.5 + 1, y - 3), yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.7))
	draw_string(f, Vector2(-gen * 0.5, y - 4), yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.95) if yerel else Color(renk.lightened(0.4), 0.95))
