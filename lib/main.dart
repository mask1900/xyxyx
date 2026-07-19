import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Yandex Mobile Ads SDK sadece Android/iOS icindir. Web'de (orn. FlutLab
  // "preview" veya "flutter run -d chrome") native eklenti bulunamadigi
  // icin bu cagri hata firlatir; try/catch OLMADAN burada patlarsa runApp
  // hic cagrilmaz ve ekran bombos kalir. Bu yuzden kIsWeb ile atlanip,
  // ayrica beklenmedik bir hataya karsi da try/catch ile sarmalanir.
  if (!kIsWeb) {
    try {
      await YandexAds.initialize();
      // Ilk odullu reklam isteginin beklemeden gosterilebilmesi icin arka
      // planda onceden yuklemeyi baslat (hata olursa sessizce yutulur).
      unawaited(AdService.instance.preload());
    } catch (_) {
      // Reklam SDK'si baslatilamasa bile oyun asla acilmadan kalmasin.
    }
  }
  runApp(const CosmicSortApp());
}

class CosmicSortApp extends StatelessWidget {
  const CosmicSortApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Space Sort',
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
    );
  }
}
