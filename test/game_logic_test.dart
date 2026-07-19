import 'package:flutter_test/flutter_test.dart';
import 'package:space_sort_game/models/tube.dart';
import 'package:space_sort_game/game/game_controller.dart';
import 'package:space_sort_game/game/level_config.dart';

void main() {
  group('Tube model', () {
    test('bos tup isSolved=true doner', () {
      final t = Tube(4);
      expect(t.isSolved, isTrue);
    });

    test('tek renkle tam dolu tup isSolved=true doner', () {
      final t = Tube(4, [1, 1, 1, 1]);
      expect(t.isSolved, isTrue);
    });

    test('karisik renkli tup isSolved=false doner', () {
      final t = Tube(4, [1, 1, 2, 2]);
      expect(t.isSolved, isFalse);
    });

    test('topRunLength dogru sayiyor', () {
      final t = Tube(4, [0, 2, 1, 1]);
      expect(t.topRunLength, 2);
    });
  });

  group('LevelConfig', () {
    test('seviye ilerledikce renk sayisi artiyor (ama makul sinirda)', () {
      final l1 = LevelConfig.forLevel(1);
      final l10 = LevelConfig.forLevel(10);
      final l50 = LevelConfig.forLevel(50);

      expect(l1.colorCount, lessThanOrEqualTo(l10.colorCount));
      expect(l10.colorCount, lessThanOrEqualTo(l50.colorCount));
      expect(l50.colorCount, lessThanOrEqualTo(10));
    });

    test('bos tup sayisi en az 1', () {
      for (final lvl in [1, 5, 20, 100]) {
        expect(LevelConfig.forLevel(lvl).emptyTubes, greaterThanOrEqualTo(1));
      }
    });
  });

  group('GameController', () {
    test('yeni seviye toplam top sayisini korur', () {
      final controller = GameController(startLevel: 3);
      final totalBalls =
          controller.tubes.fold<int>(0, (sum, t) => sum + t.balls.length);
      expect(totalBalls, controller.colorCount * 4);
    });

    test('gecerli hamle toplari tasiyor ve hamle sayisini artiriyor', () {
      final controller = GameController(startLevel: 1);

      // Gecerli bir (kaynak, hedef) cifti bulana kadar dene.
      int? from;
      int? to;
      for (var a = 0; a < controller.tubes.length && from == null; a++) {
        for (var b = 0; b < controller.tubes.length; b++) {
          if (controller.canPour(a, b)) {
            from = a;
            to = b;
            break;
          }
        }
      }

      expect(from, isNotNull, reason: 'Karistirilmis seviyede en az bir '
          'gecerli hamle bulunmali.');

      final beforeMoveCount = controller.moveCount;
      controller.tapTube(from!);
      controller.tapTube(to!);

      expect(controller.moveCount, beforeMoveCount + 1);
    });

    test('undo son hamleyi geri aliyor', () {
      final controller = GameController(startLevel: 1);

      int? from;
      int? to;
      for (var a = 0; a < controller.tubes.length && from == null; a++) {
        for (var b = 0; b < controller.tubes.length; b++) {
          if (controller.canPour(a, b)) {
            from = a;
            to = b;
            break;
          }
        }
      }
      expect(from, isNotNull);

      final snapshotBefore =
          controller.tubes.map((t) => List<int>.from(t.balls)).toList();

      controller.tapTube(from!);
      controller.tapTube(to!);
      expect(controller.canUndo, isTrue);

      controller.undo();

      final snapshotAfter =
          controller.tubes.map((t) => List<int>.from(t.balls)).toList();

      expect(snapshotAfter, snapshotBefore);
    });
  });
}
