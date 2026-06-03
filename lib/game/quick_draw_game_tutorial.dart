part of 'quick_draw_game.dart';

extension QuickDrawGameTutorial on QuickDrawGame {
  bool get isTutorialActive => _tutorialPhase != TutorialPhase.inactive;

  bool get isTutorialWaitingForInput {
    if (_tutorialPhase == TutorialPhase.inactive) {
      return false;
    }
    if (isChoosingUpgrade || player.isResolvingAction) {
      return false;
    }
    if (_tutorialPhase == TutorialPhase.firstSlash) {
      return currentChainPoints.isEmpty;
    }
    if (_tutorialPhase == TutorialPhase.chainedSlash ||
        _tutorialPhase == TutorialPhase.ultimateSlash) {
      return currentChainPoints.length < maxChainLength;
    }
    return false;
  }

  bool get shouldAutoStartTutorial =>
      _tutorialProgressLoaded && !_tutorialCompleted;

  Vector2 get tutorialFirstTargetPosition =>
      Vector2(size.x * 0.5, size.y * 0.34);

  List<Vector2> get tutorialChainTargetPositions => [
    Vector2(size.x * 0.36, size.y * 0.32),
    Vector2(size.x * 0.5, size.y * 0.28),
    Vector2(size.x * 0.64, size.y * 0.24),
  ];

  List<Vector2> get tutorialChainTapPositions {
    final targets = tutorialChainTargetPositions;
    return [targets.first, targets.last];
  }

  List<Vector2> get tutorialUltimateTapPositions => [
    Vector2(size.x * 0.34, size.y * 0.34),
    Vector2(size.x * 0.66, size.y * 0.22),
  ];

  Vector2 get tutorialBonusTargetPosition {
    final taps = tutorialUltimateTapPositions;
    return (taps.first + taps.last) * 0.5;
  }

  List<Vector2> get _tutorialCurrentChainTargetPositions =>
      tutorialChainTargetPositions;

  List<Vector2> get _tutorialCurrentChainTapPositions =>
      tutorialChainTapPositions;

  @visibleForTesting
  TutorialPhase get tutorialPhaseForTest => _tutorialPhase;

  @visibleForTesting
  bool get tutorialCompletedForTest => _tutorialCompleted;

  @visibleForTesting
  Vector2 get tutorialFirstTargetPositionForTest => tutorialFirstTargetPosition;

  @visibleForTesting
  List<Vector2> get tutorialChainTargetPositionsForTest =>
      tutorialChainTargetPositions;

  @visibleForTesting
  List<Vector2> get tutorialChainTapPositionsForTest =>
      tutorialChainTapPositions;

  @visibleForTesting
  List<Vector2> get tutorialUltimateTapPositionsForTest =>
      tutorialUltimateTapPositions;

  @visibleForTesting
  Vector2 get tutorialBonusTargetPositionForTest => tutorialBonusTargetPosition;

  @visibleForTesting
  int get finalScoreForRecord =>
      _tutorialScorePenaltyActive ? score ~/ 2 : score;

  void startTutorial() {
    playSound(GameSound.uiConfirm);
    startGame(forceTutorial: true);
  }

  void beginTutorialRun() {
    _tutorialPhase = TutorialPhase.firstSlash;
    _tutorialChainTargetsPrepared = false;
    _tutorialBonusTargetPrepared = false;
    _tutorialBonusTargetCollected = false;
    spawnTutorialFirstTarget();
  }

  void endTutorialRun() {
    if (!isTutorialActive) {
      return;
    }
    _tutorialPhase = TutorialPhase.inactive;
    _tutorialChainTargetsPrepared = false;
    _tutorialBonusTargetPrepared = false;
    _tutorialBonusTargetCollected = false;
    _tutorialCompleted = true;
    persistTutorialCompletion();
    clearGameplayComponents();
    spawnInitialObjects();
  }

  void resetTutorialStateForNewRun({required bool tutorial}) {
    _tutorialPhase = tutorial
        ? TutorialPhase.firstSlash
        : TutorialPhase.inactive;
    _tutorialChainTargetsPrepared = false;
    _tutorialBonusTargetPrepared = false;
    _tutorialBonusTargetCollected = false;
    _tutorialScorePenaltyActive = tutorial;
  }

  void spawnTutorialFirstTarget() {
    _tutorialChainTargetsPrepared = false;
    _tutorialBonusTargetPrepared = false;
    _tutorialBonusTargetCollected = false;
    clearGameplayComponents();
    add(tutorialTargetAt(tutorialFirstTargetPosition));
  }

  void spawnTutorialChainTargets() {
    if (_tutorialChainTargetsPrepared) {
      return;
    }
    _tutorialChainTargetsPrepared = true;
    clearGameplayComponents();
    for (final position in _tutorialCurrentChainTargetPositions) {
      add(tutorialTargetAt(position));
    }
    updateChainHighlighting();
  }

  void spawnTutorialBonusTarget() {
    if (_tutorialBonusTargetPrepared) {
      return;
    }
    _tutorialBonusTargetPrepared = true;
    add(
      BonusTarget()
        ..position = tutorialBonusTargetPosition
        ..age = 0.4
        ..opacity = 1.0,
    );
  }

  SlashTarget tutorialTargetAt(Vector2 position) {
    return SlashTarget()
      ..position = position
      ..age = 0.4
      ..opacity = 1.0;
  }

  UpgradeOption tutorialChainLengthUpgradeOption() {
    final t = text;
    return UpgradeOption(
      type: UpgradeType.chainLength,
      title: t.upgradeTitle(UpgradeType.chainLength),
      description: t.upgradeDescription(UpgradeType.chainLength),
      color: const Color(0xFF00E5FF),
      currentValue: '${t.current} $maxChainLength',
    );
  }

  List<UpgradeOption> tutorialUpgradeChoices() {
    final options = recommendedUpgradeChoices().toList(growable: true);
    final chainOption = tutorialChainLengthUpgradeOption();
    final chainIndex = options.indexWhere(
      (option) => option.type == UpgradeType.chainLength,
    );
    if (chainIndex >= 0) {
      options[chainIndex] = chainOption;
    } else if (options.length >= 3) {
      options[1] = chainOption;
    } else {
      options.add(chainOption);
    }
    return options.take(3).toList(growable: false);
  }

  bool canChooseUpgradeOption(UpgradeOption option) {
    if (_tutorialPhase != TutorialPhase.upgradeChoice) {
      return true;
    }
    return option.type == UpgradeType.chainLength;
  }

  bool get isTutorialUpgradeChoiceActive =>
      _tutorialPhase == TutorialPhase.upgradeChoice;

  bool isTutorialUpgradeFocus(UpgradeOption option) =>
      isTutorialUpgradeChoiceActive && option.type == UpgradeType.chainLength;

  Vector2? guidedTutorialTapPosition(Vector2 tapPosition) {
    if (!isTutorialActive) {
      return tapPosition;
    }
    if (_tutorialPhase == TutorialPhase.firstSlash) {
      return _acceptedTutorialTap(
        tapPosition: tapPosition,
        targetPosition: tutorialFirstTargetPosition,
      );
    }
    if (_tutorialPhase == TutorialPhase.chainedSlash) {
      final targets = _tutorialCurrentChainTapPositions;
      final index = currentChainPoints.length;
      if (index >= targets.length) {
        return null;
      }
      return _acceptedTutorialTap(
        tapPosition: tapPosition,
        targetPosition: targets[index],
      );
    }
    if (_tutorialPhase == TutorialPhase.ultimateSlash) {
      final targets = tutorialUltimateTapPositions;
      final index = currentChainPoints.length;
      if (index >= targets.length) {
        return null;
      }
      return _acceptedTutorialTap(
        tapPosition: tapPosition,
        targetPosition: targets[index],
      );
    }
    return null;
  }

  Vector2? _acceptedTutorialTap({
    required Vector2 tapPosition,
    required Vector2 targetPosition,
  }) {
    const tolerance = 96.0;
    if ((tapPosition - targetPosition).length > tolerance) {
      return null;
    }
    return targetPosition;
  }

  void onTutorialTargetSliced() {
    if (_tutorialPhase != TutorialPhase.firstSlash) {
      return;
    }
    _pendingExperienceHits = experienceRequiredForCharacterLevel;
  }

  void beforeCollectTutorialExperience() {
    if (_tutorialPhase == TutorialPhase.firstSlash &&
        _pendingExperienceHits > 0) {
      _pendingExperienceHits = experienceRequiredForCharacterLevel;
      _tutorialPhase = TutorialPhase.upgradeChoice;
    }
  }

  void onTutorialUpgradeChosen() {
    if (_tutorialPhase != TutorialPhase.upgradeChoice) {
      return;
    }
    _tutorialPhase = TutorialPhase.chainedSlash;
    _tutorialChainTargetsPrepared = false;
    _tutorialBonusTargetPrepared = false;
    _tutorialBonusTargetCollected = false;
    clearGameplayComponents();
    prepareTutorialInputTargetsIfReady();
  }

  void prepareTutorialInputTargetsIfReady() {
    if (_tutorialPhase != TutorialPhase.chainedSlash &&
        _tutorialPhase != TutorialPhase.ultimateSlash) {
      return;
    }
    if (isChoosingUpgrade || player.isResolvingAction) {
      return;
    }
    if (_tutorialPhase == TutorialPhase.ultimateSlash) {
      spawnTutorialBonusTarget();
      return;
    }
    if (_tutorialPhase != TutorialPhase.chainedSlash ||
        _tutorialChainTargetsPrepared ||
        children.whereType<SlashTarget>().isNotEmpty) {
      return;
    }
    spawnTutorialChainTargets();
  }

  void onTutorialChainPointAdded() {
    if (_tutorialPhase == TutorialPhase.ultimateSlash) {
      spawnTutorialBonusTarget();
    }
  }

  void onTutorialBonusCollected() {
    if (_tutorialPhase == TutorialPhase.ultimateSlash) {
      _tutorialBonusTargetCollected = true;
    }
  }

  void onTutorialInputTurnCompleted() {
    if (_tutorialPhase == TutorialPhase.chainedSlash) {
      _tutorialPhase = TutorialPhase.ultimateSlash;
      _tutorialChainTargetsPrepared = false;
      _tutorialBonusTargetPrepared = false;
      _tutorialBonusTargetCollected = false;
      clearGameplayComponents();
      prepareTutorialInputTargetsIfReady();
      return;
    }
    if (_tutorialPhase == TutorialPhase.ultimateSlash &&
        _tutorialBonusTargetCollected) {
      endTutorialRun();
    }
  }

  Future<void> persistTutorialCompletion() async {
    if (!_tutorialProgressLoaded) {
      return;
    }
    try {
      await saveAchievementProgress();
    } catch (_) {
      // Local persistence should not block gameplay or tests.
    }
  }

  void renderTutorialGuide(Canvas canvas) {
    if (!isTutorialActive ||
        isChoosingUpgrade ||
        player.isResolvingAction ||
        size.x <= 0 ||
        size.y <= 0) {
      return;
    }
    final target = _tutorialPhase == TutorialPhase.firstSlash
        ? tutorialFirstTargetPosition
        : _tutorialPhase == TutorialPhase.ultimateSlash
        ? tutorialUltimateTapPositions[min(
            currentChainPoints.length,
            tutorialUltimateTapPositions.length - 1,
          )]
        : _tutorialCurrentChainTapPositions[min(
            currentChainPoints.length,
            _tutorialCurrentChainTapPositions.length - 1,
          )];
    final showBonusGuide =
        _tutorialPhase == TutorialPhase.ultimateSlash &&
        _tutorialBonusTargetPrepared;
    final label = _tutorialPhase == TutorialPhase.firstSlash
        ? (text.isKo
              ? '운석을 베면 경험치를 얻고 강화를 선택할 수 있어요'
              : 'Slash meteors to gain experience and choose upgrades')
        : _tutorialPhase == TutorialPhase.ultimateSlash
        ? (text.isKo
              ? '보너스 오브젝트는 즉시 에너지를 모두 회복하고 화면의 모든 오브젝트를 베어요'
              : 'Bonus objects instantly refill energy and slash every object on screen')
        : (text.isKo
              ? '두 운석을 연속 클릭하면 입력 경로의 운석도 함께 벨 수 있어요'
              : 'Chain two taps to slash meteors along the input path');
    _drawTutorialGuide(
      canvas,
      target,
      label,
      secondaryTarget: showBonusGuide ? tutorialBonusTargetPosition : null,
    );
  }

  void _drawTutorialGuide(
    Canvas canvas,
    Vector2 target,
    String label, {
    Vector2? secondaryTarget,
  }) {
    final pulse = (sin(_laserIndicatorTimer * 8.0) + 1.0) / 2.0;
    _drawTutorialDarkMask(
      canvas,
      secondaryTarget == null ? [target] : [target, secondaryTarget],
    );
    final ringPaint = Paint()
      ..color = const Color(0xFF00FFCC).withValues(alpha: 0.62 + pulse * 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    final fillPaint = Paint()
      ..color = const Color(0xFF00FFCC).withValues(alpha: 0.12 + pulse * 0.08)
      ..style = PaintingStyle.fill;
    final center = Offset(target.x, target.y);
    canvas.drawCircle(center, 74 + pulse * 8, fillPaint);
    canvas.drawCircle(center, 62 + pulse * 8, ringPaint);
    _drawTutorialHandIcon(canvas, target, pulse);

    if (secondaryTarget != null) {
      final bonusCenter = Offset(secondaryTarget.x, secondaryTarget.y);
      final bonusPaint = Paint()
        ..color = const Color(0xFF22C55E).withValues(alpha: 0.58 + pulse * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawCircle(bonusCenter, 54 + pulse * 6, bonusPaint);
    }

    _drawTutorialTextPanel(canvas, label);
  }

  void _drawTutorialTextPanel(Canvas canvas, String label) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: min(size.x - 64, 460));

    final textOffset = Offset((size.x - textPainter.width) / 2, 42.0);
    final bubbleRect = Rect.fromLTWH(
      textOffset.dx - 16,
      textOffset.dy - 10,
      textPainter.width + 32,
      textPainter.height + 20,
    );
    final bubblePaint = Paint()
      ..color = const Color(0xFF05060A).withValues(alpha: 0.72);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bubbleRect, const Radius.circular(8)),
      bubblePaint,
    );
    textPainter.paint(canvas, textOffset);
  }

  void _drawTutorialHandIcon(Canvas canvas, Vector2 target, double pulse) {
    final bob = sin(_laserIndicatorTimer * 5.0) * 7.0;
    final origin = Offset(target.x + 18, target.y + 20 + bob);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(-0.18);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(const Rect.fromLTWH(-18, 20, 46, 14), shadowPaint);

    final outlinePaint = Paint()
      ..color = const Color(0xFF052E20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final handPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.94)
      ..style = PaintingStyle.fill;

    final handPath = Path()
      ..moveTo(-11, 14)
      ..lineTo(-11, -6)
      ..quadraticBezierTo(-11, -15, -4, -15)
      ..quadraticBezierTo(2, -15, 2, -7)
      ..lineTo(2, -28)
      ..quadraticBezierTo(2, -36, 9, -36)
      ..quadraticBezierTo(16, -36, 16, -28)
      ..lineTo(16, -10)
      ..lineTo(24, -8)
      ..quadraticBezierTo(31, -6, 30, 2)
      ..lineTo(26, 20)
      ..quadraticBezierTo(24, 29, 14, 29)
      ..lineTo(0, 29)
      ..quadraticBezierTo(-9, 29, -13, 20)
      ..close();
    canvas.drawPath(handPath, handPaint);
    canvas.drawPath(handPath, outlinePaint);

    final tapPaint = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: 0.52 + pulse * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(const Offset(9, -42), 9 + pulse * 4, tapPaint);
    canvas.restore();
  }

  void _drawTutorialDarkMask(Canvas canvas, List<Vector2> targets) {
    final bounds = Offset.zero & Size(size.x, size.y);
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(
      bounds,
      Paint()..color = Colors.black.withValues(alpha: 0.68),
    );
    for (final target in targets) {
      canvas.drawCircle(
        Offset(target.x, target.y),
        92,
        Paint()..blendMode = BlendMode.clear,
      );
    }
    canvas.restore();
  }
}
