enum AchievementGroup { upgrade, stage, character, score }

class Achievement {
  final String id;
  final String title;
  final String description;
  final AchievementGroup group;
  final bool unlocked;
  final bool acknowledged;
  final double progress;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.group,
    required this.unlocked,
    this.acknowledged = false,
    required this.progress,
  });
}
