import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/services/friend_share_link.dart';

void main() {
  test('builds share link with inviter uid without dropping existing path', () {
    final link = FriendShareLink.build(
      currentUri: Uri.parse('https://example.com/game/index.html?x=1'),
      uid: 'user-1',
    );

    expect(
      link.toString(),
      'https://example.com/game/index.html?friend=user-1',
    );
  });

  test('reads friend uid from share link', () {
    final uid = FriendShareLink.inviterUid(
      Uri.parse('https://example.com/?friend=user-2'),
    );

    expect(uid, 'user-2');
  });

  test('ignores blank and self friend ids', () {
    expect(
      FriendShareLink.inviterUid(Uri.parse('https://example.com/?friend=')),
      isNull,
    );
    expect(
      FriendShareLink.shouldAutoRequest(inviterUid: 'me', currentUid: 'me'),
      isFalse,
    );
  });
}
