import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import '../theme/app_colors.dart';
import 'localization.dart';
import 'sound_service.dart';

/// Odullu (rewarded) reklam akisini yoneten servis — Yandex Mobile Ads
/// Flutter SDK (yandex_mobileads) ile gercek entegrasyon.
///
/// ONEMLI: [rewardedAdUnitId] su an Yandex'in DEMO reklam birimi ID'sini
/// kullaniyor ('demo-rewarded-yandex'), boylece her istekte gercek (ama
/// test amacli) bir odullu reklam gosterilir ve para kazanilmaz. Yandex
/// Reklam Agi panelinden kendi uygulamani kaydedip GERCEK reklam birimi
/// ID'ni (orn. 'R-M-XXXXXX-Y') aldiktan sonra, yayina almadan once BU
/// SABITI degistirmen yeterli — akisin geri kalani aynen calisir.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  /// TODO(yayin-oncesi): Yandex Reklam Agi panelinden alinan gercek
  /// odullu reklam birimi ID'si ile degistir.
  static const String rewardedAdUnitId = 'demo-rewarded-yandex';

  final RewardedAdLoader _loader = RewardedAdLoader();
  RewardedAd? _ad;
  bool _isLoading = false;

  /// Bir sonraki gosterim icin onceden bir reklam yuklemeyi dener.
  /// Basarisiz olursa sessizce yutulur; [showRewardedAdFlow] gosterim
  /// aninda tekrar yuklemeyi dener.
  Future<void> preload() async {
    if (_ad != null || _isLoading) return;
    _isLoading = true;
    try {
      _ad = await _loader.loadAd(
        adRequest: AdRequest(adUnitId: rewardedAdUnitId),
      );
    } catch (_) {
      _ad = null;
    } finally {
      _isLoading = false;
    }
  }

  /// Kullaniciya "Reklam Izle" onay diyalogunu gosterir, onaylanirsa
  /// gercek odullu reklami yukleyip gosterir ve odulun verilip
  /// verilmeyecegini (true/false) dondurur. Kullanici iptal ederse null
  /// doner.
  Future<bool?> showRewardedAdFlow(
    BuildContext context, {
    required String icon,
    required String title,
    String? subtitle,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AdConfirmDialog(
        icon: icon,
        title: title,
        subtitle: subtitle ?? t('ad_defaultSubtitle'),
      ),
    );
    if (confirmed != true) return null;
    if (!context.mounted) return false;

    // "Yukleniyor" gostergesi + reklamin gercekten yuklenip gosterilmesi.
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AdLoadingDialog(),
    ));
    final granted = await _loadAndShow();
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return granted;
  }

  Future<bool> _loadAndShow() async {
    if (_ad == null) {
      await preload();
    }
    final ad = _ad;
    if (ad == null) {
      // Reklam yuklenemedi (orn. internet yok) — odul verilmeden akis
      // sessizce sonlandirilir, oyun asla bozulmaz.
      return false;
    }
    _ad = null; // ayni reklam ikinci kez gosterilmesin diye hemen ayir.

    final completer = Completer<bool>();
    ad.setAdEventListener(
      eventListener: RewardedAdEventListener(
        onAdShown: () {},
        onAdFailedToShow: (error) {
          ad.destroy();
          if (!completer.isCompleted) completer.complete(false);
          unawaited(preload());
        },
        onAdClicked: () {},
        onAdDismissed: () {
          ad.destroy();
          unawaited(preload());
        },
        onAdImpression: (impressionData) {},
        onRewarded: (reward) {
          if (!completer.isCompleted) completer.complete(true);
        },
      ),
    );

    try {
      await ad.show();
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
    }

    // Reklam kapatilana kadar bekle; odul gelmediyse false ile tamamlanir.
    unawaited(Future.delayed(const Duration(seconds: 30), () {
      if (!completer.isCompleted) completer.complete(false);
    }));
    return completer.future;
  }
}

class _AdConfirmDialog extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  const _AdConfirmDialog({
    required this.icon,
    required this.title,
    required this.subtitle,
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
            Text(icon, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
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
                onPressed: () {
                  SoundService.instance.buttonTap();
                  Navigator.of(context).pop(true);
                },
                child: Text(t('ad_watch'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.surfaceBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(t('ad_cancel'),
                    style: const TextStyle(color: AppColors.textPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdLoadingDialog extends StatelessWidget {
  const _AdLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.accentSoft),
            const SizedBox(height: 16),
            Text(t('ad_loading'),
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
