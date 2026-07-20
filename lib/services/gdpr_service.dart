import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

/// Kullanım Şartları / Gizlilik Politikası onayını ve AB (GDPR) reklam
/// rızasını yöneten, cihaz üzerinde kalıcı olarak (SharedPreferences)
/// saklayan basit bir ChangeNotifier singleton.
///
/// * Tamamen ücretsiz ve limitsiz çalışır: hiçbir 3. parti "Consent
///   Management Platform" (CMP) servisine veya ağ isteğine ihtiyaç
///   duymaz — bölge tespiti tamamen cihazın kendi Locale bilgisinden
///   (ülke/bölge kodu) yerel olarak yapılır.
/// * AB üyesi olmayan ülkelerde (ör. Türkiye) GDPR ekranı/ayarı hiç
///   gösterilmez; kullanıcı sadece standart "Kabul Et ve Devam Et"
///   akışını görür ve reklamlar varsayılan (kişiselleştirilmiş) olarak
///   çalışır.
/// * AB/AEA/İsviçre/Birleşik Krallık bölgesindeki kullanıcılara -
///   hangi dili konuşursa konuşsun (cihazın BÖLGE koduna bakılır, dile
///   değil) - kişiselleştirilmiş/kişiselleştirilmemiş reklam seçimi
///   sorulur ve bu seçim istediği zaman Profil ekranından değiştirilebilir.
/// * Seçilen rıza değeri, Yandex Mobile Ads SDK'sına
///   `YandexAds.setUserConsent(...)` ile iletilir (uygulama her
///   başladığında yeniden gönderilir; bkz. main.dart).
class GdprService extends ChangeNotifier {
  GdprService._();
  static final GdprService instance = GdprService._();

  static const _kTermsAccepted = 'legal_terms_accepted_v1';
  static const _kConsentChoice = 'legal_gdpr_ads_consent_v1';
  static const _kIsEU = 'legal_is_eu_user_v1';

  bool _termsAccepted = false;
  bool _adsConsent = true;
  bool _isEUUser = false;
  bool _loaded = false;

  /// Kullanım Şartları & Gizlilik Politikası onaylandı mı?
  bool get termsAccepted => _termsAccepted;

  /// Kişiselleştirilmiş reklamlara rıza verildi mi? (AB dışı kullanıcılar
  /// için bu her zaman true kabul edilir; GDPR sadece AB/AEA/İsviçre/UK
  /// bölgesindeki kullanıcılar için anlamlıdır.)
  bool get adsConsent => _adsConsent;

  /// Cihaz, AB/AEA/İsviçre/Birleşik Krallık bölgesinde mi? (GDPR ayarı
  /// sadece bu durumda gösterilir.)
  bool get isEUUser => _isEUUser;

  bool get loaded => _loaded;

  /// İlk açılıştaki sözleşme/GDPR popup'ının gösterilmesi gerekiyor mu?
  bool get needsConsentPrompt => _loaded && !_termsAccepted;

  /// Uygulama en başlarken (main.dart içinde, runApp'ten önce) çağrılmalı.
  /// Kayıtlı tercihleri okur ve mevcut rızayı Yandex SDK'sına iletir.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(_kIsEU)) {
      _isEUUser = prefs.getBool(_kIsEU) ?? false;
    } else {
      _isEUUser = _detectEU();
      await prefs.setBool(_kIsEU, _isEUUser);
    }

    _termsAccepted = prefs.getBool(_kTermsAccepted) ?? false;
    // AB disi kullanicilar icin varsayilan true (GDPR onlari baglamaz);
    // AB icindeyse ve henuz secim yapilmadiysa guvenli varsayilan olarak
    // false (kisisellestirilmemis) kullanilir, kullanici onaylayana kadar.
    _adsConsent = prefs.getBool(_kConsentChoice) ?? !_isEUUser;

    _loaded = true;
    await _pushConsentToYandex();
    notifyListeners();
  }

  /// Cihazin tercih ettigi bolge/ulke kodlarina bakarak (dile degil,
  /// BOLGE koduna gore) AB/AEA/Isvicre/UK icinde olup olmadigini tahmin
  /// eder. Turkiye gibi Avrupa'da olup AB uyesi olmayan ulkeler bu listede
  /// YOKTUR, dolayisiyla GDPR onlarda tetiklenmez.
  bool _detectEU() {
    try {
      final locales = WidgetsBinding.instance.platformDispatcher.locales;
      for (final loc in locales) {
        if (_isEUCountryCode(loc.countryCode)) return true;
      }
      final primary = WidgetsBinding.instance.platformDispatcher.locale;
      if (_isEUCountryCode(primary.countryCode)) return true;
    } catch (_) {
      // Bolge tespit edilemezse guvenli tarafta kal: AB disi kabul et.
    }
    return false;
  }

  static const Set<String> _euCountryCodes = {
    // AB (Avrupa Birligi) uye ulkeleri
    'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR',
    'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK',
    'SI', 'ES', 'SE',
    // AEA (AB disi) + Isvicre + Birlesik Krallik - GDPR/UK GDPR kapsaminda
    // benzer sekilde muamele edilir.
    'IS', 'LI', 'NO', 'CH', 'GB',
  };

  bool _isEUCountryCode(String? code) {
    if (code == null || code.isEmpty) return false;
    return _euCountryCodes.contains(code.toUpperCase());
  }

  /// Ilk acilis popup'indan (veya AB disi kullanicida tek dugmeli
  /// akistan) cagrilir: sozlesmeyi onaylar ve (AB icindeyse) secilen
  /// reklam tercihini kaydeder.
  Future<void> acceptTerms({required bool personalizedAds}) async {
    _termsAccepted = true;
    _adsConsent = _isEUUser ? personalizedAds : true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTermsAccepted, true);
    await prefs.setBool(_kConsentChoice, _adsConsent);
    await _pushConsentToYandex();
  }

  /// Profil/Ayarlar ekranindan, kullanici SONRADAN fikir degistirirse
  /// (sadece AB kullanicilarina gosterilen anahtar) cagrilir.
  Future<void> updateAdsConsent(bool personalizedAds) async {
    _adsConsent = personalizedAds;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConsentChoice, personalizedAds);
    await _pushConsentToYandex();
  }

  Future<void> _pushConsentToYandex() async {
    try {
      // Yandex Mobile Ads SDK'nin resmi GDPR rıza API'si — bkz.
      // https://ads.yandex.com/helpcenter/en/dev/flutter/gdpr
      YandexAds.setUserConsent(_adsConsent);
    } catch (_) {
      // SDK henuz baslatilmadiysa (ör. web/test ortami) sessizce yut;
      // main.dart SDK init edildikten SONRA load() cagirir, bu yuzden
      // normal akiste buraya dusulmez.
    }
  }
}
