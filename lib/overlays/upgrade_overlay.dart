import 'dart:async' as async_timer;
import 'dart:math';
import 'package:flutter/material.dart';
import '../game/quick_draw_game.dart';

class UpgradeOverlay extends StatefulWidget {
  final QuickDrawGame game;
  const UpgradeOverlay({super.key, required this.game});

  @override
  State<UpgradeOverlay> createState() => _UpgradeOverlayState();
}

class _UpgradeOverlayState extends State<UpgradeOverlay> {
  async_timer.Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    _lockTimer = async_timer.Timer.periodic(const Duration(milliseconds: 80), (
      _,
    ) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choices = widget.game.currentUpgradeChoices;
    final canChoose = widget.game.canChooseUpgrade;
    final t = widget.game.text;
    return SizedBox.expand(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 72),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LevelUpAnnouncement(
                    title: widget.game.levelUpAnnouncementTitle,
                    level: widget.game.levelUpAnnouncementLevel,
                    text: widget.game.text,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t.upgrade,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.game.isTutorialUpgradeChoiceActive) ...[
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Text(
                        t.tutorialUpgradeChoiceHint,
                        key: const ValueKey('tutorial-upgrade-choice-hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 288,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < choices.length; i++) ...[
                          if (i > 0) const SizedBox(width: 18),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final canChooseOption = widget.game
                                    .canChooseUpgradeOption(choices[i]);
                                final isTutorialChoice =
                                    widget.game.isTutorialUpgradeChoiceActive;
                                return _UpgradeButton(
                                  option: choices[i],
                                  text: widget.game.text,
                                  enabled: canChoose && canChooseOption,
                                  highlighted: widget.game
                                      .isTutorialUpgradeFocus(choices[i]),
                                  masked: isTutorialChoice && !canChooseOption,
                                  onPressed: () =>
                                      widget.game.chooseUpgrade(choices[i]),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
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

class LevelUpAnnouncement extends StatelessWidget {
  final String title;
  final int level;
  final GameText text;

  const LevelUpAnnouncement({
    super.key,
    required this.title,
    required this.level,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final localizedTitle = text.levelUpTitle(title);
    final isStageLevelUp = title == 'STAGE LEVEL UP';
    final accentColor = isStageLevelUp
        ? const Color(0xFFFF8A3D)
        : const Color(0xFFA29BFE);
    final levelColor = isStageLevelUp
        ? const Color(0xFFFFD166)
        : const Color(0xFFE9E5FF);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          localizedTitle,
          style: TextStyle(
            color: accentColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            shadows: [
              Shadow(color: accentColor.withValues(alpha: 0.8), blurRadius: 14),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text.level(level),
          style: TextStyle(
            color: levelColor,
            fontSize: 54,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: accentColor.withValues(alpha: 0.55),
                blurRadius: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  final UpgradeOption option;
  final GameText text;
  final bool enabled;
  final bool highlighted;
  final bool masked;
  final VoidCallback onPressed;

  const _UpgradeButton({
    required this.option,
    required this.text,
    required this.enabled,
    required this.highlighted,
    required this.masked,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF101322).withValues(alpha: 0.94),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(
          0xFF101322,
        ).withValues(alpha: 0.94),
        disabledForegroundColor: Colors.white,
        elevation: 10,
        shadowColor: option.color.withValues(alpha: 0.45),
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 210),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: option.color.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconSize = min(
            constraints.maxWidth * 0.96,
            constraints.maxHeight * 0.70,
          );

          return Stack(
            children: [
              if (highlighted)
                Positioned.fill(
                  child: DecoratedBox(
                    key: const ValueKey('tutorial-upgrade-focus'),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00FFCC),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF00FFCC,
                          ).withValues(alpha: 0.55),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: option.color,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: option.color.withValues(alpha: 0.65),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 28,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox.square(
                    dimension: iconSize,
                    child: Image.asset(
                      option.iconAssetPath,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080B15).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: option.color.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (option.isRare)
                        Text(
                          text.rare,
                          style: TextStyle(
                            color: option.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        )
                      else if (option.currentValue != null)
                        Text(
                          option.currentValue!,
                          style: TextStyle(
                            color: option.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        option.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.18,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (masked)
                Positioned.fill(
                  child: DecoratedBox(
                    key: const ValueKey('tutorial-upgrade-disabled-mask'),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
