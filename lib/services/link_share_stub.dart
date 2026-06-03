import 'friend_share_link.dart';

Uri currentAppUri() => Uri.base;

Future<void> shareFriendLink(String uid) async {
  FriendShareLink.build(currentUri: currentAppUri(), uid: uid);
}
