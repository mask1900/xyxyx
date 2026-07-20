import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../theme/app_colors.dart';

class WinDialog extends StatelessWidget {
  final int stage;
  final int stars;
  final int moveCount;
  final String timeLabel;
  final int score;
  final int gainedXp;
  final bool leveledUp;
  final int? newLevel;
  final VoidCallback onNextStage;
  final VoidCallback onClose;

  const WinDialog({
    super.key,
    required this.stage,
    required this.stars,
    required this.moveCount,
    required this.timeLabel,
    required this.score,
    required this.gainedXp,
    required this.leveledUp,
    required this.newLevel,
    required this.onNextStage,
    required this.onClose,
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
            const Icon(Icons.rocket_launch_rounded,
                color: AppColors.accentSoft, size: 42),
            const SizedBox(height: 10),
            Text(
              t('win_missionCompleted', {'n': '$stage'}),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final lit = i < stars;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    lit ? Icons.star_rounded : Icons.star_border_rounded,
                    color: lit ? AppColors.warning : AppColors.textSecondary,
                    size: 30,
                  ),
                );
              }),
            ),
            if (leveledUp) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t('win_levelUp', {'n': '$newLevel'}),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statColumn(t('win_moves'), '$moveCount'),
                _statColumn(t('win_time'), timeLabel),
                _statColumn(t('win_score'), '$score'),
                _statColumn('XP', '+$gainedXp'),
              ],
            ),
            const SizedBox(height: 22),
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
                onPressed: onNextStage,
                child: Text(t('win_nextMission'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onClose,
              child: Text(
                t('win_backToMissions'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
