/// Bolum (level) numarasina gore zorluk parametrelerini hesaplar.
/// Amac: her bolumde biraz daha zor ama oyuncuyu yormayacak sekilde
/// kademeli bir artis saglamak.
class LevelConfig {
  final int level;
  final int colorCount;
  final int emptyTubes;
  final int capacity;
  final int shuffleMoves;

  LevelConfig({
    required this.level,
    required this.colorCount,
    required this.emptyTubes,
    required this.capacity,
    required this.shuffleMoves,
  });

  factory LevelConfig.forLevel(int level) {
    final safeLevel = level < 1 ? 1 : level;

    // HTML prototipindeki getStageParams ile birebir ayni egri:
    // renk sayisi her 2 bolumde bir +1, 7 renkte tavanlaniyor.
    var colorCount = 3 + ((safeLevel - 1) ~/ 2);
    if (colorCount > 7) colorCount = 7;

    // Ilk 4 bolum 2 bos tuple (yumusak giris), sonrasinda 1 bos tup
    // (daha az manevra alani = belirgin sekilde daha zor).
    final emptyTubes = safeLevel <= 4 ? 2 : 1;

    const capacity = 4;

    // Artik kullanilmiyor (uretim tam rastgele + A* ile dogrulaniyor),
    // geriye donuk uyumluluk icin birakildi.
    const shuffleMoves = 0;

    return LevelConfig(
      level: safeLevel,
      colorCount: colorCount,
      emptyTubes: emptyTubes,
      capacity: capacity,
      shuffleMoves: shuffleMoves,
    );
  }
}
