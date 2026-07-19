import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { tr, en, ru }

/// Uygulama genelinde TR / EN / RU metinlerini yoneten, tercihi
/// SharedPreferences'a kaydeden basit bir ChangeNotifier singleton.
/// HTML prototipindeki t(key) fonksiyonunun Dart karsiligi.
class AppLocale extends ChangeNotifier {
  static final AppLocale instance = AppLocale._();
  AppLocale._();

  static const _prefsKey = 'cs_lang_v1';
  static const _chosenPrefsKey = 'cs_lang_chosen_v1';

  AppLanguage _lang = AppLanguage.tr;
  AppLanguage get language => _lang;

  bool _hasChosen = false;
  bool get hasChosenLanguage => _hasChosen;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    _hasChosen = prefs.getBool(_chosenPrefsKey) ?? false;
    _lang = switch (code) {
      'en' => AppLanguage.en,
      'ru' => AppLanguage.ru,
      _ => AppLanguage.tr,
    };
    notifyListeners();
  }

  /// İlk açılıştaki dil seçim ekranından çağrılır: dili ayarlar VE bir
  /// daha o ekranın gösterilmemesi için "seçildi" bayrağını kaydeder.
  Future<void> setInitialLanguage(AppLanguage lang) async {
    _lang = lang;
    _hasChosen = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final code = switch (lang) {
      AppLanguage.tr => 'tr',
      AppLanguage.en => 'en',
      AppLanguage.ru => 'ru',
    };
    await prefs.setString(_prefsKey, code);
    await prefs.setBool(_chosenPrefsKey, true);
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_lang == lang) return;
    _lang = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final code = switch (lang) {
      AppLanguage.tr => 'tr',
      AppLanguage.en => 'en',
      AppLanguage.ru => 'ru',
    };
    await prefs.setString(_prefsKey, code);
  }

  int get _i => switch (_lang) {
        AppLanguage.tr => 0,
        AppLanguage.en => 1,
        AppLanguage.ru => 2,
      };

  /// Bir anahtari mevcut dile cevirir. {ad} gibi yer tutuculari [args]
  /// ile degistirir (orn. t('win_missionCompleted', {'n': '7'})).
  String t(String key, [Map<String, String>? args]) {
    final list = _strings[key];
    var s = (list != null && _i < list.length) ? list[_i] : key;
    if (args != null) {
      args.forEach((k, v) {
        s = s.replaceAll('{$k}', v);
      });
    }
    return s;
  }

  static final Map<String, List<String>> _strings = {
    // ---- Genel / marka ----
    'appName': ['Space Sort', 'Space Sort', 'Space Sort'],
    'langSelect_title': [
      'Bir dil seç',
      'Choose a language',
      'Выберите язык',
    ],
    'langSelect_subtitle': [
      'Bu, oyun içindeki tüm metinlerin dilini belirler. Daha sonra '
          'profil ekranından değiştirebilirsin.',
      'This sets the language for all text in the game. You can change '
          'it later from the profile screen.',
      'Это определяет язык всех текстов в игре. Позже вы сможете '
          'изменить его в профиле.',
    ],
    'langSelect_continue': ['Devam Et', 'Continue', 'Продолжить'],
    'splashTagline': [
      'Galaksiler Arası Renk Sıralama',
      'Intergalactic Color Sorting',
      'Межгалактическая сортировка цвета',
    ],

    // ---- Ana ekran ----
    'home_resupplyTitle': [
      'Kozmik İkmal',
      'Cosmic Resupply',
      'Космическое пополнение',
    ],
    'home_resupplySubtitle': [
      '100 XP · Sinyal · Geri Al · Ekstra Tank · Sıfır Yerçekimi',
      '100 XP · Signal · Undo · Extra Tank · Zero-G Flip',
      '100 XP · Сигнал · Отмена · Доп. бак · Невесомость',
    ],
    'home_resupplyReady': ['✅ Hazır!', '✅ Ready!', '✅ Готово!'],
    'home_dailyTitle': ['Günlük Sinyal', 'Daily Signal', 'Ежедневный сигнал'],
    'home_dailyDoneTitle': [
      'Bugün Tamamlandı',
      'Completed Today',
      'Сегодня выполнено',
    ],
    'home_dailySubtitle': [
      'Herkese aynı sinyal, sadece bugün.',
      'Same signal for everyone, today only.',
      'Один сигнал для всех, только сегодня.',
    ],
    'home_dailyDoneSubtitle': [
      'Yarın tekrar gel.',
      'Come back tomorrow.',
      'Приходи завтра.',
    ],
    'home_chooseStage': ['Görev Seç', 'Choose Mission', 'Выбор задания'],
    'home_stageHint': [
      'Sırayla ilerle, her görev bir öncekinden biraz daha zor.',
      'Progress in order — each mission is a bit harder than the last.',
      'Проходи по порядку — каждое задание немного сложнее предыдущего.',
    ],
    'home_lockedStage': [
      '🔒 Bu görev henüz kilitli.',
      '🔒 This mission is still locked.',
      '🔒 Это задание пока заблокировано.',
    ],

    // ---- Profil ----
    'profile_totalStars': ['Toplam Yıldız', 'Total Stars', 'Всего звёзд'],
    'profile_stagesCleared': ['Tamamlanan', 'Cleared', 'Пройдено'],
    'profile_totalScore': ['Toplam Skor', 'Total Score', 'Общий счёт'],
    'profile_about': ['Hakkında', 'About', 'О игре'],
    'profile_aboutText': [
      'Space Sort, uzay temalı özgün bir bulmaca oyunudur; tüm görseller '
          'kod içinde çizilir, harici içerik veya üçüncü taraf marka '
          'kullanmaz.',
      'Space Sort is an original space-themed puzzle game; every visual '
          'is drawn in code, with no external content or third-party '
          'branding.',
      'Space Sort — оригинальная космическая головоломка; вся графика '
          'рисуется в коде, без внешнего контента и сторонних брендов.',
    ],
    'profile_language': ['Dil', 'Language', 'Язык'],
    'profile_playGames': ['Play Games', 'Play Games', 'Play Games'],
    'profile_playGamesConnect': [
      '🎮 Play Games\'e Bağlan',
      '🎮 Connect to Play Games',
      '🎮 Подключиться к Play Games',
    ],
    'profile_playGamesConnected': [
      '✅ Play Games\'e bağlı',
      '✅ Connected to Play Games',
      '✅ Подключено к Play Games',
    ],
    'profile_playGamesFailed': [
      'Bağlanılamadı. Google hesabınla giriş yaptığından emin ol.',
      'Couldn\'t connect. Make sure you\'re signed in with a Google account.',
      'Не удалось подключиться. Убедитесь, что вы вошли в аккаунт Google.',
    ],
    'profile_close': ['Kapat', 'Close', 'Закрыть'],
    'profile_level': ['Seviye', 'Level', 'Уровень'],

    // ---- Oyun ekrani / HUD ----
    'game_mission': ['GÖREV', 'MISSION', 'ЗАДАНИЕ'],
    'game_moves': ['HAMLE', 'MOVES', 'ХОДЫ'],
    'game_time': ['SÜRE', 'TIME', 'ВРЕМЯ'],
    'game_undo': ['Geri Al', 'Undo', 'Отмена'],
    'game_signal': ['Sinyal', 'Signal', 'Сигнал'],
    'game_extraTank': ['Ekstra Tank', 'Extra Tank', 'Доп. бак'],
    'game_noMoveFound': [
      'Şu an geçerli bir hamle bulunamadı.',
      'No valid move is available right now.',
      'Сейчас нет доступного хода.',
    ],
    'game_noMoreExtraTubes': [
      'Bu görevde daha fazla ekstra tank yok.',
      'No more extra tanks for this mission.',
      'Больше нет доп. баков для этого задания.',
    ],
    'game_undoDesc': [
      'Son hamleni geri alır.',
      'Undoes your last move.',
      'Отменяет последний ход.',
    ],
    'game_signalDesc': [
      'Oynanabilir bir sonraki hamleyi gösterir.',
      'Shows a playable next move.',
      'Показывает доступный следующий ход.',
    ],
    'game_extraTankDesc': [
      'Oyun alanına boş bir tank ekler.',
      'Adds an empty tank to the play area.',
      'Добавляет пустой бак на игровое поле.',
    ],
    'game_flip': ['Ters Çevir', 'Zero-G Flip', 'Невесомость'],
    'game_flipDesc': [
      'Seçtiğin tankın içindeki sırayı ters çevirir — sıkıştığın anlarda '
          'yeni bir hamle açabilir.',
      'Reverses the stacking order inside the tank you pick — can open up '
          'a new move when you\'re stuck.',
      'Переворачивает порядок содержимого выбранного бака — может открыть '
          'новый ход, когда ты застрял.',
    ],
    'game_flipPickTube': [
      '🌀 Ters çevirmek için bir tank seç',
      '🌀 Pick a tank to flip',
      '🌀 Выбери бак для переворота',
    ],
    'game_noMoreFlips': [
      'Bu görevde daha fazla ters çevirme yok.',
      'No more flips for this mission.',
      'Больше нет переворотов для этого задания.',
    ],
    'game_blackHole': ['Kara Delik', 'Black Hole', 'Чёрная дыра'],
    'game_blackHoleDesc': [
      'Herhangi bir tanktaki en üstteki taşı çeker ve renk kuralı '
          'aramadan başka HERHANGİ bir tanka bırakmana izin verir. '
          'Bölüm 11\'den itibaren açılır, görev başına 1 kez kullanılır.',
      'Pulls the top piece from any tank and lets you drop it into ANY '
          'other tank, ignoring the usual color rule. Unlocks from '
          'mission 11 onward, usable once per mission.',
      'Вытягивает верхний камень из любого бака и позволяет положить его '
          'в ЛЮБОЙ другой бак, не соблюдая правило цвета. Открывается с '
          '11-го задания, используется один раз за задание.',
    ],
    'game_blackHolePickSource': [
      '🕳️ Çekmek için bir tank seç',
      '🕳️ Pick a tank to pull from',
      '🕳️ Выбери бак, из которого тянуть',
    ],
    'game_blackHolePickTarget': [
      '🕳️ Taşı bırakmak için bir tank seç (iptal için aynı tanka dokun)',
      '🕳️ Pick a tank to drop the piece (tap the same tank to cancel)',
      '🕳️ Выбери бак, куда положить камень (тот же бак — отмена)',
    ],
    'game_noMoreBlackHole': [
      'Bu görevde kara delik hakkın kalmadı.',
      'No more black hole uses for this mission.',
      'Больше нет попыток чёрной дыры для этого задания.',
    ],
    'game_restartTitle': ['Yeniden Başlat', 'Restart', 'Заново'],
    'game_restartDesc': [
      'Görevi baştan başlatır (aynı bulmaca).',
      'Restarts the mission from scratch (same puzzle).',
      'Перезапускает задание с начала (та же головоломка).',
    ],
    'game_bankLabel': ['🎁 Bankada', '🎁 Banked', '🎁 В банке'],
    'game_maxPerMission': [
      '🔒 Görev başına en fazla',
      '🔒 Max per mission',
      '🔒 Макс. за задание',
    ],
    'game_resetsLeftToday': [
      '🔁 Bugün kalan ücretsiz hak',
      '🔁 Free resets left today',
      '🔁 Бесплатных попыток сегодня',
    ],
    'game_resetsExhausted': [
      'Bugünkü ücretsiz haklar bitti; reklamla yeniden başlatabilirsin.',
      'Today\'s free resets are used up; watch an ad to restart anyway.',
      'Бесплатные попытки на сегодня закончились; посмотри рекламу, '
          'чтобы перезапустить.',
    ],

    // ---- Kazanma diyalogu ----
    'win_missionCompleted': [
      'Görev {n} Tamamlandı!',
      'Mission {n} Complete!',
      'Задание {n} завершено!',
    ],
    'win_levelUp': [
      '🎉 Seviye atladın! Seviye {n}',
      '🎉 Level up! Level {n}',
      '🎉 Новый уровень! Уровень {n}',
    ],
    'win_moves': ['Hamle', 'Moves', 'Ходы'],
    'win_time': ['Süre', 'Time', 'Время'],
    'win_score': ['Skor', 'Score', 'Счёт'],
    'win_nextMission': ['Sonraki Görev', 'Next Mission', 'Следующее задание'],
    'win_backToMissions': [
      'Görev Seçimine Dön',
      'Back to Missions',
      'К выбору заданий',
    ],

    // ---- Gunluk sonuc diyalogu ----
    'daily_signalNum': [
      'Günlük Sinyal #{n}',
      'Daily Signal #{n}',
      'Ежедневный сигнал #{n}',
    ],
    'daily_streak': ['Seri', 'Streak', 'Серия'],
    'daily_moves': ['Hamle', 'Moves', 'Ходы'],
    'daily_time': ['Süre', 'Time', 'Время'],
    'daily_share': ['Paylaş', 'Share', 'Поделиться'],
    'daily_copied': [
      '📋 Panoya kopyalandı',
      '📋 Copied to clipboard',
      '📋 Скопировано в буфер',
    ],
    'daily_doubleXp': [
      '🎬 Reklamla 2x XP Al (+{n} XP)',
      '🎬 Watch Ad for 2x XP (+{n} XP)',
      '🎬 Смотреть рекламу за 2x XP (+{n} XP)',
    ],
    'daily_nextCountdown': [
      'Sonraki Günlük Sinyal: {h}s {m}dk',
      'Next Daily Signal: {h}h {m}m',
      'Следующий сигнал через: {h}ч {m}м',
    ],
    'daily_close': ['Kapat', 'Close', 'Закрыть'],
    'daily_streakLine': [
      '{n} gün seri',
      '{n} day streak',
      'серия {n} дн.',
    ],

    // ---- Reklam onay diyalogu ----
    'ad_watch': ['Reklam İzle', 'Watch Ad', 'Смотреть рекламу'],
    'ad_cancel': ['İptal', 'Cancel', 'Отмена'],
    'ad_defaultSubtitle': [
      'Ödülü almak için kısa bir reklam izle.',
      'Watch a short ad to get the reward.',
      'Посмотри короткую рекламу, чтобы получить награду.',
    ],
    'ad_loading': [
      'Reklam yükleniyor...',
      'Loading ad...',
      'Загрузка рекламы...',
    ],

    // ---- Kozmik Ikmal odul popup'i ----
    'resupply_rewardTitle': [
      '🎁 Ödül Kazandın!',
      '🎁 You Got a Reward!',
      '🎁 Ты получил награду!',
    ],
    'resupply_rewardXp': ['+{n} XP', '+{n} XP', '+{n} XP'],
    'resupply_rewardHint': [
      '+{n} 🛰️ Sinyal',
      '+{n} 🛰️ Signal',
      '+{n} 🛰️ Сигнал',
    ],
    'resupply_rewardUndo': [
      '+{n} ↩️ Geri Al',
      '+{n} ↩️ Undo',
      '+{n} ↩️ Отмена',
    ],
    'resupply_rewardExtraTube': [
      '+{n} 🧯 Ekstra Tank',
      '+{n} 🧯 Extra Tank',
      '+{n} 🧯 Доп. бак',
    ],
    'resupply_rewardFlip': [
      '+{n} 🌀 Sıfır Yerçekimi',
      '+{n} 🌀 Zero-G Flip',
      '+{n} 🌀 Невесомость',
    ],
    'resupply_rewardOrbitDockSlot': [
      '+{n} ⚓ Rıhtım Yuvası',
      '+{n} ⚓ Dock Slot',
      '+{n} ⚓ Место в доке',
    ],
    'resupply_close': ['Harika!', 'Awesome!', 'Отлично!'],
    'resupply_waitingBody': [
      'Sonraki ikmale kalan süre:',
      'Time left until next resupply:',
      'Время до следующего пополнения:',
    ],

    // ---- Gunes Sistemi Koleksiyonu (ana ekran karti + kodeks) ----
    'codex_cardTitle': [
      'Güneş Sistemim',
      'My Solar System',
      'Моя солнечная система',
    ],
    'codex_cardSubtitle': [
      '{n}/10 gezegen keşfedildi',
      '{n}/10 planets discovered',
      'Открыто планет: {n}/10',
    ],
    'codex_sheetTitle': [
      'Gezegen Koleksiyonu',
      'Planet Codex',
      'Каталог планет',
    ],
    'codex_locked': ['Kilitli', 'Locked', 'Заблокировано'],
    'codex_lockedHint': [
      'Bu gezegeni keşfetmek için bir görevi tamamla.',
      'Complete a mission to discover this planet.',
      'Пройди задание, чтобы открыть эту планету.',
    ],
    'codex_close': ['Kapat', 'Close', 'Закрыть'],
    'discovery_title': [
      '✨ Yeni Gezegen Keşfedildi!',
      '✨ New Planet Discovered!',
      '✨ Открыта новая планета!',
    ],
    'discovery_addedToSystem': [
      'Güneş sistemine eklendi.',
      'Added to your solar system.',
      'Добавлена в вашу солнечную систему.',
    ],
    'discovery_continue': ['Devam Et', 'Continue', 'Продолжить'],

    'planet_0_name': ['Güneş', 'Sun', 'Солнце'],
    'planet_0_fact': [
      'Sistemin kalbi; tüm enerji ondan yayılır.',
      'The heart of the system; all energy radiates from it.',
      'Сердце системы; вся энергия исходит от неё.',
    ],
    'planet_1_name': ['Dünya', 'Earth', 'Земля'],
    'planet_1_fact': [
      'Bilinen tek yaşayan gezegen.',
      'The only known living planet.',
      'Единственная известная обитаемая планета.',
    ],
    'planet_2_name': ['Gaia', 'Gaia', 'Гея'],
    'planet_2_fact': [
      'Efsanevi bir ikiz dünya, kâşiflerin hayali.',
      'A legendary twin world, every explorer\'s dream.',
      'Легендарный мир-близнец, мечта исследователей.',
    ],
    'planet_3_name': ['Satürn', 'Saturn', 'Сатурн'],
    'planet_3_fact': [
      'Muhteşem halkalarıyla tanınan dev gezegen.',
      'A giant known for its magnificent rings.',
      'Гигант, известный своими великолепными кольцами.',
    ],
    'planet_4_name': ['Viyole', 'Violet', 'Виолет'],
    'planet_4_fact': [
      'Mor atmosferiyle bilinen gizemli bir dünya.',
      'A mysterious world known for its violet atmosphere.',
      'Загадочный мир с фиолетовой атмосферой.',
    ],
    'planet_5_name': ['Mars', 'Mars', 'Марс'],
    'planet_5_fact': [
      'Kızıl gezegen, insanlığın bir sonraki durağı.',
      'The red planet, humanity\'s next stop.',
      'Красная планета, следующая остановка человечества.',
    ],
    'planet_6_name': ['Uranüs', 'Uranus', 'Уран'],
    'planet_6_fact': [
      'Yan yatmış ekseniyle bilinen bir buz devi.',
      'An ice giant known for its tilted axis.',
      'Ледяной гигант с наклонённой осью.',
    ],
    'planet_7_name': ['Pembe Nebula', 'Pink Nebula', 'Розовая туманность'],
    'planet_7_fact': [
      'Doğan yıldızların beşiği.',
      'A cradle of newborn stars.',
      'Колыбель новорождённых звёзд.',
    ],
    'planet_8_name': ['Merkür', 'Mercury', 'Меркурий'],
    'planet_8_fact': [
      'Güneşe en yakın ve en hızlı yörüngeli gezegen.',
      'The closest planet to the sun, with the fastest orbit.',
      'Ближайшая к Солнцу планета с самой быстрой орбитой.',
    ],
    'planet_9_name': ['Neptün', 'Neptune', 'Нептун'],
    'planet_9_fact': [
      'Sistemin en rüzgarlı ve en uzak devi.',
      'The system\'s windiest and most distant giant.',
      'Самый ветреный и далёкий гигант системы.',
    ],
  };
}

/// Kisa yol: her yerde `t('key')` yazabilmek icin.
String t(String key, [Map<String, String>? args]) =>
    AppLocale.instance.t(key, args);
