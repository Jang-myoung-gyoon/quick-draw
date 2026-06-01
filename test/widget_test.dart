import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/main.dart';
import 'package:quick_draw/game/quick_draw_game.dart';

void main() {
  testWidgets('Flame game loads and mounts successfully', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyGameApp());
    await tester.pump();

    // Verify that the GameWidget is present in the tree.
    expect(find.byType(GameWidget<QuickDrawGame>), findsOneWidget);
  });
}
