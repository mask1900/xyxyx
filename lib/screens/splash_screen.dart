import 'package:flutter/material.dart';

import '../services/cloud_progress_sync.dart';
import '../services/localization.dart';
import '../services/planet_images.dart';
import '../services/play_games_service.dart';
import '../services/player_progress.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'language_select_screen.dart';

/// HTML prototipindeki #splash-screen ile ayni fikir: roket + baslik +
/// slogan + ilerleme cubugu. Yukleme (PlayerProgress.load()) bitince VEYA
/// ~2 saniye sonra (hangisi once gelirse) ana ekrana geciyor; ekrana
/// dokununca da hemen atlanabiliyor.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flameController;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    )..repeat(reverse: true);
    _boot();
  }

  Future<void> _boot() async {
    final loadFuture = PlayerProgress.instance.load();
    final localeFuture = AppLocale.instance.load();
    final planetsFuture = PlanetImages.preload();
    await Future.wait([
      loadFuture,
      localeFuture,
      planetsFuture,
      Future.delayed(const Duration(milliseconds: 1600)),
    ]);
    // Yerel ilerleme yuklendikten SONRA Play Games'e sessizce baglanmayi
    // dene; basariliysa buluttaki (varsa) daha ileri kaydi uygula.
    await PlayGamesService.instance.signInSilently();
    if (PlayGamesService.instance.isSignedIn) {
      await CloudProgressSync.instance.syncAfterSignIn();
    }
    _goHome();
  }

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    final needsLanguage = !AppLocale.instance.hasChosenLanguage;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => needsLanguage
            ? const LanguageSelectScreen()
            : const HomeScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _flameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.spaceTop,
      body: GestureDetector(
        onTap: _goHome,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _flameController,
                  builder: (context, _) {
                    final flicker = 0.85 + _flameController.value * 0.3;
                    return CustomPaint(
                      size: const Size(76, 114),
                      painter: _RocketPainter(flameScale: flicker),
                    );
                  },
                ),
                const SizedBox(height: 22),
                const Text(
                  '🚀 AstroFelyx',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t('splashTagline'),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 34),
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: const LinearProgressIndicator(
                      backgroundColor: AppColors.surfaceBorder,
                      valueColor: AlwaysStoppedAnimation(AppColors.accent),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// HTML splash'indeki roket SVG'siyle ayni siluet: 4 renkli bolme + alev.
class _RocketPainter extends CustomPainter {
  final double flameScale;
  _RocketPainter({required this.flameScale});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final sx = w / 80.0, sy = h / 120.0;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final hull = Path()
      ..moveTo(p(40, 6).dx, p(40, 6).dy)
      ..cubicTo(p(54, 20).dx, p(54, 20).dy, p(58, 42).dx, p(58, 42).dy,
          p(58, 66).dx, p(58, 66).dy)
      ..lineTo(p(58, 86).dx, p(58, 86).dy)
      ..cubicTo(p(58, 90).dx, p(58, 90).dy, p(54, 92).dx, p(54, 92).dy,
          p(50, 92).dx, p(50, 92).dy)
      ..lineTo(p(30, 92).dx, p(30, 92).dy)
      ..cubicTo(p(26, 92).dx, p(26, 92).dy, p(22, 90).dx, p(22, 90).dy,
          p(22, 86).dx, p(22, 86).dy)
      ..lineTo(p(22, 66).dx, p(22, 66).dy)
      ..cubicTo(p(22, 42).dx, p(22, 42).dy, p(26, 20).dx, p(26, 20).dy,
          p(40, 6).dx, p(40, 6).dy)
      ..close();

    canvas.drawPath(
      hull,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_shade(0x2A3560, 20), const Color(0xFF151C36)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawPath(
      hull,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFCBD5E1),
    );

    void band(double y1, double y2, Color color) {
      final rect = Rect.fromLTRB(p(26, y1).dx, p(26, y1).dy, p(54, y2).dx, p(54, y2).dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(4 * sx)),
        Paint()..color = color,
      );
    }

    band(70, 88, AppColors.accent);
    band(52, 68, AppColors.accentSoft);
    band(34, 50, AppColors.warning);

    canvas.drawCircle(p(40, 24), 9 * sx, Paint()..color = const Color(0xFF0A0E1F));
    canvas.drawCircle(p(40, 24), 4 * sx, Paint()..color = AppColors.accentSoft.withOpacity(0.9));

    final finPaint = Paint()..color = AppColors.danger;
    canvas.drawPath(
      Path()
        ..moveTo(p(22, 66).dx, p(22, 66).dy)
        ..lineTo(p(8, 90).dx, p(8, 90).dy)
        ..lineTo(p(22, 84).dx, p(22, 84).dy)
        ..close(),
      finPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(p(58, 66).dx, p(58, 66).dy)
        ..lineTo(p(72, 90).dx, p(72, 90).dy)
        ..lineTo(p(58, 84).dx, p(58, 84).dy)
        ..close(),
      finPaint,
    );

    // Alev (flicker animasyonlu): roketin altindaki sabit noktadan
    // (40, 92) asagi dogru dikey olarek olceklenir.
    final flameAnchor = p(40, 92);
    canvas.save();
    canvas.translate(flameAnchor.dx, flameAnchor.dy);
    canvas.scale(1, flameScale);
    canvas.translate(-flameAnchor.dx, -flameAnchor.dy);
    canvas.drawPath(
      Path()
        ..moveTo(p(30, 92).dx, p(30, 92).dy)
        ..lineTo(p(40, 118).dx, p(40, 118).dy)
        ..lineTo(p(50, 92).dx, p(50, 92).dy)
        ..close(),
      Paint()..color = AppColors.warning.withOpacity(0.9),
    );
    canvas.drawPath(
      Path()
        ..moveTo(p(34, 92).dx, p(34, 92).dy)
        ..lineTo(p(40, 108).dx, p(40, 108).dy)
        ..lineTo(p(46, 92).dx, p(46, 92).dy)
        ..close(),
      Paint()..color = Colors.white.withOpacity(0.85),
    );
    canvas.restore();
  }

  Color _shade(int hex, int amt) {
    final c = Color(0xFF000000 | hex);
    int ch(int v) => (v + amt).clamp(0, 255).toInt();
    return Color.fromARGB(255, ch(c.red), ch(c.green), ch(c.blue));
  }

  @override
  bool shouldRepaint(covariant _RocketPainter oldDelegate) =>
      oldDelegate.flameScale != flameScale;
}
