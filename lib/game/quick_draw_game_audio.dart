part of 'quick_draw_game.dart';

extension QuickDrawGameAudio on QuickDrawGame {
  void playSound(GameSound sound) {
    lastRequestedSoundForTest = sound;
    if (!_canUseAudio) {
      return;
    }
    async_timer.unawaited(playSoundImpl(sound));
  }

  Future<void> playSoundImpl(GameSound sound) async {
    final volume = effectiveSfxVolumeFor(sound);
    if (html_audio.supportsHtmlAudio) {
      html_audio.playSfx(sound.assetPath, volume);
      return;
    }
    try {
      await initializeAudio();
      final pool = await soundPoolFor(sound);
      await pool.start(volume: volume);
    } catch (_) {
      _soundPools.remove(sound);
      // Audio should never block gameplay or tests.
    }
  }

  Future<AudioPool> soundPoolFor(GameSound sound) {
    return _soundPools.putIfAbsent(sound, () => createSoundPool(sound));
  }

  Future<AudioPool> createSoundPool(GameSound sound) {
    return FlameAudio.createPool(sound.assetPath, minPlayers: 1, maxPlayers: 4);
  }

  Future<void> initializeAudio() {
    return _audioInitialization ??= doInitializeAudio();
  }

  Future<void> doInitializeAudio() async {
    await FlameAudio.bgm.initialize();
    await FlameAudio.audioCache.loadAll([
      ...GameSound.values.map((sound) => sound.assetPath),
      ...GameMusic.values.map((music) => music.assetPath),
    ]);
  }

  void setMasterVolume(double value) {
    masterVolume = value.clamp(0.0, 1.0);
    applyBgmVolume();
  }

  void setBgmVolume(double value) {
    bgmVolume = value.clamp(0.0, 1.0);
    applyBgmVolume();
  }

  void setSfxVolume(double value) {
    sfxVolume = value.clamp(0.0, 1.0);
  }

  void previewUiVolume() {
    playSound(GameSound.uiVolumePreview);
  }

  void startBackgroundMusic() {
    playBgmTrack(GameMusic.mainLoop);
  }

  void startHomeBgm() {
    playBgmTrack(GameMusic.homeLoop);
  }

  void stopHomeBgm() {
    stopBgmTrack();
  }

  void playBgmTrack(GameMusic track) {
    if (!_canUseAudio) {
      return;
    }
    if (_bgmPlayingTrack == track && _currentBgmTrack == track) {
      return;
    }
    _currentBgmTrack = track;
    async_timer.unawaited(doPlayBgmTrack(track));
  }

  Future<void> doPlayBgmTrack(GameMusic track) async {
    if (html_audio.supportsHtmlAudio) {
      try {
        await html_audio.playBgm(track.assetPath, effectiveBgmVolume);
        _bgmPlayingTrack = track;
      } catch (_) {
        _bgmPlayingTrack = null;
      }
      return;
    }
    try {
      await initializeAudio();
      if (_currentBgmTrack != track) return;
      await FlameAudio.bgm.play(track.assetPath, volume: effectiveBgmVolume);
      _bgmPlayingTrack = track;
    } catch (_) {
      _audioInitialization = null;
      _bgmPlayingTrack = null;
      // Music should never block gameplay or tests.
    }
  }

  void applyBgmVolume() {
    if (html_audio.supportsHtmlAudio) {
      html_audio.setBgmVolume(effectiveBgmVolume);
      return;
    }
    if (!_canUseAudio) {
      return;
    }
    async_timer.unawaited(setBgmPlayerVolume());
  }

  Future<void> setBgmPlayerVolume() async {
    try {
      await FlameAudio.bgm.audioPlayer.setVolume(effectiveBgmVolume);
    } catch (_) {
      // Audio should never block gameplay or tests.
    }
  }

  void stopBackgroundMusic() {
    stopBgmTrack();
  }

  void stopBgmTrack() {
    _currentBgmTrack = null;
    _bgmPlayingTrack = null;
    if (html_audio.supportsHtmlAudio) {
      html_audio.stopBgm();
      return;
    }
    if (!_canUseAudio) {
      return;
    }
    async_timer.unawaited(FlameAudio.bgm.stop());
  }

  void toggleMute() {
    if (masterVolume > 0.0) {
      _preMuteMasterVolume = masterVolume;
      setMasterVolume(0.0);
    } else {
      setMasterVolume(_preMuteMasterVolume > 0.0 ? _preMuteMasterVolume : 1.0);
    }
  }
}
