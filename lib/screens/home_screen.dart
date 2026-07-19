import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/ad_service.dart';
import '../services/cloud_progress_sync.dart';
import '../services/localization.dart';
import '../services/play_games_service.dart';
import '../services/player_progress.dart';
import '../services/sound_service.dart';
import '../theme/app_colors.dart';
import '../widgets/daily_result_dialog.dart';
import '../widgets/planet_codex.dart';
import '../widgets/space_background.dart';
import '../widgets/stage_button.dart';
import 'orbit_game_screen.dart';
import 'tube_levels_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PlayerProgress _progress = PlayerProgress.instance;
  final AppLocale _locale = AppLocale.instance;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _progress.addListener(_onProgressChanged);
    _locale.addListener(_onProgressChanged);
    // Ikmal geri sayimini ve gunluk kartini canli tutmak icin periyodik
    // yenileme (yeni bir olay olmasa bile).
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onProgressChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _progress.removeListener(_onProgressChanged);
    _locale.removeListener(_onProgressChanged);
    super.dispose();
  }

  Future<void> _openStage(int stage) async {
    if (stage > _progress.orbitUnlockedStage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('home_lockedStage'))),
      );
      return;
    }
    SoundService.instance.buttonTap();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrbitGameScreen(startStage: stage)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openDaily() async {
    SoundService.instance.buttonTap();
    if (_progress.dailyCompletedToday) {
      await showDialog(
        context: context,
        builder: (_) => const DailyResultDialog(isReplay: true),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrbitGameScreen(isDaily: true)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _claimResupply() async {
    if (!_progress.isResupplyReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⏳ ${_progress.resupplyCountdownText()}')),
      );
      return;
    }
    SoundService.instance.buttonTap();
    final granted = await AdService.instance.showRewardedAdFlow(
      context,
      icon: '🎁',
      title: t('home_resupplyTitle'),
      subtitle: t('ad_defaultSubtitle'),
    );
    if (granted != true || !mounted) return;
    final reward = await _progress.grantResupplyReward(Random());
    if (!mounted) return;
    SoundService.instance.reward();
    final rewardText = switch (reward.kind) {
      ResupplyRewardKind.xp => t('resupply_rewardXp', {'n': '${reward.amount}'}),
      ResupplyRewardKind.hint =>
        t('resupply_rewardHint', {'n': '${reward.amount}'}),
      ResupplyRewardKind.undo =>
        t('resupply_rewardUndo', {'n': '${reward.amount}'}),
      ResupplyRewardKind.extraTube =>
        t('resupply_rewardExtraTube', {'n': '${reward.amount}'}),
      ResupplyRewardKind.flip =>
        t('resupply_rewardFlip', {'n': '${reward.amount}'}),
      ResupplyRewardKind.orbitDockSlot =>
        t('resupply_rewardOrbitDockSlot', {'n': '${reward.amount}'}),
    };
    final rewardIcon = switch (reward.kind) {
      ResupplyRewardKind.xp => '✨',
      ResupplyRewardKind.hint => '🛰️',
      ResupplyRewardKind.undo => '↩️',
      ResupplyRewardKind.extraTube => '🧯',
      ResupplyRewardKind.flip => '🌀',
      ResupplyRewardKind.orbitDockSlot => '⚓',
    };
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
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
              Text(rewardIcon, style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text(
                t('resupply_rewardTitle'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.tubeGlass,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.tubeGlassBorder),
                ),
                child: Text(
                  rewardText,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(t('resupply_close'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProfile() {
    showDialog(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: _locale,
        builder: (context, _) {
          final info = _progress.levelInfo();
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
              const CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.accent,
                child: Icon(Icons.person_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 14),
              // --- Seviye ilerleme cubugu (HTML'deki level-progress-track/fill) ---
              Row(
                children: [
                  Text('🎖️ ${t('profile_level')} ${info.level}',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                  const Spacer(),
                  Text('${info.xpIntoLevel} / ${info.xpForNext} XP',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 10,
                  child: Stack(
                    children: [
                      Container(color: AppColors.surfaceBorder),
                      FractionallySizedBox(
                        widthFactor: info.progress,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.accent,
                                AppColors.accentSoft,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tubeGlass,
                  border: Border.all(color: AppColors.tubeGlassBorder),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _profileStat('⭐', '${_progress.totalStars}',
                        t('profile_totalStars')),
                    _profileStat('🏆', '${_progress.stageStats.length}',
                        t('profile_stagesCleared')),
                    _profileStat('💯', '${_progress.totalScore}',
                        t('profile_totalScore')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // --- Dil secici (TR / EN / RU) ---
              Align(
                alignment: Alignment.centerLeft,
                child: Text(t('profile_language'),
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _langButton(ctx, AppLanguage.tr, '🇹🇷 TR'),
                  const SizedBox(width: 8),
                  _langButton(ctx, AppLanguage.en, '🇬🇧 EN'),
                  const SizedBox(width: 8),
                  _langButton(ctx, AppLanguage.ru, '🇷🇺 RU'),
                ],
              ),
              const SizedBox(height: 16),
              // --- Play Games baglantisi (sadece giris + ilerleme kaydi) ---
              Align(
                alignment: Alignment.centerLeft,
                child: Text(t('profile_playGames'),
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
              const SizedBox(height: 6),
              StatefulBuilder(
                builder: (ctx2, setDialogState) {
                  final connected = PlayGamesService.instance.isSignedIn;
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: connected
                          ? null
                          : () async {
                              final ok =
                                  await PlayGamesService.instance.signIn();
                              if (ok) {
                                await CloudProgressSync.instance
                                    .syncAfterSignIn();
                              }
                              setDialogState(() {});
                              if (!ok && ctx2.mounted) {
                                ScaffoldMessenger.of(ctx2).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(t('profile_playGamesFailed')),
                                  ),
                                );
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            connected ? AppColors.success : AppColors.textPrimary,
                        side: BorderSide(
                          color: connected
                              ? AppColors.success
                              : AppColors.tubeGlassBorder,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        connected
                            ? t('profile_playGamesConnected')
                            : t('profile_playGamesConnect'),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tubeGlass,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('profile_about'),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      t('profile_aboutText'),
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(t('profile_close'),
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      );
        },
      ),
    );
  }

  Widget _langButton(BuildContext ctx, AppLanguage lang, String label) {
    final active = _locale.language == lang;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          SoundService.instance.buttonTap();
          _locale.setLanguage(lang);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : AppColors.tubeGlass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.accent : AppColors.tubeGlassBorder,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileStat(String icon, String value, String label) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
        Text(label,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _progress.levelInfo();
    final maxShown = max(20, _progress.orbitUnlockedStage + 8);

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(info),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _buildResupplyCard(),
                    const SizedBox(height: 12),
                    _buildDailyCard(),
                    const SizedBox(height: 12),
                    _buildTubeCard(),
                    const SizedBox(height: 12),
                    _buildSolarSystemCard(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text('🛰️', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text(
                          'Yörünge Vardiyası',
                          style: const TextStyle(
                            color: AppColors.accentSoft,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('home_chooseStage'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('home_stageHint'),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: maxShown,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.92,
                      ),
                      itemBuilder: (context, index) {
                        final stage = index + 1;
                        return StageButton(
                          stage: stage,
                          locked: stage > _progress.orbitUnlockedStage,
                          isCurrent: stage == _progress.orbitUnlockedStage,
                          stat: _progress.orbitStageStats[stage],
                          onTap: () => _openStage(stage),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(LevelInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          const Text('🚀', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            t('appName'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          _headerBadge('🎖️ ${info.level}'),
          const SizedBox(width: 8),
          _headerBadge('⭐ ${_progress.totalStars}'),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openProfile,
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accent,
              child: Icon(Icons.person_rounded, color: Colors.white, size: 18),
            ),
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

  Widget _buildResupplyCard() {
    final ready = _progress.isResupplyReady;
    final watched = _progress.resupplyAdsWatched;
    return GestureDetector(
      onTap: _claimResupply,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Opacity(
          opacity: ready ? 1.0 : 0.75,
          child: Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('home_resupplyTitle'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      t('home_resupplySubtitle'),
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ready
                          ? '${t('home_resupplyReady')} ($watched/3)'
                          : '⏳ ${_progress.resupplyCountdownText()}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTubeLevels() async {
    SoundService.instance.buttonTap();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TubeLevelsScreen()),
    );
    if (mounted) setState(() {});
  }

  Widget _buildTubeCard() {
    return GestureDetector(
      onTap: _openTubeLevels,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C5CFF), Color(0xFF22C55E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Text('🧪', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enerji Tüpleri',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Klasik renk sıralama bulmacası · kendi bölümleri',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyCard() {
    final completed = _progress.dailyCompletedToday;
    return GestureDetector(
      onTap: _openDaily,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Text(completed ? '✅' : '🌌', style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    completed ? t('home_dailyDoneTitle') : t('home_dailyTitle'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    completed
                        ? t('home_dailyDoneSubtitle')
                        : t('home_dailySubtitle'),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('🔥${_progress.dailyStreak}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolarSystemCard() {
    final discoveredCount = _progress.discoveredPlanets.length;
    return GestureDetector(
      onTap: () {
        SoundService.instance.buttonTap();
        PlanetCodexSheet.show(context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C5CFF), Color(0xFF2A1B6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Text('🪐', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('codex_cardTitle'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t('codex_cardSubtitle', {'n': '$discoveredCount'}),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (discoveredCount / kTotalPlanets).clamp(0, 1),
                      minHeight: 6,
                      backgroundColor: Colors.black26,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

