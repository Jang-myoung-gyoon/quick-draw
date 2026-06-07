class FriendCommunitySnapshot {
  const FriendCommunitySnapshot({
    required this.uid,
    required this.friends,
    required this.incomingRequests,
    required this.outgoingRequests,
  });

  final String uid;
  final List<CommunityUser> friends;
  final List<CommunityUser> incomingRequests;
  final List<CommunityUser> outgoingRequests;

  factory FriendCommunitySnapshot.fromJson(Map<Object?, Object?> json) {
    return FriendCommunitySnapshot(
      uid: _readString(json['uid']) ?? '',
      friends: _readUsers(json['friends']),
      incomingRequests: _readUsers(json['incomingRequests']),
      outgoingRequests: _readUsers(json['outgoingRequests']),
    );
  }

  static List<CommunityUser> _readUsers(Object? value) {
    if (value is! Iterable) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key, value)))
        .map(CommunityUser.fromJson)
        .toList(growable: false);
  }
}

class CommunityUser {
  const CommunityUser({
    required this.uid,
    this.displayName,
    this.photoUrl,
    this.updatedAtMillis = 0,
  });

  final String uid;
  final String? displayName;
  final String? photoUrl;
  final int updatedAtMillis;

  factory CommunityUser.fromJson(Map<Object?, Object?> json) {
    return CommunityUser(
      uid: _readString(json['uid']) ?? '',
      displayName: _readString(json['displayName']),
      photoUrl: _readString(json['photoUrl']),
      updatedAtMillis: _readInt(json['updatedAtMillis']),
    );
  }

  String displayLabel({required bool isKo}) {
    final name = displayName;
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return isKo ? '익명 플레이어' : 'Anonymous Player';
  }
}

String? _readString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return 0;
}
