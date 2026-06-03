import 'package:flutter/material.dart';
import '../game/quick_draw_game.dart';
import 'friend_invite_dialog.dart';

class GameOverOverlay extends StatelessWidget {
  final QuickDrawGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final t = game.text;
    final upgradeRows = _upgradeReportRows();
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      t.defeated,
                      style: TextStyle(
                        fontSize: 78,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: const Color(0xFFFF2D55),
                        shadows: [
                          Shadow(
                            color: const Color(
                              0xFFFF2D55,
                            ).withValues(alpha: 0.8),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ScoreSummary(game: game),
                  if (upgradeRows.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _UpgradeReportGrid(rows: upgradeRows, closeLabel: t.close),
                  ],
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _GameOverButton(
                          label: t.tryAgain,
                          onPressed: game.startGame,
                          isPrimary: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _GameOverButton(
                          label: t.ranking,
                          onPressed: game.showRanking,
                          isPrimary: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _GameOverButton(
                          label: t.home,
                          onPressed: game.returnHomeFromSettings,
                          isPrimary: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _GameOverButton(
                      label: t.shareLink,
                      onPressed: () {
                        game.playSound(GameSound.uiSelect);
                        showFriendInviteDialog(context, game: game);
                      },
                      isPrimary: false,
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

  List<_UpgradeReportRow> _upgradeReportRows() {
    final rows = <_UpgradeReportRow>[
      _rowForLevel(UpgradeType.bladePower, game.playerAttackPower - 1),
      _rowForLevel(UpgradeType.criticalStrike, game.criticalStrikeLevel),
      _rowForLevel(UpgradeType.chainLength, game.maxChainLength - 1),
      _rowForLevel(UpgradeType.scrollRecovery, _scrollRecoveryLevel()),
      _rowForLevel(UpgradeType.energyEfficiency, _energyEfficiencyLevel()),
      _rowForLevel(UpgradeType.focusTime, _focusTimeLevel()),
      _rowForLevel(UpgradeType.luck, game.luckLevel),
      _rowForLevel(UpgradeType.shadowClone, game.shadowCloneLevel),
      _rowForLevel(UpgradeType.shield, game.shieldUnlocked ? 1 : 0),
      _rowForLevel(
        UpgradeType.lightfootGauge,
        game.lightfootGaugeUnlocked ? 1 : 0,
      ),
      _rowForLevel(UpgradeType.chainStrike, game.chainStrikeUnlocked ? 1 : 0),
    ];

    return rows.where((row) => row.level > 0).toList(growable: false);
  }

  _UpgradeReportRow _rowForLevel(UpgradeType type, int level) {
    final t = game.text;
    return _UpgradeReportRow(
      type: type,
      level: level,
      title: t.upgradeTitle(type),
      description: t.upgradeDescription(type),
    );
  }

  int _scrollRecoveryLevel() {
    return ((game.scrollEnergyGainMultiplier - 1.0) / 0.25).round().clamp(
      0,
      99,
    );
  }

  int _energyEfficiencyLevel() {
    var value = QuickDrawGame.initialPassiveDrainRate;
    var level = 0;
    while (value > game.passiveDrainRate + 0.000001 && level < 99) {
      value = (value * 0.85).clamp(0.02, double.infinity).toDouble();
      level++;
    }
    return level;
  }

  int _focusTimeLevel() {
    return ((game.maxChainTime - 1.5) / 0.25).round().clamp(0, 99);
  }
}

class _ScoreSummary extends StatelessWidget {
  final QuickDrawGame game;

  const _ScoreSummary({required this.game});

  @override
  Widget build(BuildContext context) {
    final t = game.text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF070A12).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF2D55).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        children: [
          Text(
            t.finalScore,
            style: TextStyle(
              fontSize: 20,
              letterSpacing: 2,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${game.score}',
            style: const TextStyle(
              fontSize: 69,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: t.stageLevel,
                  value: '${game.stageLevel}',
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: t.characterLevel,
                  value: '${game.characterLevel}',
                  color: const Color(0xFFFACC15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MetricTile(
            label: t.bestScore,
            value: '${game.bestScore}',
            color: const Color(0xFF00FFCC),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeReportGrid extends StatelessWidget {
  final List<_UpgradeReportRow> rows;
  final String closeLabel;

  const _UpgradeReportGrid({required this.rows, required this.closeLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101522).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 20) / 3;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final row in rows)
                _UpgradeReportChip(
                  row: row,
                  width: itemWidth,
                  onPressed: () {
                    _showUpgradeReportPopup(context, row, closeLabel);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _UpgradeReportChip extends StatelessWidget {
  final _UpgradeReportRow row;
  final double width;
  final VoidCallback onPressed;

  const _UpgradeReportChip({
    required this.row,
    required this.width,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.065),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  row.type.iconAssetPath,
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                Text(
                  'Lv.${row.level}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showUpgradeReportPopup(
  BuildContext context,
  _UpgradeReportRow row,
  String closeLabel,
) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: const Color(0xFF101522),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFACC15),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  row.description,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      closeLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _GameOverButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _GameOverButton({
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPrimary ? const Color(0xFFFF2D55) : const Color(0xFF1F2937);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shadowColor: isPrimary ? const Color(0xFFFF2D55) : Colors.black,
        elevation: isPrimary ? 10 : 4,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        side: isPrimary
            ? null
            : BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _UpgradeReportRow {
  final UpgradeType type;
  final int level;
  final String title;
  final String description;

  const _UpgradeReportRow({
    required this.type,
    required this.level,
    required this.title,
    required this.description,
  });
}
