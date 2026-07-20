import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/gdpr_service.dart';
import 'theme/app_colors.dart';

/// GECICI HATA AYIKLAMA YARDIMCISI (kod, USB/adb/flutter olmadan, sadece
/// telefondaki ekran goruntusuyle hatayi tespit edebilmek icin eklendi):
/// - Bir widget build/layout sirasinda patlarsa: o alanda bombos yer
///   kalmak yerine KIRMIZI YAZIYLA tam hata + stack trace gosterilir.
/// - Bir Future/Timer/async kod icinde (build disinda) patlarsa: ekranin
///   EN USTUNDE kirmizi bir serit (banner) olarak gosterilir; serite
///   dokununca tam hata metni acilir.
/// Sorun bulunup duzeltildikten sonra bu blok tamamen kaldirilabilir.
final ValueNotifier<String?> _lastAsyncError = ValueNotifier<String?>(null);

void _installVisibleErrorReporting() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(12),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Text(
            '⚠️ WIDGET HATASI:\n\n${details.exceptionAsString()}\n\n${details.stack}',
            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
          ),
        ),
      ),
    );
  };
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    // Konsola da yazdirmaya devam et (logcat/CI loglarinda da gorunsun).
    originalOnError?.call(details);
    FlutterError.presentError(details);
    _lastAsyncError.value = details.exceptionAsString();
  };
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    _installVisibleErrorReporting();
    // Yandex Mobile Ads SDK sadece Android/iOS icindir. Web'de (orn. FlutLab
    // "preview" veya "flutter run -d chrome") native eklenti bulunamadigi
    // icin bu cagri hata firlatir; try/catch OLMADAN burada patlarsa runApp
    // hic cagrilmaz ve ekran bombos kalir. Bu yuzden kIsWeb ile atlanip,
    // ayrica beklenmedik bir hataya karsi da try/catch ile sarmalanir.
    if (!kIsWeb) {
      try {
        await YandexAds.initialize();
        // GDPR: Yandex Mobile Ads SDK'nin resmi kurallarina gore, kullanicinin
        // rizasi UYGULAMA HER ACILDIGINDA yeniden SDK'ya iletilmelidir. Daha
        // once kaydedilmis bir tercih varsa (veya AB disindaysa) burada
        // hemen gonderilir; Kullanim Sartlari/GDPR popup'i ise ana ekranda
        // (henuz onaylanmadiysa) ayrica gosterilir.
        await GdprService.instance.load();
        // Ilk odullu reklam isteginin beklemeden gosterilebilmesi icin arka
        // planda onceden yuklemeyi baslat (hata olursa sessizce yutulur).
        unawaited(AdService.instance.preload());
      } catch (_) {
        // Reklam SDK'si baslatilamasa bile oyun asla acilmadan kalmasin.
      }
    }
    runApp(const CosmicSortApp());
  }, (error, stack) {
    // Widget build disinda (Future/Timer/async) yakalanamayan HER hata
    // buraya duser; ekranda banner olarak gosterelim ki loglara bakmadan
    // da telefondan ekran goruntusuyle tespit edilebilsin.
    _lastAsyncError.value = '$error\n\n$stack';
  });
}

class CosmicSortApp extends StatelessWidget {
  const CosmicSortApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AstroFelyx: Galaxy Puzzle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.spaceTop,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            ValueListenableBuilder<String?>(
              valueListenable: _lastAsyncError,
              builder: (context, err, _) {
                if (err == null) return const SizedBox.shrink();
                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Hata detayı'),
                          content: SingleChildScrollView(
                            child: Text(err,
                                style: const TextStyle(fontSize: 11)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Kapat'),
                            ),
                          ],
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        color: Colors.red.shade900,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Text(
                          '⚠️ Hata oluştu — detay için dokun: ${err.split('\n').first}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
