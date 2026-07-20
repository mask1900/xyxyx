import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/economy_config.dart';
import '../game/orbit_controller.dart';
import '../services/ad_service.dart';
import '../services/player_progress.dart';
import '../services/sound_service.dart';
import '../theme/app_colors.dart';
import '../widgets/daily_result_dialog.dart';
import '../widgets/meteor_icon.dart';
import '../widgets/orbit_board.dart';
import '../widgets/orbit_planet_chip.dart';
import '../widgets/backgrounds/level_background.dart';

class OrbitGameScreen extends StatefulWidget {
  final int? startStage;
  final bool isDaily;
  const OrbitGameScreen({super.key, this.startStage, this.isDaily = false})
      : assert(startStage != null || isDaily);

  @override
  State<OrbitGameScreen> createState() => _OrbitGameScreenState();
}

class _OrbitGameScreenState extends State<OrbitGameScreen> {
  late int _stage;
  late OrbitController _controller;
  bool _dialogShown = false;
  bool _dockAdUsed = false;
  int _paidDockAttempts = 0;
  int? _lastUnlockNotified;
  Stopwatch _stopwatch = Stopwatch();

  static const _tutorialPrefsKey = 'orbit_tutorial_seen_v1';

  @override
  void initState() {
    super.initState();
    _stage = widget.startStage ?? 1;
    _startLevel(_stage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
    // Bolum ekrani muzigi: sonsuz dongude calar (ana ekrandaki menu
    // muzigini otomatik olarak durdurup yerini alir).
    SoundService.instance.playBgm('audio/kinetic_overdrive.mp3');
  }

  Future<void> _maybeShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_tutorialPrefsKey) ?? false;
    if (seen || !mounted) return;
    await prefs.setBool(_tutorialPrefsKey, true);
    if (!mounted) return;
    _showTutorialDialog();
  }

  Future<void> _showTutorialDialog() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const _OrbitTutorialDialog(),
    );
  }

  void _startLevel(int stage) {
    if (widget.isDaily) {
      _controller = OrbitController.daily(
        dailyNumber: PlayerProgress.dailyNumber(),
        seed: PlayerProgress.dailySeed(),
      );
    } else {
      _controller = OrbitController.forStage(stage, random: Random());
    }
    _dialogShown = false;
    _dockAdUsed = false;
    _paidDockAttempts = 0;
    _stopwatch = Stopwatch()..start();
    _controller.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (_controller.lastUnlockedRing != null &&
        _controller.lastUnlockedRing != _lastUnlockNotified) {
      _lastUnlockNotified = _controller.lastUnlockedRing;
      SoundService.instance.reward();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 1100),
            content: Text('🔓 Kilitli halka açıldı!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
    if (_dialogShown) return;
    if (_controller.status == OrbitStatus.won) {
      _dialogShown = true;
      _handleWin();
    } else if (_controller.status == OrbitStatus.jammed) {
      _dialogShown = true;
      _showJamDialog();
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleWin() async {
    _stopwatch.stop();
    final stars = _controller.starsForResult();
    final colorCount = _controller.level.targetQueue.toSet().length;
    await PlayerProgress.instance.markPlanetsDiscovered(colorCount);

    if (widget.isDaily) {
      await PlayerProgress.instance.recordDailyResult(
        moves: _controller.rotations,
        optimal: _controller.level.parRotations,
        timeSeconds: _stopwatch.elapsed.inSeconds,
      );
      SoundService.instance.win();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const DailyResultDialog(isReplay: false),
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    SoundService.instance.win();
    await PlayerProgress.instance.recordOrbitStageResult(
      stage: _stage,
      stars: stars,
      moves: _controller.rotations,
      optimalMoves: _controller.level.parRotations,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResultDialog(
        success: true,
        stars: stars,
        rotations: _controller.rotations,
        par: _controller.level.parRotations,
        onNext: () {
          Navigator.of(ctx).pop();
          setState(() {
            _controller.removeListener(_onStateChanged);
            _stage++;
            _startLevel(_stage);
          });
        },
        onExit: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _showJamDialog() async {
    SoundService.instance.buttonTap();
    if (!mounted) return;
    final meteorPrice = EconomyConfig.orbitDockPriceFor(_paidDockAttempts);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResultDialog(
        success: false,
        stars: 0,
        rotations: _controller.rotations,
        par: _controller.level.parRotations,
        onWatchAd: _dockAdUsed ? null : () => _watchAdAndExpandDock(ctx),
        bankedDockSlots: PlayerProgress.instance.bankedOrbitDockSlots,
        onUseBankedSlot: PlayerProgress.instance.bankedOrbitDockSlots > 0
            ? () => _useBankedDockSlot(ctx)
            : null,
        // Reklam hakki zaten kullanildiysa (ya da direkt oradan sonraki
        // her denemede) meteorla kademeli artan fiyata rihtim genislet.
        meteorPrice: _dockAdUsed ? meteorPrice : null,
        meteorBalance: PlayerProgress.instance.meteors,
        onBuyWithMeteors: _dockAdUsed ? () => _buyDockWithMeteors(ctx) : null,
        onNext: () {
          Navigator.of(ctx).pop();
          setState(() {
            _controller.removeListener(_onStateChanged);
            _startLevel(_stage);
          });
        },
        onExit: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  /// Reklam hakki tukendikten sonraki her rihtim genisletmesi icin meteor
  /// harcar (fiyat her denemede kademeli artar — bkz. EconomyConfig).
  /// Ortak cekirdek: hem sikisma diyalogundan hem de canli rihtim
  /// satirindaki chip'ten kullanilir.
  Future<bool> _purchaseDockSlotWithMeteors() async {
    final ok = await PlayerProgress.instance
        .spendMeteorsForOrbitDock(_paidDockAttempts);
    if (!ok) return false;
    _paidDockAttempts++;
    SoundService.instance.reward();
    _controller.expandDock();
    _dialogShown = false;
    if (mounted) setState(() {});
    return true;
  }

  Future<void> _buyDockWithMeteors(BuildContext dialogContext) async {
    final ok = await _purchaseDockSlotWithMeteors();
    if (!ok) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(content: Text('☄️ Yeterli meteorun yok')),
        );
      }
      return;
    }
    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
  }

  /// Canli rihtim satirindaki (henuz sikisma olmadan, proaktif) meteor
  /// satin alma chip'i icin — burada kapatilacak bir dialog yok.
  Future<void> _buyDockWithMeteorsFromRow() async {
    final ok = await _purchaseDockSlotWithMeteors();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('☄️ Yeterli meteorun yok')),
      );
    }
  }

  /// Kozmik Ikmal'den biriktirilen "rihtim yuvasi" hakkini reklamsiz
  /// harcar; sikisma diyalogunu kapatip oyuna kaldigi yerden devam
  /// ettirir.
  Future<void> _useBankedDockSlot(BuildContext dialogContext) async {
    await PlayerProgress.instance.spendBankedOrbitDockSlot();
    SoundService.instance.reward();
    _controller.expandDock();
    _dialogShown = false;
    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
    if (mounted) setState(() {});
  }

  /// Odullu reklami izletir, basariliysa rihtime +1 yuva ekler ve — oyun
  /// sikismis haldeyse — sikisma diyalogunu kapatip oyuna kaldigi yerden
  /// devam ettirir (Pixel Flow'daki "tampon genislet" odul-devam akisiyla
  /// ayni fikir).
  Future<void> _watchAdAndExpandDock(BuildContext dialogContext) async {
    final granted = await AdService.instance.showRewardedAdFlow(
      dialogContext,
      icon: '🛰️',
      title: 'Rıhtımı Genişlet',
      subtitle: 'Reklamı izle, bu bölüm için +1 kargo yuvası kazan.',
    );
    if (granted != true) return;
    SoundService.instance.reward();
    _dockAdUsed = true;
    _controller.expandDock();
    _dialogShown = false;
    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
    if (mounted) setState(() {});
  }

  Future<void> _watchAdFromDockRow() async {
    if (_dockAdUsed || !mounted) return;
    final granted = await AdService.instance.showRewardedAdFlow(
      context,
      icon: '🛰️',
      title: 'Rıhtımı Genişlet',
      subtitle: 'Reklamı izle, bu bölüm için +1 kargo yuvası kazan.',
    );
    if (granted != true || !mounted) return;
    SoundService.instance.reward();
    setState(() {
      _dockAdUsed = true;
      _controller.expandDock();
    });
  }

  void _onBlockedTap(int ringIndex) {
    final isLocked = _controller.lastLockedRingAttempt == ringIndex &&
        _controller.level.rings[ringIndex].locked;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 900),
        content: Text(
          isLocked
              ? '🔒 Bu halka hâlâ kilitli — birkaç teslimat daha yap'
              : '🚧 Rıhtım dolu — önce oradaki yükü boşalt!',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _controller.removeListener(_onStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LevelBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTargetStrip(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: OrbitBoard(
                    controller: _controller,
                    onBlockedTap: _onBlockedTap,
                  ),
                ),
              ),
              _buildDockRow(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text('🪐', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.isDaily
                    ? 'Günlük Yörünge Vardiyası'
                    : 'Yörünge Vardiyası · Bölüm $_stage',
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded,
                color: AppColors.textSecondary, size: 20),
            onPressed: _showTutorialDialog,
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (!_controller.level.comboEnabled) {
                return _headerBadge('🔄 ${_controller.rotations}');
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _headerBadge('🔄 ${_controller.rotations}'),
                  const SizedBox(width: 6),
                  _headerBadge(
                    _controller.combo > 1
                        ? '🔥 ${_controller.score} · x${_controller.combo}'
                        : '🔥 ${_controller.score}',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _headerBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tubeGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tubeGlassBorder),
      ),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12)),
    );
  }

  Widget _buildTargetStrip() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final upcoming = _controller.upcomingTargets(6);
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.tubeGlass,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.tubeGlassBorder),
          ),
          child: Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text('İstenen sıra',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(upcoming.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PlanetChip(
                          colorIndex: upcoming[i],
                          size: i == 0 ? 24 : 18,
                          highlighted: i == 0,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_controller.deliveredCount}/${_controller.totalCount}',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDockRow() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.tubeGlass,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.tubeGlassBorder),
          ),
          child: Row(
            children: [
              const Text('🛰️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Text('Kargo Rıhtımı',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _controller.dock.map((slot) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: slot == null
                            ? Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: AppColors.surfaceBorder),
                                ),
                              )
                            : PlanetChip(
                                colorIndex: slot, size: 26, highlighted: true),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!_dockAdUsed)
                GestureDetector(
                  onTap: _watchAdFromDockRow,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accentSoft),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_fill_rounded,
                            color: AppColors.accentSoft, size: 16),
                        SizedBox(width: 4),
                        Text('+1 Yuva',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _buyDockWithMeteorsFromRow,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.meteorEdge.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.meteorCore),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MeteorIcon(size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '+1 · ${EconomyConfig.orbitDockPriceFor(_paidDockAttempts)}',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Oyuncuya Yorunge Sikismasi'nin dokunma kuralini gosteren, ilk seferde
/// otomatik acilan (ve istendiginde header'daki "?" ile tekrar acilabilen)
/// aciklama diyalogu.
class _OrbitTutorialDialog extends StatelessWidget {
  const _OrbitTutorialDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.surfaceBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🪐', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            const Text(
              'Yörünge Vardiyası Nasıl Oynanır?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 17),
            ),
            const SizedBox(height: 16),
            _rule(
              icon: Icons.adjust_rounded,
              iconColor: AppColors.accentSoft,
              title: '1) Hangi halka?',
              body:
                  'Merkeze olan uzaklığına göre dokun. İç içe halkalardan hangisine '
                  'dokunursan o halka döner.',
            ),
            const SizedBox(height: 12),
            _rule(
              icon: Icons.compare_arrows_rounded,
              iconColor: AppColors.warning,
              title: '2) Hangi yön?',
              body:
                  'Dokunduğun nokta halkanın SOLUNDAYSA halka ters yönde, '
                  'SAĞINDAYSA saat yönünde bir adım döner.',
            ),
            const SizedBox(height: 12),
            _rule(
              icon: Icons.local_shipping_rounded,
              iconColor: AppColors.success,
              title: '3) Kapı ve rıhtım',
              body:
                  'Tepedeki kapıya gelen gezegen, sıradaki hedefle eşleşiyorsa '
                  'teslim edilir; eşleşmiyorsa rıhtımda bekler. Rıhtım doluyken '
                  'hedefe uymayan bir gezegeni kapıya getirecek dönüşler engellenir.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Anladım'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rule({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(body,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultDialog extends StatelessWidget {
  final bool success;
  final int stars;
  final int rotations;
  final int par;
  final VoidCallback onNext;
  final VoidCallback onExit;
  final VoidCallback? onWatchAd;
  final VoidCallback? onUseBankedSlot;
  final int bankedDockSlots;
  final int? meteorPrice;
  final int meteorBalance;
  final VoidCallback? onBuyWithMeteors;

  const _ResultDialog({
    required this.success,
    required this.stars,
    required this.rotations,
    required this.par,
    required this.onNext,
    required this.onExit,
    this.onWatchAd,
    this.onUseBankedSlot,
    this.bankedDockSlots = 0,
    this.meteorPrice,
    this.meteorBalance = 0,
    this.onBuyWithMeteors,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.surfaceBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(success ? '🪐' : '🚧', style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(
              success ? 'Sistem Tamamlandı!' : 'Rıhtım Tıkandı',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18),
            ),
            const SizedBox(height: 6),
            if (success)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final filled = i < stars;
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? AppColors.warning : AppColors.textSecondary,
                    size: 28,
                  );
                }),
              )
            else
              const Text(
                'Tüm rıhtım yuvaları doldu ve kapıya gelen kargo eşleşmedi.\n'
                'Farklı bir sırayla dene!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            const SizedBox(height: 6),
            Text(
              'Dönüş: $rotations  ·  Hedef: $par',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            if (onUseBankedSlot != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSoft,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onUseBankedSlot,
                  icon: const Icon(Icons.inventory_2_rounded),
                  label: Text('⚓ Bankadan Yuva Kullan ($bankedDockSlots kalan)'),
                ),
              ),
            ],
            if (onWatchAd != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onWatchAd,
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: const Text('Reklam İzle · +1 Rıhtım Yuvası'),
                ),
              ),
            ],
            if (onBuyWithMeteors != null && meteorPrice != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: meteorBalance >= meteorPrice!
                        ? AppColors.meteorEdge
                        : AppColors.surfaceBorder,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onBuyWithMeteors,
                  icon: const MeteorIcon(size: 18),
                  label: Text(
                    '☄️ $meteorPrice Meteor ile Genişlet  ·  ($meteorBalance elinde)',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onExit,
                    child: const Text('Çıkış'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    onPressed: onNext,
                    child: Text(success ? 'Sonraki Bölüm' : 'Tekrar Dene'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
