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
                        isMuted: widget.game.masterMuted,
                        onChanged: _setMasterVolume,
                        onMuteToggled: () {
                          setState(() {
                            widget.game.toggleMute();
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      _VolumeSlider(
                        key: const ValueKey('bgm-volume-slider'),
                        label: t.bgm,
                        value: widget.game.bgmVolume,
                        accentColor: const Color(0xFFA29BFE),
                        isMuted: widget.game.bgmMuted,
                        onChanged: _setBgmVolume,
                        onMuteToggled: () {
                          setState(() {
                            widget.game.toggleBgmMute();
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      _VolumeSlider(
                        key: const ValueKey('sfx-volume-slider'),
                        label: t.sfx,
                        value: widget.game.sfxVolume,
                        accentColor: const Color(0xFFFFD166),
                        isMuted: widget.game.sfxMuted,
                        onChanged: _setSfxVolume,
                        onMuteToggled: () {
                          setState(() {
                            widget.game.toggleSfxMute();
                          });
                        },
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
  final bool isMuted;
  final ValueChanged<double> onChanged;
  final VoidCallback onMuteToggled;

  const _VolumeSlider({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.isMuted,
    required this.onChanged,
    required this.onMuteToggled,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
              color: isMuted ? const Color(0xFFFF2D55) : accentColor,
              onPressed: onMuteToggled,
              iconSize: 22,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: isMuted ? Colors.white54 : accentColor,
                ),
              ),
            ),
            Text(
              isMuted ? 'Muted' : '$percent%',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isMuted ? Colors.white54 : Colors.white,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: isMuted ? Colors.white24 : accentColor,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
            thumbColor: isMuted ? Colors.white54 : Colors.white,
            overlayColor: accentColor.withValues(alpha: 0.18),
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: isMuted ? null : onChanged,
          ),
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
