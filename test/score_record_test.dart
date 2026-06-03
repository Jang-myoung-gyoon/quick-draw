import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/services/score_record.dart';
import 'package:quick_draw/services/score_ranking_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('score records sort highest score first then newest first', () {
    final olderHigh = ScoreRecord(
      score: 1000,
      stageLevel: 2,
      characterLevel: 3,
      playedAtMillis: 100,
    );
    final newerHigh = ScoreRecord(
      score: 1000,
      stageLevel: 2,
      characterLevel: 3,
      playedAtMillis: 200,
    );
    final lower = ScoreRecord(
      score: 500,
      stageLevel: 1,
      characterLevel: 1,
      playedAtMillis: 300,
    );

    final records = ScoreRecord.sorted([olderHigh, lower, newerHigh]);

    expect(records, [newerHigh, olderHigh, lower]);
  });

  test('score records round trip through json', () {
    final record = ScoreRecord(
      score: 2400,
      stageLevel: 7,
      characterLevel: 4,
      playedAtMillis: 123456789,
      playerName: 'Player',
      uid: 'uid-1',
    );

    expect(ScoreRecord.fromJson(record.toJson()), record);
  });

  test('local score records persist in ranking order', () async {
    SharedPreferences.setMockInitialValues({});
    const store = ScoreRankingStore();

    await store.recordLocalScore(
      const ScoreRecord(
        score: 100,
        stageLevel: 1,
        characterLevel: 1,
        playedAtMillis: 100,
      ),
    );
    await store.recordLocalScore(
      const ScoreRecord(
        score: 300,
        stageLevel: 2,
        characterLevel: 2,
        playedAtMillis: 200,
      ),
    );

    final records = await store.loadLocalScores();

    expect(records.map((record) => record.score), [300, 100]);
  });
}
