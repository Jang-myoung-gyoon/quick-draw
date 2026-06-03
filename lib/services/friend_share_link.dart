class FriendShareLink {
  static const String queryKey = 'friend';

  static Uri build({required Uri currentUri, required String uid}) {
    return currentUri.replace(queryParameters: {queryKey: uid});
  }

  static String? inviterUid(Uri uri) {
    final value = uri.queryParameters[queryKey]?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static bool shouldAutoRequest({
    required String? inviterUid,
    required String? currentUid,
  }) {
    return inviterUid != null &&
        inviterUid.isNotEmpty &&
        currentUid != null &&
        currentUid.isNotEmpty &&
        inviterUid != currentUid;
  }
}
