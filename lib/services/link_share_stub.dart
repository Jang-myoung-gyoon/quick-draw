import 'friend_share_link.dart';

Uri currentAppUri() => Uri.base;

String friendInviteLink(String uid) =>
    FriendShareLink.build(currentUri: currentAppUri(), uid: uid).toString();

String plainAppLink() =>
    currentAppUri().replace(queryParameters: {}).toString();
