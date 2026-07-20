import 'package:flutter/material.dart';

import '../screens/legal_webview_screen.dart';
import '../services/gdpr_service.dart';
import '../services/legal_links.dart';
import '../services/localization.dart';
import '../services/sound_service.dart';
import '../theme/app_colors.dart';

/// Ilk acilista (dil secimi hemen sonrasinda) gosterilen, kapatilamaz
/// (barrier dismiss / geri tusu ile kapanmaz) sozlesme + GDPR onay
/// popup'i. AstroFelyxAI uygulamasindaki akistan ilham alinmistir, ancak
/// bu oyuna ait KENDI metinlerini ve KENDI legal linklerini kullanir.
///
/// * AB disi kullanicilar (ör. Türkiye): tek bir "Kabul Et ve Devam Et"
///   dugmesi gorur.
/// * AB/AEA/Isvicre/UK kullanicilari: iki secenek gorur -
///   "Kisisellestirilmis Reklamlari Kabul Et" / "Kisisellestirilmemis
///   Reklamlari Kabul Et". Her iki durumda da sozlesme kabul edilmis
///   sayilir; fark sadece reklam kisisellestirmesidir. Bu secim daha
///   sonra Profil ekranindan degistirilebilir.
class ConsentDialog extends StatelessWidget {
  const ConsentDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConsentDialog(),
    );
  }

  void _openPrivacy(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalWebViewScreen(
          url: LegalLinks.privacyPolicyUrl,
          title: t('legal_privacyPolicy'),
        ),
      ),
    );
  }

  void _openTerms(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalWebViewScreen(
          url: LegalLinks.termsUrl,
          title: t('legal_terms'),
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, {required bool personalized}) async {
    SoundService.instance.buttonTap();
    await GdprService.instance.acceptTerms(personalizedAds: personalized);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEU = GdprService.instance.isEUUser;

    return PopScope(
      canPop: false,
      child: Dialog(
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
              const Text('🚀', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 10),
              Text(
                t('consent_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t('consent_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.accentSoft),
                        foregroundColor: AppColors.accentSoft,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _openPrivacy(context),
                      child: Text(
                        t('legal_privacyPolicy'),
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.accentSoft),
                        foregroundColor: AppColors.accentSoft,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _openTerms(context),
                      child: Text(
                        t('legal_terms'),
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (isEU) ...[
                Text(
                  t('consent_euText'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _accept(context, personalized: true),
                    child: Text(
                      t('consent_euAccept'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _accept(context, personalized: false),
                    child: Text(
                      t('consent_euDecline'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _accept(context, personalized: true),
                    child: Text(
                      t('consent_acceptContinue'),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
