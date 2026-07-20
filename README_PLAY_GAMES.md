# Play Games Entegrasyonu — Sadece Giriş + İlerleme Kaydı

Bu sürümde Play Games'e SADECE şunlar için bağlanılıyor:
- Google hesabıyla giriş
- Oyuncunun ilerlemesini (bölümler, XP, yıldızlar, envanterdeki haklar
  vb.) "Saved Games" (Play Games'in bulut kayıt özelliği) ile senkronize
  etmek — yani telefon değişse veya oyun silinip yeniden yüklense bile
  ilerleme kaldığı yerden devam eder.

Skor tablosu (leaderboard) ve başarımlar (achievements) BİLEREK
eklenmedi — istemediğini söyledin.

## Nasıl çalışıyor (kod tarafı — zaten hazır)

- `lib/services/play_games_service.dart` — giriş + bulut kayıt yazma/okuma
- `lib/services/cloud_progress_sync.dart` — yerel kayıt ile buluttaki
  kaydı karşılaştırıp hangisi daha ileriyse onu esas alır (veri kaybı
  olmaz)
- Splash ekranında: yerel ilerleme yüklenir → Play Games'e sessizce
  giriş denenir → başarılıysa bulutla senkronize edilir
- Her yerel kayıt (`PlayerProgress.save()`) sonrası, bağlıysa buluta da
  otomatik yazılır
- Profil ekranında "Play Games'e Bağlan" butonu (manuel giriş için)
- Native (Android/Kotlin) tarafı: `android/.../MainActivity.kt` — asıl
  Play Games Saved Games (Snapshot) API'siyle konuşan kısım burada

## Senin yapman gereken kurulum adımları (Play Console)

Bunları ben senin adına yapamam, kendi Play Console hesabından
tamamlaman lazım:

1. **Gerçek bir applicationId belirle.** Şu an
   `android/app/build.gradle` içinde yer tutucu olarak
   `com.example.space_sort_game` yazıyor, kendi paket adınla değiştir.

2. **Play Console'da uygulamanı oluştur**, sonra *Play Games Services*
   bölümünden yeni bir oyun yapılandırması aç. Bu sana bir **App ID**
   verir.

3. Bu App ID'yi `android/app/src/main/AndroidManifest.xml` içindeki
   şu satıra yapıştır:
   ```xml
   <meta-data
       android:name="com.google.android.gms.games.APP_ID"
       android:value="YOUR_PLAY_GAMES_APP_ID_HERE" />
   ```
   (`YOUR_PLAY_GAMES_APP_ID_HERE` kısmını değiştir.)

4. **İmza sertifikanın SHA-1 parmak izini** Play Console'daki Play
   Games Services yapılandırmana ekle — bu olmadan giriş çalışmaz.
   Test için hem debug hem de (yayınlarken kullanacağın) release
   imzasının SHA-1'ini eklemen gerekir.

5. Play Console'da *Play Games Services* ayarlarında **"Saved Games"
   (bulut kayıt) özelliğini etkinleştirdiğinden emin ol** — bazı
   projelerde bu ayrı bir onay/checkbox olarak karşına çıkabilir.

6. `flutter pub get` çalıştır, ardından **gerçek bir Android
   cihazda/emülatörde** (Google Play Services yüklü) test et. Bu
   özellik flutlab.io gibi tarayıcı tabanlı önizlemelerde ÇALIŞMAZ —
   native Google Play Services ve gerçek bir imzalı derleme gerektirir.

## Önemli not — dürüst olmak gerekirse

`MainActivity.kt` içindeki Snapshot (Saved Games) kodu, Google'ın Play
Games Services v2 SDK'sının bilinen yapısına göre yazıldı, ama bu ortamda
(Android SDK/emülatör olmadığı için) gerçekten derlenip test edilemedi.
İlk `flutter build apk` denemesinde bir sınıf/metod adı uyuşmazlığı
çıkarsa (ör. Google bir isimlendirmeyi değiştirmişse), hata mesajındaki
sınıf adını arayıp güncel Play Games Services v2 "Snapshots" örnek
koduyla karşılaştırman yeterli olur — genel akış (aç → yaz/oku → kapat)
aynı kalacaktır. Bunu test aşamasında ilk denediğinde bana derleme
hatasını yapıştırırsan birlikte düzeltiriz.

## Test ederken dikkat et

- Uygulamayı ilk kez Play Games'e bağlı bir hesapla açtığında, hesapta
  daha önce kayıt yoksa "buluta yükle" olarak davranır (veri kaybı
  riski yok).
- Bir cihazda ilerleyip Play Games'e bağlanmadan önce ilerlemiş, sonra
  başka cihazda bağlanmışsan: hangi cihazın toplam skoru daha yüksekse
  o taraf esas alınır.
- Google Play "dahili test" / "kapalı test" aşamasında Play Games
  Services genelde sorunsuz çalışır; sadece test hesabının Play
  Console'daki test kullanıcıları listesinde olması gerekebilir.
