"""Sprite Atölye / Komando 8 yönlü sayfalarını (128 px kare) oyunun hafif sürümüne çevirir.
python3 tools/kucult.py [kaynak_klasor] [hedef_klasor]
Kaynak: assets/sprites/<ad>_sprite_sheet.png + .json (Sprite Atölye siparişi buraya teslim eder)
Hedef:  assets/sprites/k64/<ad>.png + .json (oyun bunu yükler; büyük kaynak dışa aktarıma girmez)

Ders (Komando): 128 px karede asker karenin ~%40'ı; boş alan dosyayı şişirir, sadece küçültmek ise
bulanıklaştırır. Önce tüm karelerin ortak dolu kutusuna kırp, x0.85: keskin ve ~5 kat küçük.
"""
import glob
import json
import os
import sys

from PIL import Image

src = sys.argv[1] if len(sys.argv) > 1 else "assets/sprites"
dst = sys.argv[2] if len(sys.argv) > 2 else "assets/sprites/k64"
OLCEK = 0.85
os.makedirs(dst, exist_ok=True)
for png in sorted(glob.glob(f"{src}/*_sprite_sheet.png")):
    ad = os.path.basename(png).replace("_sprite_sheet.png", "")
    lay = json.load(open(png[:-4] + ".json"))
    out_png, out_js = f"{dst}/{ad}.png", f"{dst}/{ad}.json"
    if os.path.exists(out_png) and os.path.getmtime(out_png) >= os.path.getmtime(png):
        continue
    fs = int(lay["frame"])
    cols = int(lay.get("cols", 16))
    im = Image.open(png).convert("RGBA")
    rows = im.height // fs
    A = im.getchannel("A").point(lambda v: 255 if v > 20 else 0)
    x0 = y0 = fs
    x1 = y1 = 0
    for r in range(rows):
        for c in range(cols):
            b = A.crop((c * fs, r * fs, c * fs + fs, r * fs + fs)).getbbox()
            if b:
                x0, y0, x1, y1 = min(x0, b[0]), min(y0, b[1]), max(x1, b[2]), max(y1, b[3])
    x0, y0 = max(0, x0 - 2), max(0, y0 - 2)
    x1, y1 = min(fs, x1 + 2), min(fs, y1 + 2)
    cw, ch = x1 - x0, y1 - y0
    fw, fh = round(cw * OLCEK), round(ch * OLCEK)
    out = Image.new("RGBA", (fw * cols, fh * rows))
    for r in range(rows):
        for c in range(cols):
            kare = im.crop((c * fs + x0, r * fs + y0, c * fs + x1, r * fs + y1)).resize((fw, fh), Image.LANCZOS)
            out.paste(kare, (c * fw, r * fh))
    out.putalpha(out.getchannel("A").point(lambda v: 0 if v < 10 else v))
    out.save(out_png, optimize=True)
    pv = lay.get("pivot", [fs / 2, fs * 0.62])
    lay.update({"frame": fw, "fw": fw, "fh": fh, "pivot": [round((pv[0] - x0) * OLCEK, 2), round((pv[1] - y0) * OLCEK, 2)]})
    lay.pop("display_px", None)
    json.dump(lay, open(out_js, "w"), ensure_ascii=False, indent=1)
    print(f"{ad}: kare {fw}x{fh}, sayfa {out.width}x{out.height}, {os.path.getsize(out_png) // 1024} KB")

# Sprite Atölye'den gelen tek görseller (1024 px) → oyunda en çok 384 px (ikonlar 192 px). Dosya boyutu ~10 kat düşer.
for png in sorted(glob.glob("assets/uretilen/*.png")):
    im = Image.open(png)
    sinir = 192 if os.path.basename(png).startswith("ikon_") else 384
    if max(im.size) > sinir:
        im = im.convert("RGBA")
        bb = im.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox()
        if bb:
            im = im.crop(bb)
        im.thumbnail((sinir, sinir), Image.LANCZOS)
        im.save(png, optimize=True)
        print(f"{png}: {im.size[0]}x{im.size[1]}")
