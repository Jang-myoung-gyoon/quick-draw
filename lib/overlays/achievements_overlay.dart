import 'package:flutter/material.dart';
import '../game/quick_draw_game.dart';

class AchievementsOverlay extends StatelessWidget {
  final QuickDrawGame game;
  const AchievementsOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.achievementRevision,
      builder: (context, revision, child) {
        final achievements = game.achievementsForDisplay();
        final visibleAchievements = QuickDrawGame.visibleAchievementsFrom(
          achievements,
        );
        return _buildContent(context, achievements, visibleAchievements);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Achievement> achievements,
    List<Achievement> visibleAchievements,
  ) {
    final unlockedCount = achievements
        .where((achievement) => achievement.unlocked)
        .length;
    final t = game.text;
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 54),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.achievements,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: Color(0xFFA29BFE),
                      ),
                    ),
                  ),
                  Text(
                    '$unlockedCount / ${achievements.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00FFCC),
                    ),
                  ),
                  const SizedBox(width: 18),
                  IconButton(
                    onPressed: game.hideAchievements,
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                    tooltip: t.close,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _AchievementSection(
                        title: t.upgrades,
                        achievements: achievementsByGroup(
                          visibleAchievements,
                          AchievementGroup.upgrade,
                        ),
                      ),
                      _AchievementSection(
                        title: t.stageLevel,
                        achievements: achievementsByGroup(
                          visibleAchievements,
                          AchievementGroup.stage,
                        ),
                      ),
                      _AchievementSection(
                        title: t.characterLevel,
                        achievements: achievementsByGroup(
                          visibleAchievements,
                          AchievementGroup.character,
                        ),
                      ),
                      _AchievementSection(
                        title: t.score,
                        achievements: achievementsByGroup(
                          visibleAchievements,
                          AchievementGroup.score,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<Achievement> achievementsByGroup(
    List<Achievement> achievements,
    AchievementGroup group,
  ) {
    return achievements
        .where((achievement) => achievement.group == group)
        .toList(growable: false);
  }
}

class _AchievementSection extends StatelessWidget {
  final String title;
  final List<Achievement> achievements;

  const _AchievementSection({required this.title, required this.achievements});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: Color(0xFF00FFCC),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final achievement in achievements)
                _AchievementTile(achievement: achievement),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;

  const _AchievementTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final accent = unlocked
        ? const Color(0xFFFFD166)
        : Colors.white.withValues(alpha: 0.28);
    return SizedBox(
      width: 220,
      height: 116,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: unlocked
              ? const Color(0xFF161A2A).withValues(alpha: 0.94)
              : const Color(0xFF101322).withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.75), width: 1.4),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    unlocked ? Icons.emoji_events : Icons.lock_outline,
                    size: 18,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      achievement.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: unlocked
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.56),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  achievement.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: Colors.white.withValues(alpha: 0.54),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: achievement.progress.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
