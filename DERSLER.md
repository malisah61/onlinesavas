# Dersler — diğer oyunlardan alınanlar ve burada nasıl uygulandığı

**Kural (Sprite Atölye'den):** bir hata ikinci kez görülürse buraya yazılır. Her geliştirme turunda önce bu dosya okunur.

## Komando (malisah61/komando)
| Ders | Online Savaş'ta |
|---|---|
| Aynı sayfadan kurulan SpriteFrames her askerde yeniden kurulunca ~100 ms takılma | `sprite_sayfa.gd` önbelleği: her sayfa bir kez kurulur, herkes paylaşır |
| 128 px sayfalar (6,4 MB) web sürümünü öldürdü (web kaldırıldı) | `tools/kucult.py`: tüm karelerin ortak dolu kutusuna kırp + ×0,85 → 6 sayfa 6,5 MB. Kaynak sayfalar dışa aktarıma girmez |
| Boyut bütçesi her derlemede ölçülür | Sürüm notunda APK ve web boyutu |
| Botlarla bulutta oyna, sayılarla ölç (BOT_RAPORU) | `tests/bot_testi.gd` her derlemede 3 maç: skor dengesi, isabet, bomba, takılma, sınıf başına öldürme |
| Asker yapay zekâsı: koni + görüş hattı, koni dışı yakından fark etme, ses duyma, tetikte kalma, tahminli arama, kuşatma yönü, yaralanınca siper | `bot.gd` aynı katmanlarla; insanla aynı girdiyi üretir (hile yok, insanla yer değiştirebilir) |
| "Görülmek oyunu bitirmemeli" — ilk görüşte ölümcül olma | Tepki gecikmesi (0,2–0,6 sn) + nişan hatası maruz kaldıkça azalır |
| Siper (kum torbası, sandık) daha zor vurulmayı sağlar | Alçak siper mermiyi yalnız hedefin ~70 px yakınındaysa %55/%70 tutar; ev/taş duvar/tank tamamen |
| Doğrudan APK bağlantısı (son-surum) | Aynı: `releases/latest/download/onlinesavas.apk` |
| Gece görevi: "daha fazla değil daha iyi"; önce oyuncu notları | `docs/YOL_HARITASI.md` |

## Efsane Kartlar (malisah61/efsane-kartlar)
| Ders | Online Savaş'ta |
|---|---|
| Savaş sonucu istemcide hesaplanıyor → hile kapısı | Kurucu otoriteli: hasar, ölüm, skor yalnız kurucuda; istemci yalnız girdi yollar |
| Supabase: RLS açık, yazmalar `security definer` RPC'lerle, anon yalnız izinli fonksiyonları çağırır | `os_*` tabloları kapalı; yalnız `os_hizli_mac`, `os_oda_ac`, `os_oda_bul`, `os_oda_guncelle`, `os_oda_kapat`, `os_mac_sonucu`, `os_siralama` |
| Arayüz koddan, tek sahne | `ana.tscn` + `ana.gd` / `hud.gd` |
| Canlı sunucu testi ayrı iş akışı | `tests/canli_testi.gd`: iki bağlantı, presence + broadcast + RPC |
| JSON'u güvenli kütüphaneyle oku | Godot `JSON`; **sayılar float gelir** → skor gibi alanlar `int()` ile çevrilir (ağ testinde yakalandı) |

## Sprite Atölye (malisah61/sprite-atolye)
| Ders | Online Savaş'ta |
|---|---|
| Tarife elin ne yaptığı yazılır, tek silah | `assets/siparis.json` tariflerinde tek silah / boş el; asker siparişleri Komando hattı (T-poz, 8 yön × 8 animasyon) |
| Ticari kullanım (Google Play) → yalnız CC0 / ticari izinli | Dokular Poly Haven CC0, animasyon Quaternius UAL CC0, sesler kodla üretilir |
| Sipariş → Actions → hedef repoya PR | `assets/siparis.json` + Komando hattının ihtiyaç duyduğu `tools/blender` ve `kaynak/ual` bu repoda |
| Görsel yoksa oyun durmamalı | Harita, ikonlar ve dekor kodla çizilir; `assets/uretilen/<ad>.png` gelince otomatik onu kullanır |

## Kule Savunma
| Ders | Online Savaş'ta |
|---|---|
| Oyuncu geniş (20:9) telefonda oynuyor | `stretch aspect = expand`, arayüz kenarlara çapalı, ortası boş; sanal çubuklar dokunulan yerde belirir |

## Bu projede öğrenilenler
| Tarih | Görülen | Ders |
|---|---|---|
| 23 Kasım | SceneTree testinde `_init` içinde eklenen düğümlerin `_ready`'si çalışmadı | Test betikleri `_initialize` kullanır; `Dunya` alt düğümlerini `_init`'te kurar |
| 23 Kasım | Yeni PNG'ler içe aktarılmadan ekran görüntüsünde askerler görünmedi | Önce `godot --headless --import` |
| 23 Kasım | Asker 128 px karede ~%40 yer kaplıyor; sadece küçültmek bulanık ve minik yaptı | Önce ortak kutuya kırp, sonra ölçekle (×0,85 sayfa, ×1,3 gösterim) |
| 23 Kasım | Supabase ücretsiz Realtime: mesaj kotası sınırlı | 10 Hz görüntü (~0,6 KB), girdi yalnız değişince (en çok 10 Hz) |
