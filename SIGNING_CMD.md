# Cmd ile İmzalama (GitHub Actions'tan gelen imzasız çıktı için)

GitHub Actions workflow'u (`.github/workflows/build.yml`) artık gerçekten
**imzasız** bir `app-release.apk` ve `app-release.aab` üretiyor (Artifacts
sekmesinden indir). Bunları kendi AstroFelyx keystore'un ile aşağıdaki
komutlarla imzala.

Gereken araçlar: Java JDK (jarsigner için) ve Android SDK build-tools
(apksigner + zipalign için) — Android Studio kuruluysa ikisi de zaten var.

## 1) AAB (Play Store'a yüklenecek asıl dosya)

AAB, `jarsigner` ile imzalanır (Play Console / bundletool bunu kabul eder):

```bash
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore /path/to/astrofelyx-release-key.jks \
  app-release.aab \
  KEY_ALIAS

# imzayı doğrula
jarsigner -verify -verbose -certs app-release.aab
```

`KEY_ALIAS` yerine keystore'unu oluştururken verdiğin alias'ı yaz.
Şifreyi soracak (keystore şifresi + varsa key şifresi).

Bu adımdan sonra **aynı `app-release.aab` dosyası** imzalı hale gelir
(ayrı bir çıktı dosyası oluşmaz) — bunu doğrudan Play Console →
Production → "Yeni sürüm oluştur" kısmına yükleyebilirsin.

## 2) APK (istersen ayrıca / test için)

APK'lar modern imza şeması (v2/v3) gerektirdiği için `jarsigner` değil
**`apksigner`** kullanılmalı (Android SDK `build-tools/<versiyon>/` içinde):

```bash
# once hizalama (zipalign)
zipalign -v -p 4 app-release-unsigned.apk app-release-aligned.apk

# sonra imzalama
apksigner sign --ks /path/to/astrofelyx-release-key.jks \
  --ks-key-alias KEY_ALIAS \
  --out app-release-signed.apk \
  app-release-aligned.apk

# dogrulama
apksigner verify app-release-signed.apk
```

## Notlar

- `key.properties` dosyasını Gradle'a eklemene gerek YOK bu akışta — CI
  zaten imzasız derliyor, sen yerelde imzalıyorsun. `key.properties`
  sadece `flutter build appbundle --release`'i **kendi bilgisayarında**
  komple imzalı almak istersen lazım (bkz. `android/key.properties.example`).
- Hangi keystore/alias olduğundan emin değilsen: mevcut yayındaki
  AstroFelyx'i imzalarken kullandığın dosya/alias/şifre neyse **birebir
  aynısı** olmalı, yoksa Play Store güncellemeyi reddeder ("imza
  uyuşmazlığı" hatası).
