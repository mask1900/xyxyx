import 'package:flutter/material.dart';

/// Bir "enerji tasi" ailesini belirtir. HTML prototipindeki PALETTE ile
/// birebir eslesir: her renk sabit bir uzay tasi ailesine (kayac/kristal/
/// kulce) baglidir, boylece ayni renk her zaman ayni dokuda gorunur.
enum RockShape { rock, crystal, nugget }

class RockColor {
  final Color color;
  final RockShape shape;
  const RockColor(this.color, this.shape);
}

/// Uygulama genelinde kullanilan sabit renkler.
class AppColors {
  AppColors._();

  static const spaceTop = Color(0xFF05061A);
  static const spaceMid = Color(0xFF0B0F2E);
  static const spaceBottom = Color(0xFF1A1040);

  static const nebulaPink = Color(0x33FF5CC8);
  static const nebulaCyan = Color(0x335CFFE0);

  static const tubeGlass = Color(0x33FFFFFF);
  static const tubeGlassBorder = Color(0x99B8C6FF);
  static const tubeSelectedGlow = Color(0xFF8CFFEA);

  static const textPrimary = Color(0xFFEAF0FF);
  static const textSecondary = Color(0xFF9AA5D1);

  static const accent = Color(0xFF7C5CFF);
  static const accentSoft = Color(0xFF5CC8FF);

  static const surface = Color(0xFF151C36);
  static const surfaceBorder = Color(0xFF2A3560);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
  static const zeroGGlow = Color(0xFFB388FF);

  /// HTML'deki PALETTE ile ayni renk + aile sirasi (Mars tozu, Neptun
  /// mavisi, aurora yesili, yildiz altini, nebula moru, roket alevi,
  /// plazma camgobegi, supernova pembesi, asteroit kahvesi, derin uzay
  /// turkuazi). En fazla 10 renge kadar destekleniyor.
  static const List<RockColor> palette = [
    RockColor(Color(0xFFE4572E), RockShape.rock),
    RockColor(Color(0xFF3B82F6), RockShape.nugget),
    RockColor(Color(0xFF22C55E), RockShape.nugget),
    RockColor(Color(0xFFFBBF24), RockShape.nugget),
    RockColor(Color(0xFFA855F7), RockShape.crystal),
    RockColor(Color(0xFFF97316), RockShape.rock),
    RockColor(Color(0xFF06B6D4), RockShape.crystal),
    RockColor(Color(0xFFEC4899), RockShape.crystal),
    RockColor(Color(0xFF92400E), RockShape.rock),
    RockColor(Color(0xFF0D9488), RockShape.crystal),
  ];

  static RockColor rockFor(int index) => palette[index % palette.length];
  static Color colorFor(int index) => rockFor(index).color;
}
