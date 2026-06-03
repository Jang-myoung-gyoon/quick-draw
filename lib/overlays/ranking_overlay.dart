import 'package:flutter/material.dart';

import '../game/quick_draw_game.dart';
import '../services/friend_ranking.dart';

enum _RankingTab { score, achievement }

class RankingOverlay extends StatefulWidget {
  const RankingOverlay({super.key, required this.game});

  final QuickDrawGame game;

  @override
  State<RankingOverlay> createState() => _RankingOverlayState();
}

class _RankingOverlayState extends State<RankingOverlay> {
  Future<FriendRankingSnapshot>? _rankingLoad;
  _RankingTab _tab = _RankingTab.score;

  @override
  void initState() {
    super.initState();
    _rankingLoad = widget.game.loadFriendRankingSnapshot();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final t = game.text;
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.ranking,
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: Color(0xFF00FFCC),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('ranking-close-button'),
                        tooltip: t.close,
                        onPressed: game.hideRanking,
                        icon: const Icon(Icons.close),
                        iconSize: 30,
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          fixedSize: const Size(52, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TabButton(
                          label: t.scoreRanking,
                          selected: _tab == _RankingTab.score,
                          onPressed: () {
                            setState(() {
                              _tab = _RankingTab.score;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TabButton(
                          label: t.achievementRanking,
                          selected: _tab == _RankingTab.achievement,
                          onPressed: () {
                            setState(() {
                              _tab = _RankingTab.achievement;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        key: const ValueKey('ranking-refresh-button'),
                        tooltip: t.refresh,
                        onPressed: () {
                          setState(() {
                            _rankingLoad = game.loadFriendRankingSnapshot();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        color: const Color(0xFF00FFCC),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF101522,
                          ).withValues(alpha: 0.86),
                          fixedSize: const Size(52, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.refreshLimited,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: FutureBuilder<FriendRankingSnapshot>(
                      future: _rankingLoad,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF00FFCC),
                            ),
                          );
                        }
                        final ranking = snapshot.data;
                        if (ranking == null ||
                            ranking.scoreRanking.isEmpty &&
                                ranking.achievementRanking.isEmpty) {
                          return Center(
                            child: Text(
                              t.noRankingRecords,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }
                        final records = _tab == _RankingTab.score
                            ? ranking.scoreRanking
                            : ranking.achievementRanking;
                        final myRank = _tab == _RankingTab.score
                            ? ranking.currentUserScoreRank
                            : ranking.currentUserAchievementRank;
                        return Column(
                          children: [
                            if (ranking.remoteUnavailable) ...[
                              _ServerUnavailableBanner(
                                message: t.rankingServerUnavailable,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (myRank != null) ...[
                              _CurrentRankBanner(
                                rank: myRank,
                                label: _tab == _RankingTab.score
                                    ? t.scoreRanking
                                    : t.achievementRanking,
                              ),
                              const SizedBox(height: 12),
                            ],
                            Expanded(
                              child: ListView.separated(
                                itemCount: records.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  return _RankingRow(
                                    game: game,
                                    rank: index + 1,
                                    record: records[index],
                                    metric: _tab,
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? const Color(0xFF00FFCC)
              : const Color(0xFF101522).withValues(alpha: 0.86),
          foregroundColor: selected ? Colors.black : Colors.white,
          side: BorderSide(
            color: selected
                ? const Color(0xFF00FFCC)
                : Colors.white.withValues(alpha: 0.16),
            width: 2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _ServerUnavailableBanner extends StatelessWidget {
  const _ServerUnavailableBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF2D55).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF2D55).withValues(alpha: 0.34),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFFF6B8A),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CurrentRankBanner extends StatelessWidget {
  const _CurrentRankBanner({required this.rank, required this.label});

  final int rank;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF00FFCC).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF00FFCC).withValues(alpha: 0.34),
        ),
      ),
      child: Text(
        '$label #$rank',
        style: const TextStyle(
          color: Color(0xFF00FFCC),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.game,
    required this.rank,
    required this.record,
    required this.metric,
  });

  final QuickDrawGame game;
  final int rank;
  final FriendRankingEntry record;
  final _RankingTab metric;

  @override
  Widget build(BuildContext context) {
    final t = game.text;
    final accent = record.isCurrentUser
        ? const Color(0xFF00FFCC)
        : rank <= 3
        ? const Color(0xFFFFD166)
        : const Color(0xFF38BDF8);
    final metricValue = metric == _RankingTab.score
        ? record.score
        : record.achievementScore;
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF101522).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: accent,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  record.displayName ?? (t.isKo ? '익명 플레이어' : 'Anonymous'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${t.stageLevel} ${record.stageLevel}  ${t.characterLevel} ${record.characterLevel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$metricValue',
            style: TextStyle(
              color: accent,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
