import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/services/friend_ranking.dart';

void main() {
  test('friend rankings sort score and achievement rankings separately', () {
    final me = FriendRankingEntry(
      uid: 'me',
      displayName: 'Me',
      photoUrl: 'https://example.com/me.png',
      score: 900,
      achievementScore: 300,
      stageLevel: 2,
      characterLevel: 2,
      updatedAtMillis: 100,
      isCurrentUser: true,
    );
    final scoreLeader = FriendRankingEntry(
      uid: 'score',
      displayName: 'Score',
      score: 1200,
      achievementScore: 100,
      stageLevel: 3,
      characterLevel: 2,
      updatedAtMillis: 200,
    );
    final achievementLeader = FriendRankingEntry(
      uid: 'achievement',
      displayName: 'Achievement',
      score: 700,
      achievementScore: 500,
      stageLevel: 4,
      characterLevel: 4,
      updatedAtMillis: 300,
    );

    final ranking = FriendRankingSnapshot.fromEntries([
      me,
      scoreLeader,
      achievementLeader,
    ], refreshedAtMillis: 1000);

    expect(ranking.scoreRanking.map((entry) => entry.uid), [
      'score',
      'me',
      'achievement',
    ]);
    expect(ranking.achievementRanking.map((entry) => entry.uid), [
      'achievement',
      'me',
      'score',
    ]);
    expect(ranking.currentUserScoreRank, 2);
    expect(ranking.currentUserAchievementRank, 2);
    expect(ranking.scoreRanking[1].photoUrl, 'https://example.com/me.png');
  });

  test('friend ranking refresh is blocked until twenty minutes pass', () {
    const refreshedAt = 1000;

    expect(
      FriendRankingSnapshot.canRefresh(
        refreshedAtMillis: refreshedAt,
        nowMillis:
            refreshedAt + FriendRankingSnapshot.refreshIntervalMillis - 1,
      ),
      isFalse,
    );
    expect(
      FriendRankingSnapshot.canRefresh(
        refreshedAtMillis: refreshedAt,
        nowMillis: refreshedAt + FriendRankingSnapshot.refreshIntervalMillis,
      ),
      isTrue,
    );
  });

  test('fallback snapshot marks remote unavailable and keeps current user', () {
    final fallback = FriendRankingSnapshot.localFallback(
      FriendRankingEntry(
        uid: 'me',
        displayName: 'Me',
        score: 1200,
        achievementScore: 400,
        stageLevel: 3,
        characterLevel: 2,
        updatedAtMillis: 2000,
        isCurrentUser: true,
      ),
      refreshedAtMillis: 3000,
    );

    expect(fallback.remoteUnavailable, isTrue);
    expect(fallback.scoreRanking.single.uid, 'me');
    expect(fallback.achievementRanking.single.achievementScore, 400);
    expect(fallback.currentUserScoreRank, 1);
  });
}
