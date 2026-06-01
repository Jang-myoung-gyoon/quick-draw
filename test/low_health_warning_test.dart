import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:quick_draw/main.dart';

void main() {
  test('displayed energy hides the ten percent survival reserve', () {
    final game = QuickDrawGame();

    game.health = 1.1;
    expect(game.displayedEnergy, 1.0);

    game.health = 0.1;
    expect(game.displayedEnergy, 0.0);
  });

  test('low health warning starts at the bottom thirty percent', () {
    final game = QuickDrawGame();

    game.health = 0.41;
    expect(game.lowHealthWarningIntensity, 0.0);

    game.health = 0.4;
    expect(game.lowHealthWarningIntensity, closeTo(0.15, 0.001));

    game.health = 0.25;
    expect(game.lowHealthWarningIntensity, closeTo(0.575, 0.001));

    game.health = 0.1;
    expect(game.lowHealthWarningIntensity, 1.0);
  });

  testWidgets('hud renders the low energy edge warning when energy is low', (
    tester,
  ) async {
    final game = QuickDrawGame()..health = 0.3;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 800,
          child: Stack(children: [HUDOverlay(game: game)]),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('low-energy-warning')), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('hud hides the low energy edge warning when energy is safe', (
    tester,
  ) async {
    final game = QuickDrawGame()..health = 0.8;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 800,
          child: Stack(children: [HUDOverlay(game: game)]),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('low-energy-warning')), findsNothing);
    expect(
      find.byKey(const ValueKey('low-energy-warning-off')),
      findsOneWidget,
    );
    expect(find.text(game.text.score), findsOneWidget);
    expect(find.text(game.text.energy), findsOneWidget);
    final passiveLayerSize = tester.getSize(
      find.byKey(const ValueKey('hud-passive-layer')),
    );
    expect(passiveLayerSize.width, greaterThan(0));
    expect(passiveLayerSize.height, greaterThan(0));
  });
}
