import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/services/firebase_game_progress_sync.dart';

void main() {
  test('anonymous display name uses a cute deterministic word pair', () {
    final name = FirebaseGameProgressSync.anonymousDisplayNameForTest(
      'anonymous-user-1',
    );

    expect(name, isNot('익명'));
    expect(name.split(' '), hasLength(2));
    expect(
      FirebaseGameProgressSync.anonymousDisplayNameForTest('anonymous-user-1'),
      name,
    );
  });
}
