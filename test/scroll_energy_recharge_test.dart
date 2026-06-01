import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/game/quick_draw_game.dart';

void main() {
  test('energy recharge is based on upward screen scroll distance', () {
    final game = QuickDrawGame();

    expect(game.energyRechargeForScroll(0, 680), 0.0);
    expect(game.energyRechargeForScroll(340, 680), closeTo(0.06125, 0.001));
    expect(game.energyRechargeForScroll(680, 680), closeTo(0.105, 0.001));
  });

  test(
    'downward screen scroll drains the same amount upward scroll restores',
    () {
      final game = QuickDrawGame()..health = 0.5;
      final scrollAmount = game.energyRechargeForScroll(340, 680);

      game.rechargeEnergyFromScroll(340, referenceHeight: 680);
      expect(game.health, closeTo(0.5 + scrollAmount, 0.001));

      game.drainEnergyFromScroll(340, referenceHeight: 680);
      expect(game.health, closeTo(0.5, 0.001));
    },
  );

  test('downward screen scroll cannot drain the hidden energy reserve', () {
    final game = QuickDrawGame()..health = 0.04;

    game.drainEnergyFromScroll(680, referenceHeight: 680);

    expect(game.health, QuickDrawGame.hiddenEnergyReserve);
    expect(game.displayedEnergy, 0.0);
  });
}
