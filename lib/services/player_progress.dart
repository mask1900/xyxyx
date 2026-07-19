import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_progress_sync.dart';

/// Tek bir bolumun en iyi sonucu.
class StageStat {
  final int stars;
  final int bestMoves;
  final int score;
  const StageStat({
    required this.stars,
    required this.bestMoves,
    required this.score,
  });

  Map<String, dynamic> toJson() =>
      {'stars': stars, 'bestMoves': bestMoves, 'score': score};

  factory StageStat.fromJson(Map<String, dynamic> j) => StageStat(
        stars: j['stars'] ?? 0,
        bestMoves: j['bestMoves'] ?? 0,
        score: j['score'] ?? 0,
      );
}

/// Gunluk gorevin son sonucu (paylasim ekrani + 2x XP butonu icin).
class DailyResult {
  final int dailyNum;
  final int moves;
  final int optimal;
  final int stars;
  final int timeSeconds;
  final int xp;
  bool doubled;
  DailyResult({
    required this.dailyNum,
    required this.moves,
    required this.optimal,
    required this.stars,
    required this.timeSeconds,
    required this.xp,
    this.doubled = false,
  });

  Map<String, dynamic> toJson() => {
        'dailyNum': dailyNum,
        'moves': moves,
        'optimal': optimal,
        'stars': stars,
        'timeSeconds': timeSeconds,
        'xp': xp,
        'doubled': doubled,
      };

  factory DailyResult.fromJson(Map<String, dynamic> j) => DailyResult(
        dailyNum: j['dailyNum'] ?? 1,
        moves: j['moves'] ?? 0,
        optimal: j['optimal'] ?? 1,
        stars: j['stars'] ?? 1,
        timeSeconds: j['timeSeconds'] ?? 0,
        xp: j['xp'] ?? 0,
        doubled: j['doubled'] ?? false,
      );
}

class LevelInfo {
  final int level;
  final int xpIntoLevel;
  final int xpForNext;
  final double progress;
  const LevelInfo(this.level, this.xpIntoLevel, this.xpForNext, this.progress);
}

/// "Kozmik Ikmal" odul turleri (resupply reklam odulleri).
enum ResupplyRewardKind { xp, hint, undo, extraTube, flip, orbitDockSlot }

class ResupplyReward {
  final ResupplyRewardKind kind;
  final int amount;
  const ResupplyReward(this.kind, this.amount);
}

/// Oyuncunun tum kalici ilerlemesini tutan ve SharedPreferences'a
/// kaydeden/yukleyen ChangeNotifier. HTML prototipindeki `playerData` +
/// ilgili tum fonksiyonlarin (saveLocal/loadLocal, resupply, daily,
/// level/xp sistemi) Dart karsiligi.
class PlayerProgress extends ChangeNotifier {
  static final PlayerProgress instance = PlayerProgress._();
  PlayerProgress._();

  static const _prefsKey = 'cs_data_v1';

  int xp = 0;
  int totalStars = 0;
  int totalScore = 0;
  int unlockedStage = 1;
  final Map<int, StageStat> stageStats = {};

  // Orbit Jam (yorunge sikismasi) modunun kendi bolum ilerlemesi — tup
  // modundan bagimsiz, ayni sekilde kilit/yildiz takibi yapar.
  int orbitUnlockedStage = 1;
  final Map<int, StageStat> orbitStageStats = {};

  int dailyStreak = 0;
  String dailyLastCompletedDate = '';
  DailyResult? dailyLastResult;

  /// "Gunes Sistemi Koleksiyonu": bir bolumde basariyla kullanilan (yani
  /// bir tup tek renge tamamlanmis olarak cozulen) gezegen renk index'leri
  /// (0..9), ilk kesfedildiginde buraya eklenir ve kalici olarak saklanir.
  final Set<int> discoveredPlanets = <int>{};

  // Kozmik Ikmal bankasi: reklamla kazanilan, sonra reklamsiz
  // harcanabilen haklar.
  int bankedHints = 0;
  int bankedUndos = 0;
  int bankedExtraTubes = 0;
  int bankedFlips = 0;
  // Yorunge Vardiyasi icin: reklamsiz kullanilabilen, bir sonraki
  // sikismada rihtima +1 yuva eklemek uzere biriktirilen hak.
  int bankedOrbitDockSlots = 0;
  int lastResupplyTime = 0;
  int resupplyAdsWatched = 0;

  int dailyResetsUsed = 0;
  String dailyResetsDate = '';

  static const int resupplyCooldownMs = 2 * 60 * 60 * 1000;
  static const int resupplyAdsRequired = 3;
  static const int dailyResetsFree = 3;
  static const int _levelBaseXp = 100;
  static const double _levelGrowth = 1.2;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        _applyJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Bozuk kayit: varsayilanlarla devam et.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_toJson()));
    // Play Games'e baglaniysa ilerlemeyi buluta da yazar (sessizce;
    // baglanti yoksa hicbir sey yapmaz).
    unawaited(CloudProgressSync.instance.pushAfterLocalSave());
  }

  /// Bulut senkronizasyonu (Play Games Saved Games) icin: tum ilerlemeyi
  /// tek bir JSON metni olarak disari verir.
  String exportJson() => jsonEncode(_toJson());

  /// Bulut senkronizasyonu icin: verilen JSON'u uygulayip yerel olarak
  /// da kaydeder (SharedPreferences).
  Future<void> restoreFromJson(Map<String, dynamic> json) async {
    _applyJson(json);
    notifyListeners();
    await save();
  }

  Map<String, dynamic> _toJson() => {
        'xp': xp,
        'totalStars': totalStars,
        'totalScore': totalScore,
        'unlockedStage': unlockedStage,
        'stageStats':
            stageStats.map((k, v) => MapEntry(k.toString(), v.toJson())),
        'orbitUnlockedStage': orbitUnlockedStage,
        'orbitStageStats':
            orbitStageStats.map((k, v) => MapEntry(k.toString(), v.toJson())),
        'dailyStreak': dailyStreak,
        'dailyLastCompletedDate': dailyLastCompletedDate,
        'dailyLastResult': dailyLastResult?.toJson(),
        'discoveredPlanets': discoveredPlanets.toList(),
        'bankedHints': bankedHints,
        'bankedUndos': bankedUndos,
        'bankedExtraTubes': bankedExtraTubes,
        'bankedFlips': bankedFlips,
        'bankedOrbitDockSlots': bankedOrbitDockSlots,
        'lastResupplyTime': lastResupplyTime,
        'resupplyAdsWatched': resupplyAdsWatched,
        'dailyResetsUsed': dailyResetsUsed,
        'dailyResetsDate': dailyResetsDate,
      };

  void _applyJson(Map<String, dynamic> j) {
    xp = j['xp'] ?? 0;
    totalStars = j['totalStars'] ?? 0;
    totalScore = j['totalScore'] ?? 0;
    unlockedStage = j['unlockedStage'] ?? 1;
    stageStats.clear();
    final stats = (j['stageStats'] as Map?) ?? {};
    stats.forEach((k, v) {
      stageStats[int.parse(k)] =
          StageStat.fromJson(Map<String, dynamic>.from(v));
    });
    orbitUnlockedStage = j['orbitUnlockedStage'] ?? 1;
    orbitStageStats.clear();
    final orbitStats = (j['orbitStageStats'] as Map?) ?? {};
    orbitStats.forEach((k, v) {
      orbitStageStats[int.parse(k)] =
          StageStat.fromJson(Map<String, dynamic>.from(v));
    });
    dailyStreak = j['dailyStreak'] ?? 0;
    dailyLastCompletedDate = j['dailyLastCompletedDate'] ?? '';
    dailyLastResult = j['dailyLastResult'] != null
        ? DailyResult.fromJson(Map<String, dynamic>.from(j['dailyLastResult']))
        : null;
    discoveredPlanets
      ..clear()
      ..addAll(
        ((j['discoveredPlanets'] as List?) ?? const [])
            .map((e) => e as int),
      );
    bankedHints = j['bankedHints'] ?? 0;
    bankedUndos = j['bankedUndos'] ?? 0;
    bankedExtraTubes = j['bankedExtraTubes'] ?? 0;
    bankedFlips = j['bankedFlips'] ?? 0;
    bankedOrbitDockSlots = j['bankedOrbitDockSlots'] ?? 0;
    lastResupplyTime = j['lastResupplyTime'] ?? 0;
    resupplyAdsWatched = j['resupplyAdsWatched'] ?? 0;
    dailyResetsUsed = j['dailyResetsUsed'] ?? 0;
    dailyResetsDate = j['dailyResetsDate'] ?? '';
  }

  // ---------------------------------------------------------------------
  // XP / seviye sistemi (bolum ilerlemesinden bagimsiz, meta ilerleme)
  // ---------------------------------------------------------------------
  LevelInfo levelInfo() {
    var level = 1;
    var xpFloor = 0;
    var xpForNext = _levelBaseXp;
    while (xp >= xpFloor + xpForNext) {
      xpFloor += xpForNext;
      level++;
      xpForNext = (xpForNext * _levelGrowth).round();
    }
    final xpIntoLevel = xp - xpFloor;
    final progress = (xpIntoLevel / xpForNext).clamp(0.0, 1.0).toDouble();
    return LevelInfo(level, xpIntoLevel, xpForNext, progress);
  }

  Future<void> addXp(int amount) async {
    xp += amount;
    notifyListeners();
    await save();
  }

  // ---------------------------------------------------------------------
  // Tarih yardimcilari
  // ---------------------------------------------------------------------
  static String todayStr([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static String yesterdayStr([DateTime? now]) {
    final d = (now ?? DateTime.now()).subtract(const Duration(days: 1));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static final DateTime dailyEpoch = DateTime(2026, 7, 13);

  static int dailyNumber([DateTime? now]) {
    final d = now ?? DateTime.now();
    final today0 = DateTime(d.year, d.month, d.day);
    final diff = today0.difference(dailyEpoch).inDays;
    return max(1, diff + 1);
  }

  /// Gunluk gorevin seed'i: ayni gun herkese ayni sayi, boylece herkes ayni
  /// bulmacayi cozer.
  static int dailySeed([DateTime? now]) {
    final d = now ?? DateTime.now();
    return d.year * 10000 + d.month * 100 + d.day;
  }

  // ---------------------------------------------------------------------
  // Bolum sonucu kaydi
  // ---------------------------------------------------------------------
  /// Bir bolum kazanildiginda cagrilir; XP/yildiz/skor gunceller, bir
  // sonraki bolumun kilidini acar. Kazanilan XP'yi ve seviye atlanip
  /// atlanmadigini dondurur (kazanma ekraninda gostermek icin).
  Future<(int, bool)> recordStageResult({
    required int stage,
    required int stars,
    required int moves,
    required int optimalMoves,
  }) async {
    final score = max(50, 500 - (moves - optimalMoves) * 10);
    final prev = stageStats[stage];
    final isNew = prev == null;
    final starDelta = isNew ? stars : max(0, stars - prev.stars);
    final scoreDelta = isNew ? score : max(0, score - prev.score);

    stageStats[stage] = StageStat(
      stars: max(stars, prev?.stars ?? 0),
      bestMoves: prev == null ? moves : min(moves, prev.bestMoves),
      score: max(score, prev?.score ?? 0),
    );
    totalStars += starDelta;
    totalScore += scoreDelta;
    if (stage + 1 > unlockedStage) unlockedStage = stage + 1;

    final levelBefore = levelInfo().level;
    final gainedXp = 15 + stars * 10;
    xp += gainedXp;
    final levelAfter = levelInfo().level;

    notifyListeners();
    await save();
    return (gainedXp, levelAfter > levelBefore);
  }

  /// [recordStageResult]'in Orbit Jam karsiligi: ayni mantik, ama kendi
  /// bagimsiz bolum/yildiz kayitlarina (orbitUnlockedStage/orbitStageStats)
  /// yazar. [moves] burada "donus sayisi" (rotations) anlamina gelir.
  Future<(int, bool)> recordOrbitStageResult({
    required int stage,
    required int stars,
    required int moves,
    required int optimalMoves,
  }) async {
    final score = max(50, 500 - (moves - optimalMoves) * 10);
    final prev = orbitStageStats[stage];
    final isNew = prev == null;
    final starDelta = isNew ? stars : max(0, stars - prev.stars);
    final scoreDelta = isNew ? score : max(0, score - prev.score);

    orbitStageStats[stage] = StageStat(
      stars: max(stars, prev?.stars ?? 0),
      bestMoves: prev == null ? moves : min(moves, prev.bestMoves),
      score: max(score, prev?.score ?? 0),
    );
    totalStars += starDelta;
    totalScore += scoreDelta;
    if (stage + 1 > orbitUnlockedStage) orbitUnlockedStage = stage + 1;

    final levelBefore = levelInfo().level;
    final gainedXp = 15 + stars * 10;
    xp += gainedXp;
    final levelAfter = levelInfo().level;

    notifyListeners();
    await save();
    return (gainedXp, levelAfter > levelBefore);
  }

  Future<void> recordDailyResult({
    required int moves,
    required int optimal,
    required int timeSeconds,
  }) async {
    final today = todayStr();
    if (dailyLastCompletedDate == yesterdayStr()) {
      dailyStreak += 1;
    } else if (dailyLastCompletedDate != today) {
      dailyStreak = 1;
    }
    dailyLastCompletedDate = today;
    final stars =
        moves <= optimal ? 3 : (moves <= (optimal * 1.5).ceil() ? 2 : 1);
    final gainedXp = 30 + stars * 10;
    xp += gainedXp;
    dailyLastResult = DailyResult(
      dailyNum: dailyNumber(),
      moves: moves,
      optimal: optimal,
      stars: stars,
      timeSeconds: timeSeconds,
      xp: gainedXp,
    );
    notifyListeners();
    await save();
  }

  // ---------------------------------------------------------------------
  // Gunes Sistemi Koleksiyonu: bir bolum kazanildiginda, o bolumde
  // kullanilan gezegen renklerinden (0..colorCount-1) daha once hic
  // kesfedilmemis olanlari kalici listeye ekler. Yeni kesfedilenlerin
  // index listesini dondurur (UI, bunun uzerine bir "yeni gezegen
  // kesfedildi" animasyonu/diyalogu gosterebilir; bos liste -> yeni yok).
  Future<List<int>> markPlanetsDiscovered(int colorCount) async {
    final fresh = <int>[];
    for (var i = 0; i < colorCount && i < 10; i++) {
      if (discoveredPlanets.add(i)) fresh.add(i);
    }
    if (fresh.isNotEmpty) {
      notifyListeners();
      await save();
    }
    return fresh;
  }

  Future<void> claimDailyDouble() async {
    final r = dailyLastResult;
    if (r == null || r.doubled) return;
    xp += r.xp;
    r.doubled = true;
    notifyListeners();
    await save();
  }

  bool get dailyCompletedToday => dailyLastCompletedDate == todayStr();

  // ---------------------------------------------------------------------
  // Kozmik Ikmal (resupply): 2 saatte bir acilan, art arda 3 reklam
  // izlenebilen odul bankasi.
  // ---------------------------------------------------------------------
  bool get isResupplyReady =>
      lastResupplyTime == 0 ||
      (DateTime.now().millisecondsSinceEpoch - lastResupplyTime) >=
          resupplyCooldownMs;

  String resupplyCountdownText() {
    final remainMs = resupplyCooldownMs -
        (DateTime.now().millisecondsSinceEpoch - lastResupplyTime);
    final remainMin = max(0, (remainMs / 60000).ceil());
    final h = remainMin ~/ 60;
    final m = remainMin % 60;
    return h > 0 ? '${h}s ${m}dk' : '${m}dk';
  }

  /// Bir Kozmik Ikmal reklami izlendikten sonra cagrilir: rastgele bir
  /// odul verir — %30 XP, %20 Yorunge rihtim yuvasi (yeni ana mod icin),
  /// %15 tup ipucu, %15 tup geri al, %10 tup ekstra tank, %10 tup sifir
  /// yercekimi ters cevirme — ve 3. reklamdan sonra 2 saatlik bekleme
  /// baslatir.
  Future<ResupplyReward> grantResupplyReward(Random rng) async {
    final roll = rng.nextDouble() * 100;
    ResupplyReward reward;
    if (roll < 30) {
      xp += 100;
      reward = const ResupplyReward(ResupplyRewardKind.xp, 100);
    } else if (roll < 50) {
      bankedOrbitDockSlots += 1;
      reward = const ResupplyReward(ResupplyRewardKind.orbitDockSlot, 1);
    } else if (roll < 65) {
      bankedHints += 1;
      reward = const ResupplyReward(ResupplyRewardKind.hint, 1);
    } else if (roll < 80) {
      bankedUndos += 1;
      reward = const ResupplyReward(ResupplyRewardKind.undo, 1);
    } else if (roll < 90) {
      bankedExtraTubes += 1;
      reward = const ResupplyReward(ResupplyRewardKind.extraTube, 1);
    } else {
      bankedFlips += 1;
      reward = const ResupplyReward(ResupplyRewardKind.flip, 1);
    }
    resupplyAdsWatched += 1;
    if (resupplyAdsWatched >= resupplyAdsRequired) {
      resupplyAdsWatched = 0;
      lastResupplyTime = DateTime.now().millisecondsSinceEpoch;
    }
    notifyListeners();
    await save();
    return reward;
  }

  // ---------------------------------------------------------------------
  // Gunluk ucretsiz "yeniden baslat" haklari (hesap bazinda, bolum
  // bazinda degil).
  // ---------------------------------------------------------------------
  int getResetsLeftToday() {
    if (dailyResetsDate != todayStr()) {
      dailyResetsDate = todayStr();
      dailyResetsUsed = 0;
    }
    return max(0, dailyResetsFree - dailyResetsUsed);
  }

  Future<void> useFreeReset() async {
    dailyResetsUsed += 1;
    notifyListeners();
    await save();
  }

  Future<void> spendBankedHint() async {
    bankedHints = max(0, bankedHints - 1);
    notifyListeners();
    await save();
  }

  Future<void> spendBankedUndo() async {
    bankedUndos = max(0, bankedUndos - 1);
    notifyListeners();
    await save();
  }

  Future<void> spendBankedExtraTube() async {
    bankedExtraTubes = max(0, bankedExtraTubes - 1);
    notifyListeners();
    await save();
  }

  Future<void> spendBankedFlip() async {
    bankedFlips = max(0, bankedFlips - 1);
    notifyListeners();
    await save();
  }

  Future<void> spendBankedOrbitDockSlot() async {
    bankedOrbitDockSlots = max(0, bankedOrbitDockSlots - 1);
    notifyListeners();
    await save();
  }
}
