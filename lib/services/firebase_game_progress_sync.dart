import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'friend_community.dart';
import 'friend_ranking.dart';
import 'friend_share_link.dart';
import 'game_progress_snapshot.dart';
import 'game_progress_store.dart';
import 'score_ranking_store.dart';
import 'score_record.dart';

class AnonymousAccountReplacementRequired implements Exception {
  const AnonymousAccountReplacementRequired({required this.replace});

  final Future<void> Function() replace;
}

class FirebaseGameProgressSync {
  FirebaseGameProgressSync({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    GameProgressStore store = const GameProgressStore(),
    ScoreRankingStore rankingStore = const ScoreRankingStore(),
  }) : _auth = auth,
       _functions = functions,
       _store = store,
       _rankingStore = rankingStore;

  static final FirebaseGameProgressSync instance = FirebaseGameProgressSync();

  @visibleForTesting
  static String anonymousDisplayNameForTest(String uid) =>
      _anonymousDisplayName(uid);

  FirebaseAuth? _auth;
  FirebaseFunctions? _functions;
  final GameProgressStore _store;
  final ScoreRankingStore _rankingStore;
  bool _initialized = false;

  User? get currentUser => _auth?.currentUser;
  String? get currentDisplayName => currentUser?.displayName;
  String? get currentPhotoUrl => _googlePhotoUrl(currentUser);
  bool get isGoogleUser =>
      currentUser?.providerData.any(
        (info) => info.providerId == 'google.com',
      ) ??
      false;
  bool get isAppleUser =>
      currentUser?.providerData.any((info) => info.providerId == 'apple.com') ??
      false;
  bool get isLinkedLoginUser => isGoogleUser || isAppleUser;
  bool get isAnonymousUser => currentUser != null && !isLinkedLoginUser;

  Future<void> initialize() async {
    if (!kIsWeb || _initialized) {
      return;
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    }
    _auth ??= FirebaseAuth.instance;
    _functions ??= FirebaseFunctions.instanceFor(region: 'us-central1');

    await _completeRedirectSignInIfAny();
    final user = _auth!.currentUser ?? (await _auth!.signInAnonymously()).user;
    if (user == null) {
      return;
    }
    await _ensureAnonymousDisplayName(user);
    await _saveAccountSafely(user);
    _initialized = true;

    if (!user.isAnonymous) {
      await restoreRemoteProgressToLocal();
    }
    await addInviterFromCurrentUri();
  }

  Future<void> signInWithGoogleAndSync({bool replaceAnonymous = false}) async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    await _signInOrLinkWithProvider(
      provider,
      replaceAnonymous: replaceAnonymous,
    );
  }

  Future<void> signInWithAppleAndSync({bool replaceAnonymous = false}) async {
    final provider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    await _signInOrLinkWithProvider(
      provider,
      replaceAnonymous: replaceAnonymous,
    );
  }

  Future<void> _signInOrLinkWithProvider(
    AuthProvider provider, {
    required bool replaceAnonymous,
  }) async {
    await initialize();
    final auth = _auth;
    if (!kIsWeb || auth == null) {
      return;
    }
    final current = auth.currentUser;
    UserCredential credential;

    if (current != null && current.isAnonymous && replaceAnonymous) {
      await _discardAnonymousUser(current, auth);
      credential = await auth.signInWithPopup(provider);
    } else if (current != null) {
      try {
        credential = await current.linkWithPopup(provider);
      } on FirebaseAuthException catch (error) {
        final pendingCredential = error.credential;
        final isDifferentAccount =
            error.code == 'credential-already-in-use' ||
            error.code == 'account-exists-with-different-credential';
        if (current.isAnonymous && isDifferentAccount) {
          throw AnonymousAccountReplacementRequired(
            replace: pendingCredential == null
                ? () => _replaceAnonymousWithProvider(current, auth, provider)
                : () => _replaceAnonymousWithCredential(
                    current,
                    auth,
                    pendingCredential,
                  ),
          );
        }
        rethrow;
      }
    } else {
      credential = await auth.signInWithPopup(provider);
    }
    final user = credential.user;
    if (user != null) {
      await _preferGoogleProfile(user);
      await _mergeSignedInUserProgress(user);
      await addInviterFromCurrentUri();
    }
  }

  Future<void> _discardAnonymousUser(User user, FirebaseAuth auth) async {
    try {
      await user.delete();
    } on FirebaseAuthException {
      await auth.signOut();
    }
  }

  Future<void> _replaceAnonymousWithCredential(
    User anonymousUser,
    FirebaseAuth auth,
    AuthCredential credential,
  ) async {
    await _discardAnonymousUser(anonymousUser, auth);
    final result = await auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) {
      return;
    }
    await _preferGoogleProfile(user);
    await _mergeSignedInUserProgress(user);
    await addInviterFromCurrentUri();
  }

  Future<void> _replaceAnonymousWithProvider(
    User anonymousUser,
    FirebaseAuth auth,
    AuthProvider provider,
  ) async {
    await _discardAnonymousUser(anonymousUser, auth);
    final result = await auth.signInWithPopup(provider);
    final user = result.user;
    if (user == null) {
      return;
    }
    await _preferGoogleProfile(user);
    await _mergeSignedInUserProgress(user);
    await addInviterFromCurrentUri();
  }

  Future<void> unlinkLoginProviders() async {
    await initialize();
    var user = currentUser;
    if (!kIsWeb || user == null) {
      return;
    }
    for (final providerId in ['google.com', 'apple.com']) {
      final hasProvider =
          user?.providerData.any((info) => info.providerId == providerId) ??
          false;
      if (!hasProvider) {
        continue;
      }
      try {
        await user!.unlink(providerId);
        await user.reload();
        user = currentUser;
      } on FirebaseAuthException {
        // Keep the current signed-in account if unlinking is rejected.
      }
    }
    user = currentUser;
    if (user != null) {
      await _ensureAnonymousDisplayName(user);
      await _saveAccount(user);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    await initialize();
    final user = currentUser;
    final nextName = _normalizeDisplayName(displayName);
    if (user == null || nextName == null) {
      return;
    }
    await user.updateDisplayName(nextName);
    await user.reload();
    await _callFunction('updateDisplayName', {
      'displayName': nextName,
      'photoUrl': currentPhotoUrl,
    });
  }

  Future<void> restoreRemoteProgressToLocal() async {
    final user = currentUser;
    if (user == null || user.isAnonymous) {
      return;
    }
    final remote = await _loadRemoteProgressSafely(user.uid);
    if (remote != null) {
      final local = await _store.loadLocal();
      await _store.saveLocal(local.merge(remote));
    }
  }

  Future<void> saveProgress(GameProgressSnapshot progress) async {
    await _store.saveLocal(progress);
    final user = currentUser;
    if (user == null || user.isAnonymous) {
      return;
    }
    await _saveRemoteProgressSafely(progress, uid: user.uid);
  }

  Future<void> recordScore(
    ScoreRecord score, {
    int achievementScore = 0,
  }) async {
    await _rankingStore.recordLocalScore(score);
    final user = currentUser;
    if (user == null) {
      return;
    }
    final record = ScoreRecord(
      score: score.score,
      stageLevel: score.stageLevel,
      characterLevel: score.characterLevel,
      playedAtMillis: score.playedAtMillis,
      playerName: user.displayName,
      uid: user.uid,
    );
    await _saveScoreRecordSafely(record, achievementScore: achievementScore);
  }

  Future<FriendRankingSnapshot> loadFriendRankingSnapshot({
    bool forceRefresh = false,
  }) async {
    await initialize();
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final cached = await _rankingStore.loadFriendRankingCache();
    if (!forceRefresh && cached != null && !cached.canRefreshAt(nowMillis)) {
      return cached;
    }

    final remote = await _loadFriendRankingFromRemoteSafely(nowMillis);
    if (remote != null) {
      await _rankingStore.saveFriendRankingCache(remote);
      return remote;
    }
    if (cached != null) {
      return FriendRankingSnapshot.fromEntries(
        cached.scoreRanking,
        refreshedAtMillis: cached.refreshedAtMillis,
        remoteUnavailable: true,
      );
    }
    return FriendRankingSnapshot.localFallback(
      await _currentUserRankingEntry(nowMillis),
      refreshedAtMillis: nowMillis,
    );
  }

  Future<FriendCommunitySnapshot> loadCommunitySnapshot() async {
    await initialize();
    final user = currentUser;
    if (user == null) {
      return const FriendCommunitySnapshot(
        uid: '',
        friends: [],
        incomingRequests: [],
        outgoingRequests: [],
      );
    }
    final data = await _callFunction('loadCommunity', const {});
    return FriendCommunitySnapshot.fromJson({
      ...data,
      'uid': data['uid'] ?? user.uid,
    });
  }

  Future<void> sendFriendRequest(String friendUid) async {
    await initialize();
    final user = currentUser;
    final targetUid = friendUid.trim();
    if (user == null || targetUid.isEmpty || targetUid == user.uid) {
      return;
    }
    await _callFunction('sendFriendRequest', {'friendUid': targetUid});
  }

  Future<bool> acceptFriendRequest(String requesterUid) async {
    await initialize();
    final user = currentUser;
    final targetUid = requesterUid.trim();
    if (user == null || targetUid.isEmpty || targetUid == user.uid) {
      return false;
    }
    final data = await _callFunction('acceptFriendRequest', {
      'requesterUid': targetUid,
    });
    return data['ok'] == true;
  }

  Future<void> addInviterFromCurrentUri() async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    final inviterUid = FriendShareLink.inviterUid(Uri.base);
    if (!FriendShareLink.shouldAutoRequest(
      inviterUid: inviterUid,
      currentUid: user.uid,
    )) {
      return;
    }
    await sendFriendRequest(inviterUid!);
  }

  Future<GameProgressSnapshot?> loadRemoteProgress(String uid) async {
    final user = currentUser;
    if (user == null || uid != user.uid) {
      return null;
    }
    final data = await _callFunction('loadProgress', const {});
    final value = _readMap(data['progress']);
    if (value != null) {
      return GameProgressSnapshot.fromJson(value);
    }
    return null;
  }

  Future<void> saveRemoteProgress(
    GameProgressSnapshot progress, {
    required String uid,
  }) async {
    final user = currentUser;
    if (user == null || uid != user.uid) {
      return;
    }
    await _callFunction('saveProgress', {
      'progress': progress.toJson(),
      'displayName': user.displayName,
      'photoUrl': currentPhotoUrl,
    });
  }

  Future<void> _saveAccount(User user) {
    return _store.saveAccount(
      uid: user.uid,
      provider: user.isAnonymous ? 'anonymous' : 'google',
    );
  }

  Future<void> _saveAccountSafely(User user) async {
    try {
      await _saveAccount(user);
    } catch (_) {
      // Account persistence is a cache; Firebase Auth remains the source of truth.
    }
  }

  Future<void> _completeRedirectSignInIfAny() async {
    final auth = _auth;
    if (auth == null) {
      return;
    }
    try {
      final credential = await auth.getRedirectResult();
      final user = credential.user;
      if (user == null) {
        return;
      }
      await _mergeSignedInUserProgress(user);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'no-auth-event') {
        return;
      }
      rethrow;
    } catch (_) {
      // Popup sign-in is the active auth flow. A stale or malformed redirect
      // result must not block creation of the anonymous community account.
    }
  }

  Future<void> _mergeSignedInUserProgress(User user) async {
    await _saveAccount(user);
    if (user.isAnonymous) {
      return;
    }
    final local = await _store.loadLocal();
    final remote = await _loadRemoteProgressSafely(user.uid);
    final merged = remote == null ? local : local.merge(remote);
    await _store.saveLocal(merged);
    await _saveRemoteProgressSafely(merged, uid: user.uid);
  }

  Future<void> _preferGoogleProfile(User user) async {
    if (user.isAnonymous) {
      return;
    }
    for (final info in user.providerData) {
      if (info.providerId != 'google.com') {
        continue;
      }
      final googleName = _normalizeDisplayName(info.displayName);
      final googlePhotoUrl = _normalizeUrl(info.photoURL);
      try {
        if (googleName != null && user.displayName != googleName) {
          await user.updateDisplayName(googleName);
        }
        if (googlePhotoUrl != null && user.photoURL != googlePhotoUrl) {
          await user.updatePhotoURL(googlePhotoUrl);
        }
        if (googleName != null || googlePhotoUrl != null) {
          await user.reload();
        }
      } catch (_) {
        // A stale Google profile should not block Google sign-in.
      }
      return;
    }
  }

  Future<void> _ensureAnonymousDisplayName(User user) async {
    if (!user.isAnonymous || user.displayName?.trim().isNotEmpty == true) {
      return;
    }
    try {
      await user.updateDisplayName(_anonymousDisplayName(user.uid));
      await user.reload();
    } catch (_) {
      // A missing anonymous display name should not block local play.
    }
  }

  static String _anonymousDisplayName(String uid) {
    const adjectives = [
      '몽실한',
      '보송한',
      '달콤한',
      '말랑한',
      '반짝이는',
      '포근한',
      '깡총대는',
      '새침한',
      '용감한',
      '졸린',
    ];
    const nouns = [
      '토끼',
      '당근',
      '솜방울',
      '달토끼',
      '풀잎',
      '구름',
      '별조각',
      '찹쌀떡',
      '민들레',
      '리본',
    ];
    final hash = uid.codeUnits.fold<int>(
      0,
      (value, unit) => (value * 31 + unit) & 0x7fffffff,
    );
    return '${adjectives[hash % adjectives.length]} '
        '${nouns[(hash ~/ adjectives.length) % nouns.length]}';
  }

  static String? _normalizeDisplayName(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length <= 24) {
      return trimmed;
    }
    return trimmed.substring(0, 24);
  }

  static String? _normalizeUrl(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _googlePhotoUrl(User? user) {
    if (user == null) {
      return null;
    }
    final hasGoogleProvider = user.providerData.any(
      (info) => info.providerId == 'google.com',
    );
    if (!hasGoogleProvider) {
      return null;
    }
    return _normalizeUrl(user.photoURL);
  }

  Future<GameProgressSnapshot?> _loadRemoteProgressSafely(String uid) async {
    try {
      return await loadRemoteProgress(uid);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveRemoteProgressSafely(
    GameProgressSnapshot progress, {
    required String uid,
  }) async {
    try {
      await saveRemoteProgress(progress, uid: uid);
    } catch (_) {
      // Local progress is already saved; remote sync can retry on next change.
    }
  }

  Future<void> _saveScoreRecordSafely(
    ScoreRecord record, {
    required int achievementScore,
  }) async {
    try {
      final uid = record.uid;
      if (uid == null) {
        return;
      }
      await _callFunction('recordScore', {
        'record': record.toJson(),
        'achievementScore': achievementScore,
        'displayName': record.playerName,
        'photoUrl': currentPhotoUrl,
      });
    } catch (_) {
      // Local score history remains available if remote ranking is unavailable.
    }
  }

  Future<FriendRankingSnapshot?> _loadFriendRankingFromRemoteSafely(
    int nowMillis,
  ) async {
    final user = currentUser;
    if (user == null) {
      return null;
    }
    try {
      final data = await _callFunction('loadFriendRanking', const {});
      final entriesValue = data['entries'];
      final entries = entriesValue is Iterable
          ? entriesValue
                .map(_readMap)
                .nonNulls
                .map(FriendRankingEntry.fromJson)
                .toList(growable: false)
          : const <FriendRankingEntry>[];
      return FriendRankingSnapshot.fromEntries(
        entries,
        refreshedAtMillis: _readInt(
          data['refreshedAtMillis'],
          fallback: nowMillis,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<FriendRankingEntry> _currentUserRankingEntry(int nowMillis) async {
    final user = currentUser;
    final progress = await _store.loadLocal();
    final localScores = await _rankingStore.loadLocalScores();
    final bestLocalScore = localScores.isEmpty ? null : localScores.first;
    return FriendRankingEntry(
      uid: user?.uid ?? 'local',
      displayName: user?.displayName,
      photoUrl: currentPhotoUrl,
      score: bestLocalScore?.score ?? progress.bestScore,
      achievementScore: _achievementScore(progress),
      stageLevel: bestLocalScore?.stageLevel ?? progress.bestStageLevel,
      characterLevel:
          bestLocalScore?.characterLevel ?? progress.bestCharacterLevel,
      updatedAtMillis: bestLocalScore?.playedAtMillis ?? nowMillis,
      isCurrentUser: true,
    );
  }

  int _achievementScore(GameProgressSnapshot progress) {
    return progress.acknowledgedAchievements.length * 100 +
        progress.selectedUpgrades.length * 100 +
        progress.maxedUpgrades.length * 100 +
        (progress.bestStageLevel - 1).clamp(0, 9999) * 20 +
        (progress.bestCharacterLevel - 1).clamp(0, 9999) * 20;
  }

  int _readInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return fallback;
  }

  Future<Map<Object?, Object?>> _callFunction(
    String name,
    Map<String, Object?> data,
  ) async {
    final functions = _functions;
    if (functions == null) {
      return const {};
    }
    final result = await functions.httpsCallable(name).call<Object?>(data);
    return _readMap(result.data) ?? const {};
  }

  Map<Object?, Object?>? _readMap(Object? value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key, value));
    }
    return null;
  }
}
