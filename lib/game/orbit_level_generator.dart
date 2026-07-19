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

  OrbitLevelConfig({
    required this.stage,
    required this.ringCount,
    required this.cellsPerRing,
    required this.colorCount,
    required this.dockCapacity,
  });

  factory OrbitLevelConfig.forStage(int stage) {
    final safeStage = stage < 1 ? 1 : stage;

    // Halka sayisi: 3'ten baslar, her 3 bolumde bir +1, 6'da tavanlanir.
    var ringCount = 3 + ((safeStage - 1) ~/ 3);
    if (ringCount > 6) ringCount = 6;

    // Renk sayisi: her 2 bolumde bir +1, 8'de tavanlanir (10'luk paletin
    // hepsini asla tek seferde kullanmiyoruz ki hedef kuyrugu okunakli
    // kalsin).
    var colorCount = 3 + ((safeStage - 1) ~/ 2);
    if (colorCount > 8) colorCount = 8;

    // Ic halkalar kucuk (az hucre), dis halkalar buyuk — gercek bir
    // gunes sistemi gibi hissettirir.
    final cellsPerRing = List<int>.generate(
      ringCount,
      (i) => 4 + i + min(safeStage ~/ 6, 3),
    );

    // Rihtim (dock) kapasitesi: ilk bolumler bol (3), zorlastikca 2'ye
    // duser — bu, Pixel Flow tarzi "tampon" gerilimini kademeli acar.
    final dockCapacity = safeStage <= 5 ? 3 : 2;

    return OrbitLevelConfig(
      stage: safeStage,
      ringCount: ringCount,
      cellsPerRing: cellsPerRing,
      colorCount: colorCount,
      dockCapacity: dockCapacity,
    );
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
    );
  }
}
