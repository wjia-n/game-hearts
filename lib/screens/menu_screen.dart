import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/hearts_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/hearts_themes.dart';
import '../widgets/card_table.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';
import 'custom_theme_screen.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.hearts';
const _difficultyNames = ['Easy', 'Medium', 'Hard'];

/// Main menu: mode setup (vs bots / pass-and-play), difficulty, seats,
/// theme + card-style pickers, Pro, settings, share, how-to-play.
class MenuScreen extends StatefulWidget {
  final HeartsAudio audio;
  final HeartsSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late final HeartsStore _store;

  @override
  void initState() {
    super.initState();
    _store = HeartsStore();
    _store.init();
    _store.proPurchased.addListener(_onProChanged);
    widget.settings.addListener(_refresh);
    widget.audio.startMenuMusic();
  }

  void _onProChanged() {
    if (_store.proPurchased.value) {
      widget.settings.setPro(true);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _store.proPurchased.removeListener(_onProChanged);
    widget.settings.removeListener(_refresh);
    _store.dispose();
    super.dispose();
  }

  void _startGame() {
    widget.audio.click();
    widget.audio.startGameMusic();
    final settings = widget.settings;
    final players = [
      for (int i = 0; i < 4; i++)
        HeartsPlayer(
          name: settings.playerNames[i],
          isBot: settings.botSeats.contains(i),
        ),
    ];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: settings,
          players: players,
          difficulty: BotDifficulty.values[settings.difficulty],
          store: _store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final theme = HeartsThemes.byId(
      settings.themeId,
      custom: settings.customTheme,
    );
    final humans = 4 - settings.botSeats.length;
    return Scaffold(
      body: FeltTheme(
        theme: theme,
        child: FeltBackdrop(
          theme: theme,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset('assets/hearts_logo.png',
                          width: 56, height: 56, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hearts',
                              style: TextStyle(
                                  color: theme.ivory,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5)),
                          Text(
                              'Dodge the hearts · ditch the queen · shoot the moon',
                              style: TextStyle(
                                  color: theme.ivoryDim, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (!settings.isPro)
                      _ProBadge(
                          onTap: () {
                            widget.audio.click();
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ProScreen(
                                    audio: widget.audio,
                                    settings: settings,
                                    store: _store)));
                          }),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  theme: theme,
                  title: 'Who\'s at the table?',
                  child: Column(
                    children: [
                      for (int i = 0; i < 4; i++)
                        _SeatRow(
                          theme: theme,
                          index: i,
                          name: settings.playerNames[i],
                          isBot: settings.botSeats.contains(i),
                          onToggleBot: () {
                            final seats =
                                List<int>.of(settings.botSeats);
                            if (seats.contains(i)) {
                              seats.remove(i);
                            } else if (seats.length < 3) {
                              seats.add(i);
                            } else {
                              return; // need at least one human
                            }
                            widget.audio.click();
                            settings.setSetup(
                                botSeats: seats,
                                difficulty: settings.difficulty);
                          },
                          onRename: (v) => settings.setPlayerName(i, v),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        humans == 1
                            ? 'Solo vs 3 bots'
                            : '$humans humans pass-and-play + ${4 - humans} bots',
                        style: TextStyle(
                            color: theme.ivoryDim, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  theme: theme,
                  title: 'Bot difficulty',
                  child: Row(
                    children: [
                      for (int d = 0; d < 3; d++)
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: _ChoiceChip(
                              theme: theme,
                              label: _difficultyNames[d] +
                                  (d == 2 && !settings.isPro ? ' 🔒' : ''),
                              selected: settings.difficulty == d,
                              onTap: (d == 2 && !settings.isPro)
                                  ? () => _openPro()
                                  : () {
                                      widget.audio.click();
                                      settings.setSetup(
                                          botSeats: settings.botSeats,
                                          difficulty: d);
                                    },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  theme: theme,
                  title: 'Table theme',
                  child: _ThemeGrid(
                    theme: theme,
                    settings: settings,
                    audio: widget.audio,
                    onLocked: _openPro,
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  theme: theme,
                  title: 'Card style',
                  child: _CardStyleGrid(
                    theme: theme,
                    settings: settings,
                    audio: widget.audio,
                    onLocked: _openPro,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: FeltButton(
                    label: '♥  Deal Me In  ♥',
                    icon: Icons.play_arrow,
                    onPressed: _startGame,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _IconBtn(
                        theme: theme,
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () {
                          widget.audio.click();
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => SettingsScreen(
                                  audio: widget.audio,
                                  settings: settings)));
                        }),
                    _IconBtn(
                        theme: theme,
                        icon: Icons.help_outline,
                        label: 'How to play',
                        onTap: () {
                          widget.audio.click();
                          _showHowToPlay(theme);
                        }),
                    _IconBtn(
                        theme: theme,
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () {
                          widget.audio.click();
                          SharePlus.instance.share(ShareParams(
                            text:
                                '♥️ Hearts by WAJIHA — dodge the hearts, ditch the queen, shoot the moon! $_storeUrl',
                          ));
                        }),
                    _IconBtn(
                        theme: theme,
                        icon: Icons.star_rate,
                        label: 'Rate',
                        onTap: () async {
                          widget.audio.click();
                          try {
                            if (await InAppReview.instance.isAvailable()) {
                              await InAppReview.instance.requestReview();
                            }
                          } catch (_) {}
                        }),
                  ],
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    'Lowest score wins · first to 100 ends the match',
                    style:
                        TextStyle(color: theme.ivoryDim, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPro() {
    widget.audio.click();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProScreen(
            audio: widget.audio,
            settings: widget.settings,
            store: _store)));
  }

  void _showHowToPlay(HeartsThemeDef theme) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.railDark,
        title: Text('How to play',
            style: TextStyle(color: theme.ivory)),
        content: SingleChildScrollView(
          child: Text(
            '• 4 players, 13 cards each. Avoid taking HEARTS (1 pt each) and the QUEEN OF SPADES (13 pts!).\n\n'
            '• Before each hand, pass 3 cards — left, right, across, then a hold hand with no passing.\n\n'
            '• The 2♣ always leads the first trick. You must follow suit if you can.\n\n'
            '• No points may be played on the first trick.\n\n'
            '• Hearts cannot be led until broken (or you hold only hearts).\n\n'
            '• Highest card of the led suit takes the trick and leads next.\n\n'
            '• Take ALL 26 points to SHOOT THE MOON 🌙 — you score 0, everyone else gets 26!\n\n'
            '• Lowest total wins. First player to 100 ends the match.',
            style: TextStyle(color: theme.ivory, fontSize: 14, height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Got it',
                style: TextStyle(color: theme.accentLight)),
          ),
        ],
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _ProBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFFE8CE7A), Color(0xFFC9A227)],
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: const Text('PRO',
            style: TextStyle(
                color: Color(0xFF2E1C0F),
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 1)),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final HeartsThemeDef theme;
  final String title;
  final Widget child;
  const _SectionCard(
      {required this.theme, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(
            color: theme.accent.withValues(alpha: 0.35), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(0, 4),
              blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: theme.accentLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SeatRow extends StatefulWidget {
  final HeartsThemeDef theme;
  final int index;
  final String name;
  final bool isBot;
  final VoidCallback onToggleBot;
  final ValueChanged<String> onRename;

  const _SeatRow({
    required this.theme,
    required this.index,
    required this.name,
    required this.isBot,
    required this.onToggleBot,
    required this.onRename,
  });

  @override
  State<_SeatRow> createState() => _SeatRowState();
}

class _SeatRowState extends State<_SeatRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.name);
  }

  @override
  void didUpdateWidget(covariant _SeatRow old) {
    super.didUpdateWidget(old);
    // Sync external name changes (defaults/migration) without clobbering
    // text the user is typing right now.
    if (old.name != widget.name && _ctrl.text != widget.name) {
      _ctrl.text = widget.name;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.seatColors[widget.index]
                  .withValues(alpha: 0.25),
              border: Border.all(
                  color: theme.seatColors[widget.index]),
            ),
            child: Text('${widget.index + 1}',
                style: TextStyle(
                    color: theme.ivory,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: TextStyle(color: theme.ivory, fontSize: 14),
              maxLength: 16,
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                filled: true,
                fillColor:
                    Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              // Save on EVERY keystroke into the single JSON names string —
              // never lost if the app is killed mid-edit.
              onChanged: widget.onRename,
              onSubmitted: widget.onRename,
              onEditingComplete: () => widget.onRename(_ctrl.text),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onToggleBot,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.isBot
                    ? theme.accent.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.4),
                border: Border.all(
                    color: widget.isBot
                        ? theme.accent
                        : theme.ivory.withValues(alpha: 0.25)),
              ),
              child: Text(widget.isBot ? '🤖 Bot' : '🧑 Human',
                  style: TextStyle(
                      color: theme.ivory,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final HeartsThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip(
      {required this.theme,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? theme.accent.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.35),
          border: Border.all(
              color: selected
                  ? theme.accent
                  : theme.ivory.withValues(alpha: 0.2),
              width: selected ? 2 : 1),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: theme.ivory,
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

class _ThemeGrid extends StatelessWidget {
  final HeartsThemeDef theme;
  final HeartsSettings settings;
  final HeartsAudio audio;
  final VoidCallback onLocked;
  const _ThemeGrid(
      {required this.theme,
      required this.settings,
      required this.audio,
      required this.onLocked});

  @override
  Widget build(BuildContext context) {
    final items = [
      ...HeartsThemes.all,
      if (settings.isPro) settings.customTheme,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in items)
          _Swatch(
            theme: theme,
            colors: [t.felt, t.rail, t.accent],
            label: t.name,
            locked: HeartsThemes.isProTheme(t.id) &&
                !settings.isPro,
            selected: settings.themeId == t.id,
            onTap: () {
              if (HeartsThemes.isProTheme(t.id) &&
                  !settings.isPro) {
                onLocked();
                return;
              }
              audio.click();
              settings.setTheme(t.id);
            },
          ),
        _Swatch(
          theme: theme,
          colors: [
            Color(settings.customColors['felt']!),
            Color(settings.customColors['rail']!),
            Color(settings.customColors['accent']!),
          ],
          label: 'Custom 🎨',
          locked: !settings.isPro,
          selected: settings.themeId == 'custom',
          onTap: () {
            if (!settings.isPro) {
              onLocked();
              return;
            }
            audio.click();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CustomThemeScreen(
                    audio: audio, settings: settings)));
          },
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final HeartsThemeDef theme;
  final List<Color> colors;
  final String label;
  final bool locked;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch(
      {required this.theme,
      required this.colors,
      required this.label,
      required this.locked,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected
                      ? theme.accentLight
                      : theme.ivory.withValues(alpha: 0.2),
                  width: selected ? 3 : 1),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 5,
                    offset: const Offset(0, 2))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  for (final c in colors)
                    Expanded(child: Container(color: c)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 64,
            child: Text(
              locked ? '$label 🔒' : label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: theme.ivoryDim, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardStyleGrid extends StatelessWidget {
  final HeartsThemeDef theme;
  final HeartsSettings settings;
  final HeartsAudio audio;
  final VoidCallback onLocked;
  const _CardStyleGrid(
      {required this.theme,
      required this.settings,
      required this.audio,
      required this.onLocked});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in HeartsThemes.cardStyles)
          _Swatch(
            theme: theme,
            colors: [s.front, s.back, s.backPattern],
            label: s.name,
            locked: HeartsThemes.isProCardStyle(s.id) &&
                !settings.isPro,
            selected: settings.cardStyleId == s.id,
            onTap: () {
              if (HeartsThemes.isProCardStyle(s.id) &&
                  !settings.isPro) {
                onLocked();
                return;
              }
              audio.click();
              settings.setCardStyle(s.id);
            },
          ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final HeartsThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.theme,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Icon(icon, color: theme.accentLight, size: 24),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: theme.ivoryDim, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
