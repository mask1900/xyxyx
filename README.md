# Cosmic Sort — Uzay Temali Sort Bulmaca Oyunu

Flutter + Dart ile yazilmis, klasik "renk/enerji siralama" (water/ball sort)
mekanigine sahip, uzay temali bir bulmaca oyunu.

## Onemli tasarim kararlari

- **Hicbir dis kaynak yok.** Yildizlar, nebulalar, enerji kapsulleri (tupler)
  ve toplarin tamami `CustomPainter` / `Canvas` / `Path` (Flutter'in dahili
  vektorel cizim API'si) ile koddan ciziliyor. Ne bir `.svg` dosyasi, ne bir
  `.png` asset'i, ne de network'ten cekilen bir gorsel var. `pubspec.yaml`
  icinde bilerek `assets:` tanimlanmadi.
- **Sifir ekstra runtime paketi.** Sadece Flutter SDK'nin kendisi kullanildi
  (`cupertino_icons` yalnizca ikon fontu icin, o da Flutter'in resmi
  paketi). Bu, FlutLab gibi ortamlarda paket cakismasi/versiyon sorunu
  yasama riskini en aza indiriyor.
- **Cozulebilirlik garantisi.** Her bolum, "cozulmus" (her tup tek renk)
  durumdan baslanip oyunun kendi gecerli hamle kurallariyla geriye dogru
  rastgele karistirilarak uretiliyor (`GameController._shuffleFromSolved`).
  Bu, bu turden sort/water-sort oyunlarinda yaygin kullanilan standart
  uretim teknigidir.
- **Kademeli ama yorucu olmayan zorluk.** `lib/game/level_config.dart`
  icinde: renk sayisi her 2 bolumde bir +1 artiyor (en fazla 10 renk),
  bos tup sayisi uzun sure 2'de sabit kaliyor (cozulebilirligi kolaylastirir,
  ekrani karistirmaz), karistirma yogunlugu bolum arttikca kademeli artiyor.
  Sinirsiz "geri al", "yeniden karistir" ve "ipucu" butonlari var; oyuncu
  hicbir zaman tikilip kalmiyor.

## Dosya yapisi

```
space_sort_game/
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
├── android/                        # Calisir durumda Android native projesi
│   ├── build.gradle
│   ├── settings.gradle
│   ├── gradle.properties
│   ├── gradle/wrapper/gradle-wrapper.properties
│   └── app/
│       ├── build.gradle
│       └── src/
│           ├── main/
│           │   ├── AndroidManifest.xml
│           │   ├── kotlin/com/example/space_sort_game/MainActivity.kt
│           │   └── res/
│           │       ├── values/{styles.xml,colors.xml}
│           │       ├── drawable/launch_background.xml
│           │       ├── drawable-v21/launch_background.xml
│           │       └── mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png
│           ├── debug/AndroidManifest.xml
│           └── profile/AndroidManifest.xml
├── ios/                             # SADECE FlutLab yukleyici kontrolu icin
│   ├── Podfile                      # minimal yer tutucu - gercek iOS
│   ├── Runner/{Info.plist,AppDelegate.swift}   # derlemesi icin yeterli
│   └── Flutter/{AppFrameworkInfo.plist,Debug.xcconfig,Release.xcconfig}  # degildir
├── lib/
│   ├── main.dart                  # Uygulama giris noktasi
│   ├── theme/
│   │   └── app_colors.dart        # Renk paleti (uzay + enerji renkleri)
│   ├── models/
│   │   └── tube.dart              # Tek bir tup/kapsul veri modeli
│   ├── game/
│   │   ├── level_config.dart      # Bolume gore zorluk hesaplama
│   │   └── game_controller.dart   # Oyun mantigi: uretim, hamle, undo, kazanma
│   ├── widgets/
│   │   ├── space_background.dart  # Animasyonlu yildiz/nebula arka plani (CustomPainter)
│   │   ├── tube_widget.dart       # Kapsul + enerji toplarinin vektorel cizimi
│   │   ├── game_hud.dart          # Ust bar: bolum no, hamle sayaci, undo/restart/ipucu
│   │   └── win_dialog.dart        # Bolum tamamlandi dialogu
│   └── screens/
│       ├── home_screen.dart       # Ana menu
│       └── game_screen.dart       # Oyun ekrani (tup grid'i + etkilesim)
└── test/
    ├── widget_test.dart           # Temel UI smoke testleri
    └── game_logic_test.dart       # Tube/GameController/LevelConfig birim testleri
```

## Nasil calistirilir

Bu proje artik **calisir durumda bir `android/` klasoru** iceriyor (Gradle
build dosyalari, `AndroidManifest.xml`, `MainActivity.kt`, uzay temali
launcher ikonu vb.). Ayrica FlutLab'in yukleme sirasinda "ios/ klasoru da
gerekli" seklinde vermesi muhtemel benzer bir hatayi onlemek icin minimal
bir `ios/` **yer tutucu** klasoru de eklendi — ama bu proje **sadece
Android'de calistirilmak** icin hazirlandi, iOS tarafi gercekten
derlenebilir/calistirilabilir durumda degil (Xcode proje dosyalari
kasitli olarak dahil edilmedi, cunku bunlar cok karmasik/hataya acik
ikili+xml dosyalar ve sizin ihtiyaciniz yok).

### Yontem A — FlutLab.io (tarayicida, kurulum gerektirmez)
1. https://flutlab.io adresine girip ucretsiz hesap ac / giris yap.
2. "New Project" → "Upload zip" ile bu zip dosyasini yukle.
3. Artik `android/` klasoru mevcut oldugu icin ilk hatayi almayacaksiniz.
   `ios/` icin de benzer bir uyari cikarsa, klasor zaten zip'te mevcut
   oldugundan gecmesi gerekir (icerigi minimal olsa da).
4. Sag ust "Run" (yesil play) butonuna basip **Android** hedefini secin.
   iOS hedefini secmeyin; bu proje onun icin hazirlanmadi.

### Yontem B — GitHub + Yerel Flutter SDK (sadece Android)
```bash
# 1) Zip'i ac ve klasore gir
unzip space_sort_game.zip
cd space_sort_game

# 2) Bagimliliklari indir
flutter pub get

# 3) Bagli bir Android cihaz/emulatorde calistir
flutter run -d android

# 4) Testleri calistir
flutter test
```

> Not: `android/gradlew`, `android/gradlew.bat` ve
> `android/gradle/wrapper/gradle-wrapper.jar` (ikili dosya) bilerek
> dahil edilmedi. Yerel makinenizde ilk `flutter pub get` / `flutter run`
> calistirmasinda Flutter tool bunlari otomatik tamamlar/uretir. Eger
> gradlew ile ilgili bir hata gorurseniz, tek seferlik `flutter create .`
> komutunu proje kok dizininde calistirmaniz eksik sarmalayici (wrapper)
> dosyalarini tamamlayacaktir (mevcut `lib/`, `pubspec.yaml` ve elle
> yazdigimiz `android/` dosyalarinizin uzerine yazmaz, sadece eksik
> parcalari ekler).

### Yontem C — GitHub Codespaces / VS Code (Flutter eklentisi kurulu)
Ayni adimlar (`flutter pub get` → `flutter run -d android`) VS Code
terminalinde de calisir.

## Oynanis

- Bir kapsule dokunarak sec (kaynak).
- Ustu ayni renkte olan veya tamamen bos baska bir kapsule dokun; enerji
  oraya akar.
- Butun kapsuller tek renge donuşunce (ya da bossa) bolum biter.
- Ust bardaki ampul ikonu bir sonraki gecerli hamleyi 2 saniyeligine
  vurgular; geri al ve yeniden karistir butonlari sinirsizdir.

## Genisletme fikirleri (opsiyonel)

- Kalici ilerleme icin `shared_preferences` paketi eklenip
  `HomeScreen._reachedLevel` degeri diske yazilabilir.
- Ses efekti icin `audioplayers`/`just_audio` eklenebilir (yine de dosya
  yerine kod-uretimli tonlar `SoundPool`/senkron osilator ile de
  yapilabilir, boylece "dis kaynak yok" ilkesi korunur).
- Yildiz derecelendirme (1-3 yildiz), hamle sayisina gore hesaplanabilir
  (`GameController.moveCount` zaten mevcut).
