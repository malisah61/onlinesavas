extends RefCounted
## Komando'nun sprite_sheet.gd'sinden uyarlandı. 8 yönlü sayfalar (tools/kucult.py çıktısı, dikdörtgen kare: fw × fh).
## Ders (Komando): aynı sayfadan kurulan SpriteFrames herkesçe paylaşılır (her asker için yeniden kurmak ~100 ms takılma).

const KLASOR := "res://assets/sprites/k64/"
static var _onbellek := {}


static func var_mi(ad: String) -> bool:
	return ResourceLoader.exists(KLASOR + ad + ".png")


static func sec(adaylar: Array) -> String:
	for a in adaylar:
		if var_mi(a):
			return a
	return "komando"


static func kur(ad: String) -> Array:
	if _onbellek.has(ad):
		return _onbellek[ad]
	var tex: Texture2D = load(KLASOR + ad + ".png")
	var lay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KLASOR + ad + ".json"))
	var fw: int = int(lay.get("fw", lay["frame"]))
	var fh: int = int(lay.get("fh", lay["frame"]))
	var slot_w: int = int(lay["slot"])
	var per_row: int = int(lay["slots_per_row"])
	var dirs: int = int(lay.get("directions", 8))
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim_ad in lay["anims"]:
		var a: Dictionary = lay["anims"][anim_ad]
		for d in dirs:
			var an := StringName("%s_%d" % [anim_ad, d])
			frames.add_animation(an)
			frames.set_animation_speed(an, float(a.get("fps", 10)))
			frames.set_animation_loop(an, bool(a.get("loop", true)))
			var slot: int = int(a["slot"]) + d
			var row: int = slot / per_row
			var c0: int = (slot % per_row) * slot_w
			for i in int(a["frames"]):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2((c0 + i) * fw, row * fh, fw, fh)
				frames.add_frame(an, at)
	var pv: Array = lay.get("pivot", [fw * 0.5, fh * 0.8])
	var sonuc := [frames, Vector2(fw * 0.5 - float(pv[0]), fh * 0.5 - float(pv[1])), dirs]
	_onbellek[ad] = sonuc
	return sonuc


static func ekle(sahip: Node2D, ad: String, olcek := 0.9) -> AnimatedSprite2D:
	var k := kur(ad)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = k[0]
	spr.offset = k[1]
	spr.scale = Vector2(olcek, olcek)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.set_meta("dirs", k[2])
	sahip.add_child(spr)
	oynat(spr, &"idle", 0.0)
	return spr


static func oynat(spr: AnimatedSprite2D, anim: StringName, aci: float) -> void:
	if spr == null:
		return
	var dirs: int = spr.get_meta("dirs", 8)
	var d := posmod(roundi(aci / (TAU / dirs)), dirs)
	var ad := StringName("%s_%d" % [anim, d])
	if spr.animation == ad or not spr.sprite_frames.has_animation(ad):
		return
	var koru := spr.frame if String(spr.animation).get_slice("_", 0) == String(anim) else 0
	spr.play(ad)
	if koru < spr.sprite_frames.get_frame_count(ad):
		spr.frame = koru
