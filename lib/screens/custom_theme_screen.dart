import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/hearts_themes.dart';
import '../widgets/card_table.dart';

/// Custom theme creator (Pro): tune the table's material colors.
class CustomThemeScreen extends StatefulWidget {
  final HeartsAudio audio;
  final HeartsSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() =>
      _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  final _labels = {
    'felt': 'Felt',
    'feltDark': 'Felt shadow',
    'rail': 'Wood rail',
    'railDark': 'Rail shadow',
    'accent': 'Brass accent',
    'accentLight': 'Accent highlight',
    'ivory': 'Text ivory',
    'redSuit': 'Red suits',
    'blackSuit': 'Black suits',
  };

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

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    // Preview with the custom theme live.
    final preview = settings.customTheme;
    return Scaffold(
      body: FeltTheme(
        theme: preview,
        child: FeltBackdrop(
          theme: preview,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back,
                            color: preview.ivory),
                        onPressed: () {
                          widget.audio.click();
                          Navigator.of(context).pop();
                        },
                      ),
                      Text('Custom theme 🎨',
                          style: TextStyle(
                              color: preview.ivory,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          widget.audio.click();
                          settings.resetCustomColors();
                        },
                        child: Text('Reset',
                            style: TextStyle(
                                color: preview.accentLight)),
                      ),
                    ],
                  ),
                ),
                // Live preview strip: mini felt + card sample.
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: preview.accent
                            .withValues(alpha: 0.5)),
                    color: Colors.black
                        .withValues(alpha: 0.25),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      PlayingCard(
                        card: 3 * 13 + 12, // A♥
                        theme: preview,
                        style: HeartsThemes.cardStyles
                            .first,
                        width: 56,
                      ),
                      const SizedBox(width: 14),
                      PlayingCard(
                        card: 2 * 13 + 10, // Q♠
                        theme: preview,
                        style: HeartsThemes.cardStyles
                            .first,
                        width: 56,
                      ),
                      const SizedBox(width: 14),
                      PlayingCard(
                        card: 0,
                        theme: preview,
                        style: HeartsThemes.cardStyles
                            .first,
                        width: 56,
                        faceUp: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        20, 8, 20, 24),
                    children: [
                      for (final key in _labels.keys)
                        _ColorRow(
                          preview: preview,
                          label: _labels[key]!,
                          value: Color(settings
                              .customColors[key]!),
                          onPick: (c) => settings
                              .setCustomColor(key, c),
                        ),
                      const SizedBox(height: 12),
                      Center(
                        child: FeltButton(
                          label: 'Use this theme',
                          onPressed: () {
                            widget.audio.click();
                            settings.setTheme('custom');
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ],
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

class _ColorRow extends StatelessWidget {
  final HeartsThemeDef preview;
  final String label;
  final Color value;
  final ValueChanged<int> onPick;
  const _ColorRow(
      {required this.preview,
      required this.label,
      required this.value,
      required this.onPick});

  static const _palette = [
    0xFF1E5B3A,
    0xFF0F6E4E,
    0xFF1F3A5F,
    0xFF6E1F2E,
    0xFF3E4A54,
    0xFF5A6234,
    0xFF2E2E34,
    0xFFD8CFB8,
    0xFF5C3A21,
    0xFF4A2E18,
    0xFFC9A227,
    0xFFE8CE7A,
    0xFFF5EFE0,
    0xFFB3122E,
    0xFF1A1A22,
    0xFF7E2A22,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: value,
                  border: Border.all(
                      color: preview.ivory
                          .withValues(alpha: 0.4)),
                ),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: preview.ivory,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _palette)
                GestureDetector(
                  onTap: () => onPick(c),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(c),
                      border: Border.all(
                        color: value.value == c
                            ? preview.accentLight
                            : Colors.white24,
                        width:
                            value.value == c ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
