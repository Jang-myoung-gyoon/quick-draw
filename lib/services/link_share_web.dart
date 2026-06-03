// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'friend_share_link.dart';

Uri currentAppUri() => Uri.parse(html.window.location.href);

Future<void> shareFriendLink(String uid) async {
  final link = FriendShareLink.build(
    currentUri: currentAppUri(),
    uid: uid,
  ).toString();
  await html.window.navigator.clipboard?.writeText(link);
}
