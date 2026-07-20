import 'dart:math';

import 'orbit_models.dart';

/// Bolum numarasina gore Orbit Jam parametrelerini hesaplar ve rastgele
/// (ama her zaman "cozulebilir" — cunku her nesne kendi halkasinda sonsuz
/// donerek er ya da gec kapiya ulasabilir) bir dizilim uretir. Asil zorluk
/// kaynagi cozulup cozulemeyecegi degil, HAMLE/RIHTIM butcesini asmadan
/// cozebilmek.
class OrbitLevelConfig {
  final int stage;
  final int ringCount;
  final List<int> cellsPerRing;
  final int colorCount;
  final int dockCapacity;
  final bool comboEnabled;
  final bool lockedRingEnabled;

  OrbitLevelConfig({
    required this.stage,
    required this.ringCount,
    required this.cellsPerRing,
    required this.colorCount,
    required this.dockCapacity,
    required this.comboEnabled,
    required this.lockedRingEnabled,
  });

  factory OrbitLevelConfig.forStage(int stage) {
    final safeStage = stage < 1 ? 1 : stage;

    // Halka sayisi: 3'ten baslar, her 3 bolumde bir +1, 6'da tavanlanir.
    var ringCount = 3 + ((safeStage - 1) ~/ 3);
    if (ringCount > 6) ringCount = 6;

    // Renk/gezegen sayisi: tup modundaki ile ayni kademeli mantik
    // (1-9: her 5 bolumde +1, 10-14: her 4 bolumde +1, 15+: her 3
    // bolumde +1), sadece tavan 8 (orbit'te palet biraz daha genis).
    var colorCount = _colorCountForStage(safeStage);
    if (colorCount > 8) colorCount = 8;

    // Ic halkalar kucuk (az hucre), dis halkalar buyuk — gercek bir
    // gunes sistemi gibi hissettirir.
    final cellsPerRing = List<int>.generate(
      ringCount,
      (i) => 4 + i + min(safeStage ~/ 6, 3),
    );

    // Rihtim (dock) kapasitesi: ilk bolumler bol (3), 10. bolumden
    // itibaren 2'ye duser — kombo/skor sisteminin acildigi ayni esikte,
    // boylece "bolum 10 = yeni chapter" hissi tek bir noktada birikir.
    final dockCapacity = safeStage <= 9 ? 3 : 2;

    // 10. bolumden itibaren kombo/skor sistemi acik.
    final comboEnabled = safeStage >= 10;
    // 15. bolumden itibaren kilitli halka mekanigi acik.
    final lockedRingEnabled = safeStage >= 15;

    return OrbitLevelConfig(
      stage: safeStage,
      ringCount: ringCount,
      cellsPerRing: cellsPerRing,
      colorCount: colorCount,
      dockCapacity: dockCapacity,
      comboEnabled: comboEnabled,
      lockedRingEnabled: lockedRingEnabled,
    );
  }

  static int _colorCountForStage(int stage) {
    var count = 3;
    var remaining = stage - 1;

    const phase1Levels = 9, phase1Step = 5; // 1-9
    const phase2Levels = 5, phase2Step = 4; // 10-14

    final phase1 = min(remaining, phase1Levels);
    count += phase1 ~/ phase1Step;
    remaining -= phase1;
    if (remaining <= 0) return count;

    final phase2 = min(remaining, phase2Levels);
    count += phase2 ~/ phase2Step;
    remaining -= phase2;
    if (remaining <= 0) return count;

    count += remaining ~/ 3; // 15+
    return count;
  }
}

class OrbitLevelGenerator {
  static OrbitLevel generate(int stage, {Random? random}) {
    final rnd = random ?? Random();
    final cfg = OrbitLevelConfig.forStage(stage);

    // 1) Her halka icin hucreleri rastgele renklerle doldur (bos hucre
    //    birakmiyoruz ki halka "dolu" hissettirsin; bos hucre olmadan da
    //    dondurme her zaman mumkun cunku halka dairesel/kapali bir dongu).
    final rings = <OrbitRing>[];
    final allColors = <int>[];
    for (final cellCount in cfg.cellsPerRing) {
      final cells = List<int>.generate(
        cellCount,
        (_) => rnd.nextInt(cfg.colorCount),
      );
      allColors.addAll(cells);
      rings.add(OrbitRing(cellCount: cellCount, cells: List<int?>.from(cells)));
    }

    // 2) Baslangicta her halkayi rastgele bir miktar "on-donus" ile
    //    karistir (kapida hangi rengin bekledigi de rastgele olsun).
    for (final ring in rings) {
      final spins = rnd.nextInt(ring.cellCount);
      for (var i = 0; i < spins; i++) {
        ring.rotate(clockwise: rnd.nextBool());
      }
    }

    // 3) Hedef kuyrugu: tum nesnelerin rengini karistir. Toplam talep,
    //    toplam arzla birebir esit oldugu icin (ayni renk havuzundan
    //    geliyor) her zaman cozulebilir.
    final targetQueue = List<int>.from(allColors)..shuffle(rnd);

    // 3.5) Kilitli halka (15. bolumden itibaren): rastgele bir halka
    //    (ilk halka haric, boylece oyuncunun elinde her zaman en az bir
    //    acik/kucuk halka kalir) kilitlenir. targetQueue'nun ilk ucte
    //    biri teslim edilene kadar bu halka dondurulemez.
    if (cfg.lockedRingEnabled && rings.length > 1) {
      final lockIndex = 1 + rnd.nextInt(rings.length - 1);
      rings[lockIndex].locked = true;
      rings[lockIndex].unlockAt = (targetQueue.length * 0.3).ceil();
    }

    // 4) Par (referans) hamle sayisi: her nesnenin ortalama olarak kendi
    //    halkasinin yarisi kadar donmesi gerektigini varsayan kaba bir
    //    tahmin, + rihtim yonetimi icin kucuk bir tampon.
    var par = 0;
    for (final ring in rings) {
      par += (ring.cellCount * ring.cellCount / 2).ceil();
    }
    par += (targetQueue.length * 0.5).ceil();

    return OrbitLevel(
      stage: cfg.stage,
      rings: rings,
      targetQueue: targetQueue,
      dockCapacity: cfg.dockCapacity,
      parRotations: par,
      comboEnabled: cfg.comboEnabled,
    );
  }
}
