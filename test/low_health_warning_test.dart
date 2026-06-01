import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/main.dart';

void main() {
  test('low health warning starts at the bottom twenty percent', () {
    final game = QuickDrawGame();

    game.health = 0.21;
    expect(game.lowHealthWarningIntensity, 0.0);

    game.health = 0.2;
    expect(game.lowHealthWarningIntensity, 0.0);

    game.health = 0.1;
    expect(game.lowHealthWarningIntensity, closeTo(0.5, 0.001));

    game.health = 0.0;
    expect(game.lowHealthWarningIntensity, 1.0);
  });
}
