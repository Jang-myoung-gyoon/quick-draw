enum GameSound {
  slashSwing('elevenlabs/slash_swing.mp3'),
  targetSlice('elevenlabs/target_slice_soft.mp3'),
  targetHit('elevenlabs/target_hit.mp3'),
  obstacleHit('elevenlabs/obstacle_hit.mp3'),
  bonusTrigger('elevenlabs/bonus_trigger.mp3'),
  bonusCollect('elevenlabs/bonus_ultimate_slash.mp3'),
  laserAttack('elevenlabs/laser_attack.mp3'),
  energyShardAbsorb('elevenlabs/energy_shard_absorb.mp3'),
  experienceShardAbsorb('elevenlabs/experience_shard_absorb.mp3'),
  uiSelect('elevenlabs/ui_select.mp3'),
  uiConfirm('elevenlabs/ui_confirm.mp3'),
  uiVolumePreview('elevenlabs/ui_volume_preview.mp3'),
  gameOver('elevenlabs/game_over.wav');

  final String assetPath;

  const GameSound(this.assetPath);

  double get volumeMultiplier => switch (this) {
    GameSound.bonusCollect => 1.3,
    GameSound.energyShardAbsorb || GameSound.experienceShardAbsorb => 0.6,
    GameSound.uiConfirm || GameSound.uiVolumePreview => 0.72,
    _ => 1.0,
  };
}

enum GameMusic {
  mainLoop('gemini_bgm/quick_draw_loop.mp3'),
  homeLoop('gemini_bgm/home_peaceful_loop_lyria3_pro.mp3');

  final String assetPath;

  const GameMusic(this.assetPath);
}

class SlashDamageRoll {
  final int damage;
  final bool isCritical;

  const SlashDamageRoll({required this.damage, required this.isCritical});
}
