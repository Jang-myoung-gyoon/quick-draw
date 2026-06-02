import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:quick_draw/components/player.dart';

void main() {
  test('freefall base position sits at two thirds of the screen height', () {
    expect(PlayerComponent.baseYForViewportHeight(1680), 1120);
    expect(PlayerComponent.baseYForViewportHeight(900), 600);
  });

  test('freefall animation draw size is ten percent larger', () {
    expect(PlayerComponent.freefallSpriteDrawSize, const Size(105.6, 187));
  });

  test('freefall animation uses a compact six frame sheet', () {
    expect(PlayerComponent.freefallFrameCount, 6);
    expect(
      PlayerComponent.freefallSourceRectForFrame(0),
      const Rect.fromLTWH(0, 0, 212, 374),
    );
    expect(
      PlayerComponent.freefallSourceRectForFrame(5),
      const Rect.fromLTWH(1060, 0, 212, 374),
    );
  });
}
