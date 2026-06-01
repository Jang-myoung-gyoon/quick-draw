import 'package:flutter/material.dart';

enum UpgradeType {
  bladePower,
  criticalStrike,
  chainLength,
  scrollRecovery,
  energyEfficiency,
  focusTime,
  luck,
  shadowClone,
  shield,
  lightfootGauge,
  chainStrike,
}

class UpgradeOption {
  final UpgradeType type;
  final String title;
  final String description;
  final Color color;
  final bool isRare;
  final String? currentValue;

  const UpgradeOption({
    required this.type,
    required this.title,
    required this.description,
    required this.color,
    this.isRare = false,
    this.currentValue,
  });

  String get iconAssetPath => type.iconAssetPath;
}

extension UpgradeTypeIconAsset on UpgradeType {
  String get iconAssetPath => switch (this) {
    UpgradeType.bladePower => 'assets/images/icons/upgrades/blade_power.png',
    UpgradeType.criticalStrike =>
      'assets/images/icons/upgrades/critical_chance.png',
    UpgradeType.chainLength => 'assets/images/icons/upgrades/chain_length.png',
    UpgradeType.scrollRecovery =>
      'assets/images/icons/upgrades/scroll_recovery.png',
    UpgradeType.energyEfficiency =>
      'assets/images/icons/upgrades/energy_efficiency.png',
    UpgradeType.focusTime => 'assets/images/icons/upgrades/focus_time.png',
    UpgradeType.luck => 'assets/images/icons/upgrades/luck.png',
    UpgradeType.shadowClone => 'assets/images/icons/upgrades/shadow_clone.png',
    UpgradeType.shield => 'assets/images/icons/upgrades/shield.png',
    UpgradeType.lightfootGauge =>
      'assets/images/icons/upgrades/lightfoot_gauge.png',
    UpgradeType.chainStrike => 'assets/images/icons/upgrades/chain_strike.png',
  };
}
