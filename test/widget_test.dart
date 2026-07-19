import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:space_sort_game/main.dart';

void main() {
  setUp(() {
    // shared_preferences'in gercek platform kanalina ihtiyac duymadan
    // testlerde calismasi icin bos bir baslangic durumu tanimlar.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Splash ekrani acilir ve ana ekrana gecer', (tester) async {
    await tester.pumpWidget(const CosmicSortApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('🚀 Space Sort'), findsOneWidget);

    // Splash, yukleme bitince (veya ~1.6sn sonra) otomatik ana ekrana gecer.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Görev Seç'), findsOneWidget);
  });

  testWidgets('Bir goreve girince en az bir tup gorunur', (tester) async {
    await tester.pumpWidget(const CosmicSortApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(CustomPaint), findsWidgets);
  });
}
