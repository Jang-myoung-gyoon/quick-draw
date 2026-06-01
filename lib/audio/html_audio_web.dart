// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

bool get supportsHtmlAudio => true;

html.AudioElement? _bgm;

String _assetUrl(String assetPath) {
  return Uri.base.resolve('assets/assets/audio/$assetPath').toString();
}

void playSfx(String assetPath, double volume) {
  final audio = html.AudioElement(_assetUrl(assetPath))
    ..volume = volume.clamp(0.0, 1.0)
    ..preload = 'auto';
  audio.play().catchError((_) {});
}

void playBgm(String assetPath, double volume) {
  final audio = _bgm ??= html.AudioElement(_assetUrl(assetPath))
    ..loop = true
    ..preload = 'auto';
  audio
    ..src = _assetUrl(assetPath)
    ..loop = true
    ..volume = volume.clamp(0.0, 1.0);
  audio.play().catchError((_) {});
}

void setBgmVolume(double volume) {
  _bgm?.volume = volume.clamp(0.0, 1.0);
}

void stopBgm() {
  final audio = _bgm;
  if (audio == null) {
    return;
  }
  audio.pause();
  audio.currentTime = 0;
}
