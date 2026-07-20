import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Meteor (para birimi) ikonu — projenin "hiçbir dış görsel/svg dosyası
/// yok, her şey Canvas ile çizilir" ilkesine uyar: düzensiz, kraterli
/// bir kayaç + arkasında kısa bir alev izi, tamamen CustomPainter ile
/// vektörel üretilir.
class MeteorIcon extends StatelessWidget {
  final double size;
  const MeteorIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MeteorPainter(),
    );
  }
}

class _MeteorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.58;
    final cy = size.height * 0.52;
    final r = size.width * 0.34;

    // Alev izi (sol-alttan gelen kısa kuyruk).
    final trailPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.meteorTrail.withOpacity(0.0), AppColors.meteorTrail.withOpacity(0.85)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final trailPath = Path()
      ..moveTo(cx - r * 1.9, cy + r * 1.7)
      ..quadraticBezierTo(
          cx - r * 0.9, cy + r * 0.3, cx - r * 0.25, cy - r * 0.15)
      ..lineTo(cx - r * 0.05, cy + r * 0.35)
      ..quadraticBezierTo(
          cx - r * 1.1, cy + r * 0.9, cx - r * 1.5, cy + r * 2.05)
      ..close();
    canvas.drawPath(trailPath, trailPaint);

    // Ana gövde (düzensiz çokgen kayaç).
    final rnd = Random(7);
    final points = <Offset>[];
    const sides = 8;
    for (var i = 0; i < sides; i++) {
      final angle = (i / sides) * 2 * pi;
      final wobble = 0.82 + rnd.nextDouble() * 0.3;
      points.add(Offset(
        cx + cos(angle) * r * wobble,
        cy + sin(angle) * r * wobble,
      ));
    }
    final bodyPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      bodyPath.lineTo(points[i].dx, points[i].dy);
    }
    bodyPath.close();

    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: const [AppColors.meteorCore, AppColors.meteorEdge],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawPath(bodyPath, bodyPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..color = Colors.black.withOpacity(0.25);
    canvas.drawPath(bodyPath, rimPaint);

    // Küçük kraterler.
    final craterPaint = Paint()..color = AppColors.meteorEdge.withOpacity(0.55);
    canvas.drawCircle(Offset(cx - r * 0.25, cy - r * 0.1), r * 0.16, craterPaint);
    canvas.drawCircle(Offset(cx + r * 0.2, cy + r * 0.28), r * 0.12, craterPaint);
  }

  @override
  bool shouldRepaint(covariant _MeteorPainter oldDelegate) => false;
}

/// Ana ekran üst bar için: sağ üstte "🔶 sayı" formatındaki para birimi
/// rozetlerinin meteor sürümü.
class MeteorBadge extends StatelessWidget {
  final int amount;
  final VoidCallback? onTap;
  const MeteorBadge({super.key, required this.amount, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.tubeGlass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.tubeGlassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MeteorIcon(size: 16),
            const SizedBox(width: 5),
            Text(
              '$amount',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
