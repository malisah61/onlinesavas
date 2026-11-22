# Proje notları — Online Savaş

- Kullanıcıyla Türkçe konuş; oyundaki tüm metinler Türkçe. Önce `DERSLER.md` oku.
- Tür: 2D yukarıdan bakış, 2. Dünya Savaşı, **4'e 4 online takım çatışması** (Müttefik vs Mihver), boş yerleri botlar doldurur.
- Motor: Godot 4.3, GDScript, GL Compatibility, yatay 1280x720 (expand). Hedef: **Android APK + Web** (GitHub Pages, threads kapalı).
- Dosyalar (`scripts/`):
  - `ayarlar.gd` sabitler: Supabase adresi/anon anahtar, sınıflar (Piyade, Makineli, Keskin, Ağır), maç kuralları.
  - `harita.gd` tohumdan nokta simetrili harita; çarpışma/görüş/mermi yolu saf matematik; AStarGrid2D; çizim.
  - `asker.gd` asker durumu + görünüm; `sprite_sayfa.gd` Komando 8 yönlü sayfaları (k64).
  - `dunya.gd` maç simülasyonu (kurucu) / anlık görüntü uygulama (istemci), olaylar, takım görüşü.
  - `bot.gd` bot beyni (Komando guard.gd derslerinden), insanla aynı girdi.
  - `ag.gd` Supabase RPC + Realtime (Phoenix WebSocket: broadcast + presence). `hud.gd` arayüz + girdi. `ana.gd` menü/akış.
  - `fx.gd`, `ses.gd` kodla efekt ve ses.
- Ağ: kurucu otoriteli. İstemci → "g" girdi (≤10 Hz), kurucu → "s" anlık görüntü (10 Hz). Kurucu ayrılırsa presence'taki en eski
  (`giris` en küçük) üye devralır (`dunya.kurucuya_gec`).
- Sunucu: Supabase projesi `efsane-kartlar` (gqswczthqabfgiwtfege) içinde **os_ önekli** tablolar/fonksiyonlar (Efsane Kartlar'a dokunma).
- Varlıklar: `assets/sprites/k64/` (oyun sürümü), Sprite Atölye siparişi `assets/sprites/<ad>_sprite_sheet.png` getirir → `tools/kucult.py`
  (CI'da da çalışır). Sipariş listesi `assets/siparis.json`. Tek görseller `assets/uretilen/`.
- Testler: `tests/ag_testi.gd`, `tests/bot_testi.gd` (→ `docs/BOT_RAPORU.md`), `tests/canli_testi.gd` (CI, internet), `tests/ekran.gd` (xvfb → `docs/ekran/`).
- CI `derle.yml`: test → web (gh-pages) → APK (`son-surum`).
