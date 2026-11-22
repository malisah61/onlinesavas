# Online Savaş

1944 · Müttefik vs Mihver · **4'e 4 online takım çatışması** (2D, yukarıdan bakış). Boş yerleri botlar doldurur, internetsiz botlara karşı da oynanır.
Askerler [Komando](https://github.com/malisah61/komando)'nun 8 yönlü sprite'ları; yeni askerler, dekor ve ikonlar [Sprite Atölye](https://github.com/malisah61/sprite-atolye) sipariş hattıyla üretilir.

- **Web'de oyna:** https://malisah61.github.io/onlinesavas/
- **APK indir:** https://github.com/malisah61/onlinesavas/releases/latest/download/onlinesavas.apk
- Motor: Godot 4.3 (GDScript) · Sunucu: Supabase (oda eşleştirme, gerçek zamanlı kanal, sıralama)

## Nasıl oynanır
- **Hızlı maç:** açık bir odaya katılır ya da yenisini kurar. **Oda kur:** 5 harfli kodu arkadaşına ver, **Katıl** ile gelir.
- **Telefon:** sol yarı yürü, sağ yarı nişan (çubuk yarıdan fazla itilince ateş), BOMBA / DOLDUR düğmeleri.
- **PC:** WASD + fare, sol tık ateş, sağ tık / G bomba, R doldur, Tab skor, 1-4 sınıf.
- 40 öldürmeye ilk ulaşan ya da 6 dakika sonunda önde olan takım kazanır. Ölünce 4 sn sonra doğarsın; o sırada sınıf seçebilirsin.

## Sınıflar
| Sınıf | Silah | Not |
|---|---|---|
| Piyade | Tüfek | Dengeli, orta menzil |
| Makineli | Hafif makineli | Hızlı, yakın mesafe |
| Keskin | Dürbünlü tüfek | Tek atış ağır hasar, geniş görüş |
| Ağır | Makineli tüfek | Çok can, uzun şarjör, yavaş |

## Özellikler
- Tohumdan üretilen **adil (nokta simetrili) haritalar**: evler, taş duvarlar, kum torbası siperleri, sandıklar, tank enkazı, ağaçlar, toprak yol.
- **Siper:** kum torbası ve sandık, arkasındakini korur (mermiyi tutabilir); ev ve duvar görüşü de keser.
- **Takım görüşü:** düşman yalnız takımından birinin görebildiği yerde (ya da ateş edince) görünür.
- **Botlar** (Komando yapay zekâsından): görüş konisi, ses duyma, tepki gecikmesi, siper alma, kuşatma, tahminli arama, el bombası.
- Sağlık çantası ve bomba toplama, kendini yenileyen can, doğuşta kısa koruma.
- **Kurucu devri:** odayı kuran çıkarsa maç başka bir oyuncuda kaldığı yerden sürer.
- Online sıralama (puan: öldürme ×10 + zafer 50).

## Sprite Atölye ile yeni görsel üretmek
Sprite Atölye → Actions → **Sipariş (oyun repolarına toplu asset)** → hedef `malisah61/onlinesavas`. Liste: [`assets/siparis.json`](assets/siparis.json).
Askerler 3D'ye çevrilip Komando'nun 8 yön × 8 animasyon düzeninde render alınır; derleme bunları otomatik hafifletir (`tools/kucult.py`).

Geliştirme notları: [CLAUDE.md](CLAUDE.md) · Dersler: [DERSLER.md](DERSLER.md) · Bot raporu: [docs/BOT_RAPORU.md](docs/BOT_RAPORU.md)
