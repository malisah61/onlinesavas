extends RefCounted
## Sabitler: sunucu, sürüm, sınıflar, maç kuralları. Tek yerden ayarlanır.

const SURUM := 1                     # ağ protokolü sürümü: farklı sürümler aynı odaya düşmez
const SURUM_ADI := "0.1"
const SUPABASE_URL := "https://gqswczthqabfgiwtfege.supabase.co"
# Herkese açık (anon) anahtar: yalnızca os_* RPC'lerini çağırabilir (RLS açık, tablolar kapalı).
const SUPABASE_ANON := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3djenRocWFiZmdpd3RmZWdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ5MTk1ODEsImV4cCI6MjExMDQ5NTU4MX0.sq9cZ1T8XV1gLzM3lFAKniNk1bMPKuD5ICTG2nZeLrY"

const TAKIM_BOYU := 4                # 4v4, boş yerleri botlar doldurur
const SKOR_HEDEF := 40
const MAC_SURE := 360.0              # sn
const DONUS_SURE := 4.0              # ölünce yeniden doğma
const KORUMA := 2.0                  # doğunca dokunulmazlık
const GORUNTU_HZ := 10.0             # kurucu → herkes anlık görüntü
const GIRDI_HZ := 10.0               # oyuncu → kurucu girdi

# Takımlar: 0 Müttefik, 1 Mihver
const TAKIM_AD := ["Müttefik", "Mihver"]
const TAKIM_RENK := [Color(0.35, 0.65, 1.0), Color(1.0, 0.38, 0.3)]

# Sınıflar. sprite: [müttefik, mihver] (Sprite Atölye siparişi gelince ilk bulunan kullanılır)
const SINIFLAR := [
	{"ad": "Piyade", "silah": "Tüfek", "hasar": 46.0, "aralik": 0.55, "menzil": 720.0, "sapma": 0.025, "sarjor": 8, "dolum": 1.8,
	 "hiz": 150.0, "can": 100.0, "ikon": "tufek",
	 "sprite": [["amerikan_er", "komando"], ["alman_er"]]},
	{"ad": "Makineli", "silah": "Hafif makineli", "hasar": 15.0, "aralik": 0.09, "menzil": 430.0, "sapma": 0.11, "sarjor": 30, "dolum": 2.0,
	 "hiz": 168.0, "can": 100.0, "ikon": "makineli",
	 "sprite": [["direnisci"], ["alman_elit"]]},
	{"ad": "Keskin", "silah": "Dürbünlü tüfek", "hasar": 96.0, "aralik": 1.35, "menzil": 1150.0, "sapma": 0.004, "sarjor": 5, "dolum": 2.6,
	 "hiz": 138.0, "can": 90.0, "ikon": "keskin",
	 "sprite": [["ingiliz_keskin", "pilot"], ["alman_subay"]]},
	{"ad": "Ağır", "silah": "Makineli tüfek", "hasar": 21.0, "aralik": 0.115, "menzil": 650.0, "sapma": 0.07, "sarjor": 75, "dolum": 4.0,
	 "hiz": 118.0, "can": 135.0, "ikon": "agir",
	 "sprite": [["komando"], ["alman_mg", "alman_er"]]},
]

const BOT_ADLARI := ["Reilly", "Blake", "Duval", "Kowalski", "Hans", "Fritz", "Otto", "Karl", "Jack", "Pierre",
	"Walter", "Ernst", "Tom", "Sam", "Henri", "Kurt"]
