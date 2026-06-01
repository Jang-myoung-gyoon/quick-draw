import 'dart:async' as async_timer;
import 'package:flutter/material.dart';
import '../game/quick_draw_game.dart';
import 'settings_overlay.dart';
import 'upgrade_overlay.dart';

class _AchievementToast extends StatelessWidget {
  final String message;

  const _AchievementToast({required this.message});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('achievement-toast'),
      decoration: BoxDecoration(
        color: const Color(0xFF05060A).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFD166).withValues(alpha: 0.78),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD166).withValues(alpha: 0.18),
            blurRadius: 18,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Text(
          message,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFFFD166),
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class HUDOverlay extends StatefulWidget {
  final QuickDrawGame game;
  const HUDOverlay({super.key, required this.game});

  @override
  State<HUDOverlay> createState() => _HUDOverlayState();
}

class _HUDOverlayState extends State<HUDOverlay> {
  static const int rareSkillSlotCount = 2;
  async_timer.Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateTimer = async_timer.Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.game.text;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              key: const ValueKey('hud-passive-layer'),
              child: Stack(
                children: [
                  _LowEnergyWarningOverlay(
                    intensity: widget.game.lowHealthWarningIntensity,
                  ),

                  // ── Top Bar: Score & Combo ──
                  Positioned(
                    top: 50,
                    left: 24,
                    right: 92,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Score
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.score,
                              style: const TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.5,
                                color: Colors.white60,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.game.score}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                for (
                                  var i = 0;
                                  i < rareSkillSlotCount;
                                  i++
                                ) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  _buildRareSkillSlot(
                                    slotIndex: i,
                                    i < widget.game.acquiredRareUpgrades.length
                                        ? widget.game.acquiredRareUpgrades[i]
                                        : null,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        // Combo indicator
                        if (widget.game.combo > 0)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF00FFCC,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(
                                  0xFF00FFCC,
                                ).withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              t.comboSlices(widget.game.combo),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: const Color(0xFF00FFCC),
                                shadows: [
                                  Shadow(
                                    color: const Color(
                                      0xFF00FFCC,
                                    ).withValues(alpha: 0.8),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (widget.game.levelUpAnnouncementTimer > 0)
                    Positioned(
                      top: 178,
                      left: 24,
                      right: 24,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: widget.game.levelUpAnnouncementTimer > 0
                            ? 1
                            : 0,
                        child: LevelUpAnnouncement(
                          title: widget.game.levelUpAnnouncementTitle,
                          level: widget.game.levelUpAnnouncementLevel,
                          text: widget.game.text,
                        ),
                      ),
                    ),

                  if (widget.game.achievementToastMessage != null)
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 116,
                      child: Center(
                        child: _AchievementToast(
                          message: widget.game.achievementToastMessage!,
                        ),
                      ),
                    ),

                  // ── Bottom-right vertical gauges ──
                  Positioned(
                    bottom: 32,
                    right: 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildVerticalGauge(
                          label: t.energy,
                          value: widget.game.displayedEnergy,
                          gradientColors: widget.game.displayedEnergy < 0.25
                              ? [
                                  const Color(0xFFFF0055),
                                  const Color(0xFFFF5500),
                                ]
                              : [
                                  const Color(0xFFFF2D55),
                                  const Color(0xFF00FFCC),
                                ],
                          glowColor: widget.game.displayedEnergy < 0.25
                              ? const Color(0xFFFF0055)
                              : const Color(0xFF00FFCC),
                          icon: '⚡',
                        ),
                        const SizedBox(width: 10),
                        _buildVerticalGauge(
                          label: t.characterGauge(widget.game.characterLevel),
                          value: widget.game.experience.clamp(0.0, 1.0),
                          gradientColors: const [
                            Color(0xFF6C5CE7),
                            Color(0xFFA29BFE),
                          ],
                          glowColor: const Color(0xFFA29BFE),
                          icon: '✦',
                        ),
                        if (widget.game.lightfootGaugeUnlocked) ...[
                          const SizedBox(width: 10),
                          _buildVerticalGauge(
                            label: t.step,
                            value: widget.game.lightfootGauge.clamp(0.0, 1.0),
                            gradientColors: const [
                              Color(0xFF16A34A),
                              Color(0xFF86EFAC),
                            ],
                            glowColor: const Color(0xFF22C55E),
                            icon: '⇧',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 44,
            right: 24,
            child: SettingsIconButton(game: widget.game),
          ),
        ],
      ),
    );
  }

  Widget _buildRareSkillSlot(
    UpgradeType? upgradeType, {
    required int slotIndex,
  }) {
    return Container(
      key: ValueKey('rare-skill-slot-$slotIndex'),
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFF05060A).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.12),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: upgradeType == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                upgradeType.iconAssetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
    );
  }

  Widget _buildVerticalGauge({
    required String label,
    required double value,
    required List<Color> gradientColors,
    required Color glowColor,
    required String icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: TextStyle(fontSize: 13, color: glowColor)),
        const SizedBox(height: 5),
        Container(
          width: 18,
          height: 132,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2135).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: glowColor.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: constraints.maxWidth,
                    height: constraints.maxHeight * value,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: gradientColors,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: glowColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _LowEnergyWarningOverlay extends StatelessWidget {
  final double intensity;

  const _LowEnergyWarningOverlay({required this.intensity});

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0) {
      return const SizedBox.shrink(key: ValueKey('low-energy-warning-off'));
    }
    return Positioned.fill(
      key: const ValueKey('low-energy-warning'),
      child: CustomPaint(painter: LowEnergyWarningPainter(intensity)),
    );
  }
}
