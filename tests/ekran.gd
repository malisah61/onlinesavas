extends SceneTree
## Ekran görüntüsü (bulutta, xvfb + yazılımsal OpenGL): menü ve botlara karşı maçtan kareler → docs/ekran/
## xvfb-run godot --rendering-driver opengl3 -s res://tests/ekran.gd

var ana
var t := 0.0
var adim := 0
var kareler := [[1.0, "menu"], [9.0, "mac1"], [20.0, "mac2"], [32.0, "mac3"]]


func _initialize() -> void:
	ana = load("res://ana.tscn").instantiate()
	root.add_child(ana)


func _process(dt: float) -> bool:
	t += dt
	if adim < kareler.size() and t >= kareler[adim][0]:
		var ad: String = kareler[adim][1]
		if ad == "menu":
			_kaydet(ad)
			ana._botlara_karsi()
			# yerel oyuncuyu bota çevir: kendisi oynasın (ekran görüntüsünde hareket olsun)
			var ben = ana.dunya.askerler[ana.dunya.yerel_id]
			ben.bot = preload("res://scripts/bot.gd").new(ben, ana.dunya, 5, 0.7)
		else:
			_kaydet(ad)
		adim += 1
	return adim >= kareler.size()


func _kaydet(ad: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://docs/ekran/%s.png" % ad)
	print("kaydedildi: ", ad)
