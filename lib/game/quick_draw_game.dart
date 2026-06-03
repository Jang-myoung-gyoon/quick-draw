import 'dart:async' as async_timer;
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/background.dart';
import '../components/effects.dart';
import '../components/player.dart';
import '../components/target.dart';
import '../audio/html_audio_stub.dart'
    if (dart.library.html) '../audio/html_audio_web.dart'
    as html_audio;

import '../models/upgrade.dart';
import '../models/achievement.dart';
import '../models/game_text.dart';
import '../models/audio.dart';
import '../services/firebase_game_progress_sync.dart';
import '../services/friend_community.dart';
import '../services/friend_ranking.dart';
import '../services/game_progress_snapshot.dart';
import '../services/game_progress_store.dart';
import '../services/link_share_stub.dart'
    if (dart.library.html) '../services/link_share_web.dart'
    as link_share;
import '../services/score_record.dart';

export '../models/upgrade.dart';
export '../models/achievement.dart';
export '../models/game_text.dart';
export '../models/audio.dart';

part 'quick_draw_game_input.dart';
part 'quick_draw_game_upgrades.dart';
part 'quick_draw_game_camera.dart';
part 'quick_draw_game_spawning.dart';
part 'quick_draw_game_shards.dart';
part 'quick_draw_game_audio.dart';
part 'quick_draw_game_achievements.dart';
part 'quick_draw_game_tutorial.dart';

enum TutorialPhase {
  inactive,
  firstSlash,
  upgradeChoice,
  chainedSlash,
  ultimateSlash,
}

class QuickDrawGame extends FlameGame with KeyboardEvents, TapCallbacks {
  QuickDrawGame({
    GameProgressStore progressStore = const GameProgressStore(),
    FirebaseGameProgressSync? firebaseSync,
  }) : _progressStore = progressStore,
       _firebaseSync = firebaseSync ?? FirebaseGameProgressSync.instance;

  final GameProgressStore _progressStore;
  final FirebaseGameProgressSync _firebaseSync;
  static const double initialPassiveDrainRate = 0.06435;
  static const int earlyDrainBonusFadeOutStage = 20;
  static const Duration bonusCollectSoundDelay = Duration(milliseconds: 500);

  FallingBackground? background;
  late PlayerComponent player;

  // Game states
  bool isPlaying = false;
  bool isGameOver = false;
  bool isChoosingUpgrade = false;
  double _gameOverDelayTimer = 0.0;
  int score = 0;
  int combo = 0;

  // Health Gauge (0.0 to 1.0)
  double health = 1.1;
  static const double hiddenEnergyReserve = 0.1;
  final double maxHealth = 1.0 + hiddenEnergyReserve;
  double passiveDrainRate = initialPassiveDrainRate;

  // Experience Gauge (0.0 to 1.0)
  double experience = 0.0;
  double get maxExperience => 1.0;
  int characterLevel = 1;
  int stageLevel = 1;
  int levelUpAnnouncementLevel = 1;
  String levelUpAnnouncementTitle = 'CHARACTER LEVEL UP';
  double levelUpAnnouncementTimer = 0.0;
  int inputTurnsThisStage = 0;
  int playerAttackPower = 1;
  int criticalStrikeLevel = 0;
  double scrollEnergyGainMultiplier = 1.0;
  int luckLevel = 0;
  int rareUpgradeCount = 0;
  int shadowCloneLevel = 0;
  bool shieldUnlocked = false;
  int shieldCharges = 0;
  bool lightfootGaugeUnlocked = false;
  double lightfootGauge = 0.0;
  bool chainStrikeUnlocked = false;
  List<UpgradeOption> currentUpgradeChoices = const [];
  double upgradeInputLockTimer = 0.0;
  final List<UpgradeType> acquiredRareUpgrades = [];
  int bestStageLevel = 1;
  int bestCharacterLevel = 1;
  int bestScore = 0;
  final Set<UpgradeType> selectedUpgradeAchievements = {};
  final Set<UpgradeType> maxedUpgradeAchievements = {};
  final Set<String> acknowledgedAchievementIds = {};
  final Set<String> _announcedAchievementIds = {'stage-1', 'character-1'};
  final List<String> _achievementToastQueue = [];
  final ValueNotifier<int> achievementRevision = ValueNotifier<int>(0);
  String? achievementToastMessage;
  double achievementToastTimer = 0.0;
  bool _achievementProgressLoaded = false;
  bool _tutorialCompleted = false;
  bool _tutorialProgressLoaded = false;
  TutorialPhase _tutorialPhase = TutorialPhase.inactive;
  bool _tutorialChainTargetsPrepared = false;
  bool _tutorialBonusTargetPrepared = false;
  bool _tutorialBonusTargetCollected = false;
  bool _tutorialScorePenaltyActive = false;
  Future<void>? _achievementProgressLoad;
  Future<void>? _scoreRecordSave;
  int _pendingExperienceHits = 0;
  final List<Vector2> _pendingLaserAttackOrigins = [];
  int _spawnsSinceLastBonus = 0;
  bool _pausedForSettings = false;
  bool soundEnabled = true;
  GameLanguage language = GameLanguage.ko;
  GameText get text => GameText(language);
  bool get isGameplayPausedForUi => isChoosingUpgrade || paused;
  bool get isGameOverPending => _gameOverDelayTimer > 0;
  bool get isUltimateProtectionActive {
    try {
      return player.isUltimateProtectionActive;
    } catch (_) {
      return false;
    }
  }

  // Chain variables (now using raw screen coordinates instead of targets)
  final List<Vector2> currentChainPoints = [];
  SlashPathLine? activePathLine;
  double chainTimer = 0.0;
  double maxChainTime = 1.5; // 1.5s to complete chain after first selection
  int maxChainLength = 1;
  double inputDrainMultiplier = 1.0;

  // Spawning variables
  double totalAltitude = 0.0; // Total distance climbed
  double _laserIndicatorTimer = 0.0;
  static const int baseFloatingObjects = 9;
  static const int maxFloatingObjects = 20;
  static const double _spawnInset = 48.0;
  static const double _replacementSpawnEdgeBand = 72.0;
  static const double _maxSpawnYFactor = 0.72;
  static const double baseReplacementSpawnPixelsPerObject = 80.0;
  int get targetFloatingObjectCount =>
      min(maxFloatingObjects, baseFloatingObjects + stageLevel - 1);
  double get replacementSpawnPixelsPerObject {
    final extraVisibleObjects = max(
      0,
      targetFloatingObjectCount - baseFloatingObjects,
    );
    return max(
      40.0,
      baseReplacementSpawnPixelsPerObject - extraVisibleObjects * 4.0,
    );
  }

  double get maxSpawnY => max(_spawnInset, size.y * _maxSpawnYFactor);

  int get experienceRequiredForCharacterLevel {
    final levelRamp = characterLevel - 1;
    return 6 + levelRamp * 4 + levelRamp * levelRamp * 2;
  }

  double experienceRewardMultiplierForStage(int level) {
    final stageRamp = max(0, level - 1);
    return min(2.5, 1.0 + stageRamp * 0.12);
  }

  int experienceRewardForTarget(SlashTarget target) {
    return max(
      target.experienceValue,
      (target.experienceValue * experienceRewardMultiplierForStage(stageLevel))
          .round(),
    );
  }

  int get turnsRequiredForNextStage => 5;
  int get bonusSpawnInterval {
    final reducedInterval = 400 * pow(0.9, luckLevel);
    return max(200, reducedInterval.round());
  }

  static double inputDrainMultiplierForStage(int level) {
    final stageLevel = max(1, level);
    final baseMultiplier = 1.0 + (stageLevel - 1) * 0.28;
    final earlyBonusProgress =
        ((earlyDrainBonusFadeOutStage - stageLevel) /
                (earlyDrainBonusFadeOutStage - 1))
            .clamp(0.0, 1.0);
    return baseMultiplier + 0.2 * earlyBonusProgress;
  }

  double get criticalStrikeChance => min(1.0, criticalStrikeLevel * 0.15);
  double get laserTargetSpawnChance {
    if (stageLevel < 2) {
      return 0.0;
    }
    return 0.013 + (stageLevel - 2) * 0.0065;
  }

  double get longObstacleChance => 0.18;

  int maxTargetDurabilityForStage(int level) {
    if (level <= 1) return 1;
    if (level <= 5) return level;
    return min(15, level + 2);
  }

  int laserTargetStageDurabilityBase(int level) {
    if (level <= 2) return 1;
    return maxTargetDurabilityForStage(level);
  }

  @visibleForTesting
  double obstacleSpawnChanceForStage(int level) {
    if (level < 2) return 0;
    if (level == 3) return 0.15;
    return min(0.50, (level - 1) * 0.10);
  }

  final Random random = Random();
  Vector2 _lastCameraShift = Vector2(0, 1);
  static const int maxRareUpgradeCount = 3;
  static const double rareUpgradeChance = 0.1;
  static const double lightfootGaugeDistance = 24000.0;
  static const double upgradeInputLockDuration = 0.7;
  static const double gameOverDelayDuration = 3.0;
  double _replacementSpawnScrollPixels = 0.0;
  double masterVolume = 0.5;
  double bgmVolume = 0.7;
  double sfxVolume = 1.0;
  bool masterMuted = false;
  bool bgmMuted = false;
  bool sfxMuted = false;
  bool get isMuted => masterMuted;
  bool get canChooseUpgrade => upgradeInputLockTimer <= 0.0;

  @visibleForTesting
  int get spawnsSinceLastBonusForTest => _spawnsSinceLastBonus;

  void setLanguage(GameLanguage value) {
    if (language == value) {
      return;
    }
    language = value;
    currentUpgradeChoices = isChoosingUpgrade
        ? (_tutorialPhase == TutorialPhase.upgradeChoice
              ? tutorialUpgradeChoices()
              : recommendedUpgradeChoices())
        : const [];
    achievementRevision.value++;
  }

  static List<Achievement> visibleAchievementsFrom(
    List<Achievement> achievements, {
    Set<String> acknowledgedAchievementIds = const {},
  }) {
    return [
      ...visibleUpgradeAchievementsFrom(
        achievements,
        acknowledgedAchievementIds: acknowledgedAchievementIds,
      ),
      visibleProgressAchievementFrom(
        achievements,
        AchievementGroup.stage,
        acknowledgedAchievementIds: acknowledgedAchievementIds,
      ),
      visibleProgressAchievementFrom(
        achievements,
        AchievementGroup.character,
        acknowledgedAchievementIds: acknowledgedAchievementIds,
      ),
      visibleProgressAchievementFrom(
        achievements,
        AchievementGroup.score,
        acknowledgedAchievementIds: acknowledgedAchievementIds,
      ),
    ].whereType<Achievement>().toList(growable: false);
  }

  static List<Achievement> visibleUpgradeAchievementsFrom(
    List<Achievement> achievements, {
    Set<String> acknowledgedAchievementIds = const {},
  }) {
    final visible = <Achievement>[];
    for (final type in UpgradeType.values) {
      final steps = achievements
          .where(
            (achievement) => achievement.id.startsWith('upgrade-${type.name}-'),
          )
          .toList(growable: false);
      if (steps.isEmpty) {
        continue;
      }
      visible.add(
        steps.firstWhere(
          (step) =>
              !step.unlocked || !acknowledgedAchievementIds.contains(step.id),
          orElse: () => steps.last,
        ),
      );
    }
    return visible;
  }

  static Achievement? visibleProgressAchievementFrom(
    List<Achievement> achievements,
    AchievementGroup group, {
    Set<String> acknowledgedAchievementIds = const {},
  }) {
    final steps = achievements
        .where((achievement) => achievement.group == group)
        .toList(growable: false);
    if (steps.isEmpty) {
      return null;
    }
    return steps.firstWhere(
      (step) => !step.unlocked || !acknowledgedAchievementIds.contains(step.id),
      orElse: () => steps.last,
    );
  }

  final Map<GameSound, Future<AudioPool>> _soundPools = {};
  Future<void>? _audioInitialization;
  GameMusic? _currentBgmTrack;
  GameMusic? _bgmPlayingTrack;
  GameSound? lastRequestedSoundForTest;
  double get effectiveBgmVolume => (masterMuted || bgmMuted)
      ? 0.0
      : (masterVolume * bgmVolume).clamp(0.0, 1.0);
  double get effectiveSfxVolume => (masterMuted || sfxMuted)
      ? 0.0
      : (masterVolume * sfxVolume).clamp(0.0, 1.0);
  double effectiveSfxVolumeFor(GameSound sound) =>
      (effectiveSfxVolume * sound.volumeMultiplier).clamp(0.0, 1.0);
  double get displayedEnergy => (health - hiddenEnergyReserve).clamp(0.0, 1.0);
  bool get _canUseAudio =>
      soundEnabled &&
      !WidgetsBinding.instance.runtimeType.toString().contains(
        'TestWidgetsFlutterBinding',
      );

  // Screen shake
  double shakeIntensity = 0.0;
  double get lowHealthWarningIntensity {
    const threshold = 0.3;
    final energy = displayedEnergy;
    if (energy > threshold + 0.000001) {
      return 0.0;
    }
    final dangerRatio = ((threshold - energy) / threshold).clamp(0.0, 1.0);
    return (0.15 + dangerRatio * 0.85).clamp(0.0, 1.0);
  }

  // Slow motion factor when chaining targets (bullet time)
  double get speedMultiplier {
    if (isTutorialWaitingForInput) {
      return 0.0;
    }
    return (currentChainPoints.isNotEmpty && !player.isDashing) ? 0.25 : 1.0;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await loadAchievementProgress();
    async_timer.unawaited(preloadSounds());

    // 1. Background
    background = FallingBackground();
    add(background!);

    // 2. Player
    player = PlayerComponent();
    add(player);
  }

  Future<void> preloadSounds() async {
    try {
      await FlameAudio.audioCache.loadAll([
        ...GameSound.values.map((sound) => sound.assetPath),
        ...GameMusic.values.map((music) => music.assetPath),
      ]);
    } catch (_) {
      // Audio should never block gameplay or tests.
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    handleTapDown(event);
  }

  @override
  void update(double dt) {
    _laserIndicatorTimer += dt;
    recordAchievementProgress(showToasts: isPlaying && !isGameOver);
    updateAchievementToast(dt);
    // Screen shake decay
    if (shakeIntensity > 0) {
      shakeIntensity = max(0.0, shakeIntensity - dt * 50.0);
    }
    if (levelUpAnnouncementTimer > 0) {
      levelUpAnnouncementTimer = max(0.0, levelUpAnnouncementTimer - dt);
    }
    if (upgradeInputLockTimer > 0) {
      upgradeInputLockTimer = max(0.0, upgradeInputLockTimer - dt);
    }
    prepareTutorialInputTargetsIfReady();

    // Apply speed multiplier (time dilation)
    final double adjustedDt = dt * speedMultiplier;
    if (isChoosingUpgrade) {
      syncBackgroundMotionSpeed();
      return;
    }

    syncBackgroundMotionSpeed();
    super.update(adjustedDt);
    resolveFloatingObjectRepulsion();

    if (!isPlaying) return;

    if (isGameOverPending) {
      _gameOverDelayTimer = max(0.0, _gameOverDelayTimer - dt);
      if (_gameOverDelayTimer == 0.0) {
        gameOver();
      }
      return;
    }

    // Passive energy decay when not dashing
    if (!player.isDashing) {
      health -= passiveDrainRate * inputDrainMultiplier * adjustedDt;
      if (health <= 0) {
        health = 0.0;
        beginDelayedGameOver();
        return;
      }
    }

    // Handle chain expiration timer (using real delta time so bullet time doesn't freeze the timer)
    if (currentChainPoints.isNotEmpty &&
        !player.isDashing &&
        !isTutorialWaitingForInput) {
      chainTimer += dt;
      if (chainTimer >= maxChainTime) {
        executeChainSlash();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();

    // Apply screen shake
    if (shakeIntensity > 0) {
      final double dx = (random.nextDouble() - 0.5) * shakeIntensity;
      final double dy = (random.nextDouble() - 0.5) * shakeIntensity;
      canvas.translate(dx, dy);
    }

    super.render(canvas);

    canvas.restore();
    renderLowHealthWarning(canvas);
    renderLaserTargetIndicators(canvas);
    renderTutorialGuide(canvas);
  }

  @override
  void onRemove() {
    stopBackgroundMusic();
    for (final pool in _soundPools.values) {
      async_timer.unawaited(pool.then((value) => value.dispose()));
    }
    _soundPools.clear();
    achievementRevision.dispose();
    super.onRemove();
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    return KeyEventResult.ignored;
  }

  void renderLowHealthWarning(Canvas canvas) {
    final intensity = lowHealthWarningIntensity;
    if (intensity <= 0) {
      return;
    }
    LowEnergyWarningPainter(intensity).paint(canvas, Size(size.x, size.y));
  }
}

@visibleForTesting
class LowEnergyWarningPainter extends CustomPainter {
  final double intensity;

  const LowEnergyWarningPainter(this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0 || size.isEmpty) {
      return;
    }

    final clampedIntensity = intensity.clamp(0.0, 1.0).toDouble();
    final edgeWidth = max(72.0, min(size.width, size.height) * 0.18);
    final edgeOpacity = 0.09 + clampedIntensity * 0.23;
    final red = const Color(0xFFFF003C);

    void drawEdge(Rect rect, Alignment begin, Alignment end) {
      final paint = Paint()
        ..shader = LinearGradient(
          begin: begin,
          end: end,
          colors: [
            red.withValues(alpha: edgeOpacity),
            red.withValues(alpha: edgeOpacity * 0.28),
            Colors.transparent,
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }

    drawEdge(
      Rect.fromLTWH(0, 0, size.width, edgeWidth),
      Alignment.topCenter,
      Alignment.bottomCenter,
    );
    drawEdge(
      Rect.fromLTWH(0, size.height - edgeWidth, size.width, edgeWidth),
      Alignment.bottomCenter,
      Alignment.topCenter,
    );
    drawEdge(
      Rect.fromLTWH(0, 0, edgeWidth, size.height),
      Alignment.centerLeft,
      Alignment.centerRight,
    );
    drawEdge(
      Rect.fromLTWH(size.width - edgeWidth, 0, edgeWidth, size.height),
      Alignment.centerRight,
      Alignment.centerLeft,
    );
  }

  @override
  bool shouldRepaint(covariant LowEnergyWarningPainter oldDelegate) {
    return oldDelegate.intensity != intensity;
  }
}
