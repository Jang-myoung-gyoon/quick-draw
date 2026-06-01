import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/main.dart';

void main() {
  test('energy recharge is based on upward screen scroll distance', () {
    final game = QuickDrawGame();

    expect(game.energyRechargeForScroll(0, 680), 0.0);
    expect(game.energyRechargeForScroll(340, 680), closeTo(0.0875, 0.001));
    expect(game.energyRechargeForScroll(680, 680), closeTo(0.15, 0.001));
  });
}
