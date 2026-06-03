import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/services/friend_community.dart';

void main() {
  test('community snapshot parses friends and friend requests', () {
    final snapshot = FriendCommunitySnapshot.fromJson({
      'uid': 'me',
      'friends': [
        {'uid': 'friend-a', 'displayName': 'Friend A', 'updatedAtMillis': 100},
      ],
      'incomingRequests': [
        {'uid': 'requester', 'updatedAtMillis': 200},
      ],
      'outgoingRequests': [
        {'uid': 'target', 'displayName': 'Target'},
      ],
    });

    expect(snapshot.uid, 'me');
    expect(snapshot.friends.single.displayName, 'Friend A');
    expect(snapshot.incomingRequests.single.uid, 'requester');
    expect(snapshot.outgoingRequests.single.updatedAtMillis, 0);
  });
}
