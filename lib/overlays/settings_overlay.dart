import 'package:flutter/material.dart';
import '../game/quick_draw_game.dart';

class SettingsIconButton extends StatelessWidget {
  final QuickDrawGame game;

  const SettingsIconButton({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: game.text.settings,
        child: IconButton(
          key: const ValueKey('settings-button'),
          onPressed: game.openSettings,
          icon: const Icon(Icons.settings),
          color: Colors.white,
          iconSize: 30,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF05060A).withValues(alpha: 0.58),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
            fixedSize: const Size(56, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsOverlay extends StatefulWidget {
  final QuickDrawGame game;

  const SettingsOverlay({super.key, required this.game});

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
  void _setMasterVolume(double value) {
    setState(() {
      widget.game.setMasterVolume(value);
      widget.game.previewUiVolume();
    });
  }

  void _setBgmVolume(double value) {
    setState(() {
      widget.game.setBgmVolume(value);
      widget.game.previewUiVolume();
    });
  }

  void _setSfxVolume(double value) {
    setState(() {
      widget.game.setSfxVolume(value);
      widget.game.previewUiVolume();
    });
  }

  void _setLanguage(GameLanguage value) {
    setState(() {
      widget.game.playSound(GameSound.uiSelect);
      widget.game.setLanguage(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.game.text;
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.62),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 22),
                  padding: const EdgeInsets.fromLTRB(40, 34, 40, 40),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101322).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF00FFCC).withValues(alpha: 0.34),
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.settings,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('settings-mute-button'),
                            tooltip: widget.game.isMuted
                                ? (t.isKo ? '음소거 해제' : 'Unmute')
                                : (t.isKo ? '음소거' : 'Mute'),
                            onPressed: () {
                              setState(() {
                                widget.game.toggleMute();
                              });
                            },
                            icon: Icon(
                              widget.game.isMuted
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                            ),
                            iconSize: 30,
                            color: widget.game.isMuted
                                ? const Color(0xFFFF2D55)
                                : const Color(0xFF00FFCC),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            key: const ValueKey('settings-close-button'),
                            tooltip: t.close,
                            onPressed: widget.game.closeSettings,
                            icon: const Icon(Icons.close),
                            iconSize: 32,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _VolumeSlider(
                        key: const ValueKey('master-volume-slider'),
                        label: t.master,
                        value: widget.game.masterVolume,
                        accentColor: const Color(0xFF00FFCC),
                        onChanged: _setMasterVolume,
                      ),
                      const SizedBox(height: 24),
                      _VolumeSlider(
                        key: const ValueKey('bgm-volume-slider'),
                        label: t.bgm,
                        value: widget.game.bgmVolume,
                        accentColor: const Color(0xFFA29BFE),
                        onChanged: _setBgmVolume,
                      ),
                      const SizedBox(height: 24),
                      _VolumeSlider(
                        key: const ValueKey('sfx-volume-slider'),
                        label: t.sfx,
                        value: widget.game.sfxVolume,
                        accentColor: const Color(0xFFFFD166),
                        onChanged: _setSfxVolume,
                      ),
                      const SizedBox(height: 28),
                      _LanguageSelector(
                        label: t.languageLabel,
                        koreanLabel: t.korean,
                        englishLabel: t.english,
                        value: widget.game.language,
                        onChanged: _setLanguage,
                      ),
                      const SizedBox(height: 32),
                      OutlinedButton.icon(
                        key: const ValueKey('settings-home-button'),
                        onPressed: widget.game.returnHomeFromSettings,
                        icon: const Icon(Icons.home, size: 26),
                        label: Text(t.home),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                          side: BorderSide(
                            color: const Color(
                              0xFFFF2D55,
                            ).withValues(alpha: 0.78),
                            width: 1.6,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color accentColor;
  final ValueChanged<double> onChanged;

  const _VolumeSlider({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: accentColor,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accentColor,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
            thumbColor: Colors.white,
            overlayColor: accentColor.withValues(alpha: 0.18),
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          ),
          child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
        ),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  final String label;
  final String koreanLabel;
  final String englishLabel;
  final GameLanguage value;
  final ValueChanged<GameLanguage> onChanged;

  const _LanguageSelector({
    required this.label,
    required this.koreanLabel,
    required this.englishLabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: Color(0xFF00FFCC),
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<GameLanguage>(
          segments: [
            ButtonSegment<GameLanguage>(
              value: GameLanguage.ko,
              label: Text(koreanLabel),
            ),
            ButtonSegment<GameLanguage>(
              value: GameLanguage.en,
              label: Text(englishLabel),
            ),
          ],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
          style: ButtonStyle(
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.black
                  : Colors.white,
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Color(0xFF00FFCC)
                  : const Color(0xFF05060A),
            ),
            side: WidgetStateProperty.all(
              BorderSide(
                color: const Color(0xFF00FFCC).withValues(alpha: 0.42),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
