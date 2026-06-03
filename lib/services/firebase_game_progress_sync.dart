import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'friend_ranking.dart';
import 'friend_share_link.dart';
import 'game_progress_snapshot.dart';
import 'game_progress_store.dart';
import 'score_ranking_store.dart';
import 'score_record.dart';

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

  FirebaseAuth? _auth;
  FirebaseFunctions? _functions;
  final GameProgressStore _store;
  final ScoreRankingStore _rankingStore;
  bool _initialized = false;

  User? get currentUser => _auth?.currentUser;
  bool get isGoogleUser =>
      currentUser?.providerData.any(
        (info) => info.providerId == 'google.com',
      ) ??
      false;

  Future<void> initialize() async {
    if (!kIsWeb || _initialized) {
      return;
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    }
    _auth ??= FirebaseAuth.instance;
    _functions ??= FirebaseFunctions.instanceFor(region: 'us-central1');

    final user = _auth!.currentUser ?? (await _auth!.signInAnonymously()).user;
    if (user == null) {
      return;
    }
    await _saveAccount(user);
    _initialized = true;

    if (!user.isAnonymous) {
      await restoreRemoteProgressToLocal();
    }
    await addInviterFromCurrentUri();
  }

  Future<void> signInWithGoogleAndSync() async {
    await initialize();
    final auth = _auth;
    if (!kIsWeb || auth == null) {
      return;
    }

    final localBeforeSignIn = await _store.loadLocal();
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    UserCredential credential;
    final current = auth.currentUser;

    if (current != null && current.isAnonymous) {
      try {
        credential = await current.linkWithPopup(provider);
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use' &&
            error.code != 'provider-already-linked' &&
            error.code != 'email-already-in-use') {
          rethrow;
        }
        credential = await auth.signInWithPopup(provider);
      }
    } else {
      credential = await auth.signInWithPopup(provider);
    }

    final user = credential.user;
    if (user == null) {
      return;
    }
    await _saveAccount(user);

    final remote = await _loadRemoteProgressSafely(user.uid);
    final merged = remote == null
        ? localBeforeSignIn
        : localBeforeSignIn.merge(remote);
    await _store.saveLocal(merged);
    await _saveRemoteProgressSafely(merged, uid: user.uid);
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

  Future<void> addFriend(String friendUid) async {
    await initialize();
    final user = currentUser;
    final targetUid = friendUid.trim();
    if (user == null || targetUid.isEmpty || targetUid == user.uid) {
      return;
    }
    await _callFunction('addFriend', {'friendUid': targetUid});
    final snapshot = await _loadFriendRankingFromRemoteSafely(
      DateTime.now().millisecondsSinceEpoch,
    );
    if (snapshot != null) {
      await _rankingStore.saveFriendRankingCache(snapshot);
    }
  }

  Future<void> addInviterFromCurrentUri() async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    final inviterUid = FriendShareLink.inviterUid(Uri.base);
    if (!FriendShareLink.shouldAutoAdd(
      inviterUid: inviterUid,
      currentUid: user.uid,
    )) {
      return;
    }
    await addFriend(inviterUid!);
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
    });
  }

  Future<void> _saveAccount(User user) {
    return _store.saveAccount(
      uid: user.uid,
      provider: user.isAnonymous ? 'anonymous' : 'google',
    );
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
