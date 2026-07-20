/// Meteor (elmas) ekonomisinin TEK kaynağı. Fiyatlar ve olasılıklar
/// burada toplanır ki dengeleme yapılacaksa tek dosyaya bakmak yetsin.
///
/// Sohbette üzerinde uzlaşılan mantık:
/// - hint/undo/flip/extraTube artık Kozmik İkmal RNG'sinden değil,
///   SADECE meteor mağazasından alınıyor (reklam yolu zaten hala açık,
///   meteor sadece "reklamı atla" kolaylığı satıyor -> ucuz tutuluyor).
/// - Orbit'te 1. rıhtım genişletme hakkı hâlâ ücretsiz (reklam), ama
///   aynı denemede 2.+ hak artık meteorla, kademeli artan fiyatla
///   satın alınıyor (sınırsız "pay-to-skip" döngüsünü engellemek için).
class EconomyConfig {
  EconomyConfig._();

  // ---- Meteor mağazası fiyatları (tüp modu + genel yardımcılar) ----
  static const int hintPrice = 2;
  static const int undoPrice = 3;
  static const int flipPrice = 4;
  static const int extraTubePrice = 5;

  // ---- Orbit rıhtım genişletme: 1. hak ücretsiz (reklam), sonrası ----
  // meteor ile ve kademeli artan fiyatla. index 0 = 2. hak fiyatı.
  static const List<int> orbitDockMeteorPrices = [6, 10, 15, 20];

  static int orbitDockPriceFor(int paidAttemptIndex) {
    if (paidAttemptIndex < orbitDockMeteorPrices.length) {
      return orbitDockMeteorPrices[paidAttemptIndex];
    }
    // Tablo biterse son fiyattan +5 katlanarak devam eder (pratikte tavan).
    final overflow = paidAttemptIndex - orbitDockMeteorPrices.length + 1;
    return orbitDockMeteorPrices.last + overflow * 5;
  }

  // ---- Kozmik İkmal ödül olasılık tablosu (toplam %100) ----
  // Meteor dilimi %50, eski ödüller (sadece XP + hint) %50.
  static const double pMeteor10 = 0.05;
  static const double pMeteor5 = 0.10;
  static const double pMeteor3 = 0.15;
  static const double pMeteor2 = 0.20;
  static const double pXp = 0.35;
  static const double pHint = 0.15;

  static const int xpRewardAmount = 100;
  static const int hintRewardAmount = 1;

  // ---- Küçük, sabit meteor gelir kanalları (tamamen RNG'ye bağlı
  // kalmaması için) ----
  static const int meteorPerLevelComplete = 1;
  static const int meteorDailyStreakBonus = 2;
  static const int meteorStarterGift = 12;
}
