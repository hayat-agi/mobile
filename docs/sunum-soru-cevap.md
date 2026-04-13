# Hayat Ağı — Sunum Soru-Cevap Hazırlığı

Hedef kitle: Teknik ve iş dünyasından profesyoneller. Sorular sistemin genel mantığına, güvenilirliğine ve pratik değerine odaklanacaktır.

---

## 1. Sistem Mimarisi

**S: İnternet olmadan nasıl çalışıyor? Mesajlar nereye gidiyor?**

Telefon BLE ile yakındaki ESP32 gateway'e bağlanır. Gateway bu mesajları toplar; varsa internet üzerinden backend'e iletir, yoksa lokal olarak saklar. Felaket anında kritik ilk halka: survivor → telefon → ESP32 gateway.

---

**S: Telefonlar neden doğrudan birbirleriyle haberleşmiyor, neden ESP32 araya giriyor?**

BLE mesh henüz yaygın bir standart değil ve pil tüketimi çok yüksek. ESP32 sabit bir hub görevi görüyor; binaya monte edilebilir, harici güç alabiliyor. Telefonlar kısa süreliğine bağlanıp mesajı bırakıp gidebilir, böylece pil korunur.

---

**S: Bir gateway kaç kişiye hizmet edebilir?**

Aynı anda 3 aktif BLE bağlantısı. Ancak 20 cihaza kadar kayıt tutulabiliyor. Sistem sıralı çalışıyor: telefon bağlanır, mesajı bırakır (max 3 mesaj/oturum), bağlantıyı keser, sıradaki telefon bağlanır.

---

**S: Gateway'lerin nasıl dağıtılması planlanıyor? Kim kuracak?**

Camilere, muhtarlıklara, okullara, apartman girişlerine önceden kurulu olması hedefleniyor. Kurulum teknik bilgi gerektirmiyor: güce bağla, aktivasyon şifresi gir, çalışmaya başlar. İdeal senaryo: belediye veya AFAD koordinasyonuyla kritik noktalara önceden konuşlandırılmış gateway'ler.

---

## 2. Güvenilirlik

**S: Bağlantı kopuksa mesaj kaybolur mu?**

Hayır. Persistent queue mekanizması var. Mesaj önce telefonda diske yazılıyor, bağlantı sağlandığında otomatik gönderiliyor. "Fire and forget" değil, "never drop" prensibi.

---

**S: Aynı anda 10–15 telefon mesaj göndermek isterse ne olur?**

Randomized backoff ile retry sistemi var. Her telefon farklı aralıklarla yeniden deniyor (2–15 saniye arası). Max 12 retry. Kimse gateway'i tekelleştiremez; bir oturumda en fazla 3 mesaj gönderildikten sonra bağlantı kesiliyor, sıra diğerine geçiyor.

---

**S: Gateway'in elektriği kesilirse ne olur?**

Depremlerde elektrik kesintisi bekleniyor. Bu nedenle gateway'in UPS veya güneş enerjisi gibi alternatif güç kaynaklarıyla desteklenmesi gerekiyor. Bu sistemin dışında kalan bir altyapı sorusu; deployment planının parçası olmalı.

---

**S: Pil biterse sistem çöküyor mu?**

Felakette pil optimizasyon servisi devreye giriyor: ekran parlaklığı düşürülüyor, arka plan işlemleri azaltılıyor. Ayrıca fener ve sesli uyarı özellikleri var — telefon artık mesaj gönderemese bile hayatta olduğunu belirtmek için kullanılabiliyor.

---

## 3. Deprem Tespiti

**S: Telefonu sallarsan yanlış alarm verir mi?**

İki katmanlı koruma var:
1. **Jiroskop vetosu** — insan sallaması rotasyonel hareket içerir, deprem saf translasyonel; jiroskop bunu ayırt ediyor.
2. **Durağanlık kapısı** — telefon elde tutuluyorsa tespit hiç başlamıyor.

---

**S: Algoritma nasıl çalışıyor?**

İki katmanlı:
- **Layer 1:** STA/LTA (kısa dönem / uzun dönem enerji oranı) — sürekli çalışan, düşük maliyetli ilk tetikleyici.
- **Layer 2:** IQR, sıfır geçiş oranı, CAV, kurtosis — sadece Layer 1 tetiklendiğinde çalışır. Depremin frekans ve enerji imzasını doğrular.

Gerçek AFAD/KOERI deprem kayıtlarıyla (3 farklı istasyon) test edildi.

---

**S: Bu sistem neden mevcut AFAD uyarı sisteminin yerini almıyor?**

Almayı hedeflemiyor. AFAD erken uyarı sistemi depremi önceden bildiriyor; bu sistem depremin *sonrasında* hayatta kalanların konum ve durumunu iletmek için. Birbirini tamamlayan sistemler.

---

## 4. Triaj Sistemi

**S: Triaj skoru neye göre hesaplanıyor, doktor mu gerekiyor?**

Kullanıcı kendi durumunu seçiyor: güvende / yaralı / mahsur. Altına yaralanma tipi, durum ve ihtiyaç chip'leri ekleniyor. Her seçim skora katkı yapıyor (0–255). Yardım ekipleri önceliklendirme için bu skoru kullanıyor — tıbbi karar değil, kaynak yönlendirme aracı.

---

**S: Neden 15 dakikalık bekleme var, acil durum değil mi?**

Evet acil durum, ama aynı anda binlerce kişi gateway'e mesaj göndermeye çalışırsa kanal kilitlenir. 15 dakika hem kanalı korur hem de aynı kişinin gereksiz tekrar göndermesini engeller. Durum değişirse (güvenden yaralıya geçiş gibi) bekleme sıfırlanıyor.

---

**S: Yardım ekipleri bu verileri nasıl görüyor?**

Bu, backend ve komuta merkezi ekibinin geliştirdiği alan. Mobil uygulama veriyi ESP32 üzerinden backend'e iletir; oradan yardım ekiplerine yönelik bir dashboard'da görselleştiriliyor. Bu sunum mobil + BLE katmanını kapsıyor.

---

## 5. Güvenlik

**S: Herhangi biri gateway'e bağlanıp sahte SOS gönderemez mi?**

Cihaz ilk kurulumda aktivasyon şifresiyle korunuyor. 5 hatalı denemede 1 dakika kilit. Şifre doğru girilmeden gateway mesaj kabul etmiyor. Protokol: bağlantı → `NEED_ACTIVATION` → şifre → `ACTIVATED`.

---

**S: Kullanıcı verisi nerede saklanıyor, gizlilik var mı?**

Sağlık profili ve hane bilgileri telefonda şifreli depolanıyor (flutter_secure_storage). BLE üzerinden gönderilen paket sadece anlık durum + triaj bilgisi; kimlik bilgisi içermiyor. Uzun vadeli depolama backend politikasına bağlı.

---

## 6. Ölçeklenebilirlik & Pratik Değer

**S: Büyük bir depremde binlerce kişi aynı anda kullanırsa ne olur?**

Tek gateway kapasitesi sınırlı, bu yüzden sistem çok gateway'li topoloji varsayıyor. Her gateway kendi yakın çevresine hizmet eder. Darboğaz gateway yoğunluğu değil, gateway sayısı ve dağılımı — bu da önceden planlama gerektiriyor.

---

**S: Yaşlılar ve teknoloji bilmeyen kişiler kullanabilir mi?**

Tasarım bunun için yapıldı: tek büyük buton "Felaket Modunu Aç", chip'ler sembolik ve kısa metinli. Metin-ses (TTS) ve ses-metin özellikleri de dahil — el kullanımı kısıtlı kişiler için. Uygulamanın önceden yüklenmiş ve gateway'e kayıtlı olması gerekiyor; bu yüzden "deprem öncesi hazırlık" sistemin kritik parçası.

---

**S: Benzer çözümler var mı, bu sistemin farkı ne?**

Gotennet, Meshtastic gibi mesh radio çözümleri var. Farkımız: akıllı telefon ekosistemini kullanıyor (ek donanım gerektirmiyor), triaj protokolü var (sadece "hayattayım" mesajı değil), yerel kuruma entegrasyon için tasarlandı. Dezavantaj: BLE menzili WiFi/LoRa'dan kısa.

---

**S: Sistem prototip mi, production-ready mi?**

Şu anki haliyle fonksiyonel bir prototip. Gerçek deployment için gateway güç yönetimi, saha testi ve kurumsal entegrasyon gerekiyor. Akademik proje kapsamında değerlendirilmeli; temel altyapı çalışıyor.

---

*Hazırlayan: Hayat Ağı Mobil & BLE Ekibi — Nisan 2026*
