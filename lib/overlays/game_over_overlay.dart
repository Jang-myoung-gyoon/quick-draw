import 'package:flutter/material.dart';
import '../game/quick_draw_game.dart';

class GameOverOverlay extends StatelessWidget {
  final QuickDrawGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final t = game.text;
    final reportRows = _upgradeReportRows();
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
                  Text(
                    t.defeated,
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: const Color(0xFFFF2D55),
                      shadows: [
                        Shadow(
                          color: const Color(0xFFFF2D55).withValues(alpha: 0.8),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _ScoreSummary(game: game),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101522).withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.finalReport,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: Colors.white.withValues(alpha: 0.58),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: reportRows
                              .map((row) => _UpgradeReportChip(row: row))
                              .toList(growable: false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: game.startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D55),
                      foregroundColor: Colors.white,
                      shadowColor: const Color(0xFFFF2D55),
                      elevation: 10,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      t.tryAgain,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
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
    final t = game.text;
    final isKo = t.isKo;
    String percent(double value) => '${(value * 100).round()}%';
    String unlocked(bool value) {
      if (isKo) return value ? '획득' : '-';
      return value ? 'Unlocked' : '-';
    }

    return [
      _UpgradeReportRow(
        t.upgradeTitle(UpgradeType.bladePower),
        isKo
            ? '공격력 ${game.playerAttackPower}'
            : 'ATK ${game.playerAttackPower}',
      ),
      _UpgradeReportRow(
        t.upgradeTitle(UpgradeType.criticalStrike),
        percent(game.criticalStrikeChance),
      ),
      _UpgradeReportRow(
        t.upgradeTitle(UpgradeType.chainLength),
        isKo ? '${game.maxChainLength}회' : '${game.maxChainLength} cuts',
      ),
      _UpgradeReportRow(
        t.upgradeTitle(UpgradeType.scrollRecovery),
        percent(game.scrollEnergyGainMultiplier),
      ),
      _UpgradeReportRow(
        t.upgradeTitle(UpgradeType.energyEfficiency),
        isKo
            ? '소모 ${(game.passiveDrainRate * 100).toStringAsFixed(1)}'
            : 'Drain ${(game.passiveDrainRate * 100).toStringAsFixed(1)}',
      ),
      _UpgradeReportRow(
        t.upgradeTitle(UpgradeType.focusTime),
        '${game.maxChainTime.toStringAsFixed(2)}s',
      ),
      _UpgradeReportRow(
        t.upgradeTitle(UpgradeType.luck),
        '1 / ${game.bonusSpawnInterval}',
      ),
      _UpgradeReportRow(
        t.upgradeTitle(UpgradeType.shadowClone),
        '${game.shadowCloneLevel} / 4',
      ),
      _UpgradeReportRow(
        t.upgradeTitle(UpgradeType.shield),
        unlocked(game.shieldUnlocked),
      ),
      _UpgradeReportRow(
        t.upgradeTitle(UpgradeType.lightfootGauge),
        unlocked(game.lightfootGaugeUnlocked),
      ),
      _UpgradeReportRow(
        t.upgradeTitle(UpgradeType.chainStrike),
        unlocked(game.chainStrikeUnlocked),
      ),
    ];
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
              fontSize: 13,
              letterSpacing: 2,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${game.score}',
            style: const TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
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
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeReportChip extends StatelessWidget {
  final _UpgradeReportRow row;

  const _UpgradeReportChip({required this.row});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.065),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              row.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeReportRow {
  final String label;
  final String value;

  const _UpgradeReportRow(this.label, this.value);
}
