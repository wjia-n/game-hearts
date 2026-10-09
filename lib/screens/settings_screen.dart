import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/hearts_themes.dart';
import '../widgets/card_table.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.hearts';

/// Settings: audio controls, lifetime stats, share, credits.
class SettingsScreen extends StatefulWidget {
  final HeartsAudio audio;
  final HeartsSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.settings.removeListener(_refresh);
    super.dispose();
  }

  void _applyAudio() {
    widget.audio.configure(
      musicOn: widget.settings.musicOn,
      sfxOn: widget.settings.sfxOn,
      volume: widget.settings.volume,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final theme = HeartsThemes.byId(
      settings.themeId,
      custom: settings.customTheme,
    );
    return Scaffold(
      body: FeltTheme(
        theme: theme,
        child: FeltBackdrop(
          theme: theme,
          child: SafeArea(
            child: ListView(
              padding:
                  const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: theme.ivory),
                      onPressed: () {
                        widget.audio.click();
                        Navigator.of(context).pop();
                      },
                    ),
                    Text('Settings',
                        style: TextStyle(
                            color: theme.ivory,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 12),
                _Card(
                  theme: theme,
                  title: 'Sound',
                  child: Column(
                    children: [
                      _Toggle(
                        theme: theme,
                        label: 'Music',
                        value: settings.musicOn,
                        onChanged: (v) {
                          settings.setMusic(v);
                          _applyAudio();
                          if (v) {
                            widget.audio
                                .startMenuMusic();
                          }
                        },
                      ),
                      _Toggle(
                        theme: theme,
                        label: 'Sound effects',
                        value: settings.sfxOn,
                        onChanged: (v) {
                          settings.setSfx(v);
                          _applyAudio();
                        },
                      ),
                      Row(
                        children: [
                          Text('Volume',
                              style: TextStyle(
                                  color: theme.ivory)),
                          Expanded(
                            child: Slider(
                              value: settings.volume,
                              activeColor: theme.accent,
                              onChanged: (v) {
                                settings.setVolume(v);
                                _applyAudio();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Card(
                  theme: theme,
                  title: 'Your table stats',
                  child: Column(
                    children: [
                      _Stat(theme, 'Matches played',
                          '${settings.gamesPlayed}'),
                      _Stat(theme, 'Matches won',
                          '${settings.wins}'),
                      _Stat(
                          theme,
                          'Best winning total',
                          settings.bestScore == 0
                              ? '—'
                              : '${settings.bestScore} pts'),
                      _Stat(theme, 'Moons shot 🌙',
                          '${settings.moonsShot}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Card(
                  theme: theme,
                  title: 'About',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/wajiha_logo.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Hearts by WAJIHA — a classic card game, hand-crafted with love. 100% free, no ads.',
                              style: TextStyle(
                                  color: theme.ivory,
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FeltButton(
                        label: 'Share Hearts',
                        icon: Icons.share,
                        primary: false,
                        onPressed: () {
                          widget.audio.click();
                          SharePlus.instance.share(
                            ShareParams(
                              text:
                                  '♥️ Hearts by WAJIHA — dodge the hearts, ditch the queen, shoot the moon! $_storeUrl',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text('v2.0.0 · com.gameswajiha.hearts',
                      style: TextStyle(
                          color: theme.ivoryDim,
                          fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final HeartsThemeDef theme;
  final String title;
  final Widget child;
  const _Card(
      {required this.theme,
      required this.title,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(
            color: theme.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: theme.accentLight,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final HeartsThemeDef theme;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle(
      {required this.theme,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: TextStyle(color: theme.ivory))),
        Switch(
            value: value,
            activeColor: theme.accent,
            onChanged: onChanged),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final HeartsThemeDef theme;
  final String label;
  final String value;
  const _Stat(this.theme, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(color: theme.ivory))),
          Text(value,
              style: TextStyle(
                  color: theme.accentLight,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
