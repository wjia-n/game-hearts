import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import '../engine/hearts_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/hearts_themes.dart';
import '../widgets/card_table.dart';

/// The card table: every seat has its own plate, the active seat highlights,
/// AI turns animate visibly with narration, and nothing ever auto-plays
/// silently. Pass-and-play shows a "pass the phone" cover between humans.
class GameScreen extends StatefulWidget {
  final HeartsAudio audio;
  final HeartsSettings settings;
  final List<HeartsPlayer> players;
  final BotDifficulty difficulty;
  final HeartsStore store;

  const GameScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.players,
    required this.difficulty,
    required this.store,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver {
  late final HeartsEngine _engine;
  int _viewSeat = 0; // whose hand is shown at the bottom
  int _revealedSeat = -1; // pass-and-play cover tracking
  bool _matchDialogShown = false;
  bool _reviewAsked = false;

  HeartsThemeDef get _theme => HeartsThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );
  CardStyleDef get _cardStyle =>
      HeartsThemes.cardStyleById(widget.settings.cardStyleId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = HeartsEngine(
      players: widget.players,
      difficulty: widget.difficulty,
    );
    _engine.onEvent = _onEngineEvent;
    _engine.addListener(_onEngineChanged);
    _viewSeat = _firstHumanSeat();
    _revealedSeat = _viewSeat;
    // Defer start until after first frame so the table is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _engine.startMatch();
    });
  }

  int _firstHumanSeat() {
    for (int i = 0; i < 4; i++) {
      if (!widget.players[i].isBot) return i;
    }
    return 0;
  }

  void _onEngineEvent(String event) {
    final a = widget.audio;
    switch (event) {
      case 'shuffle':
        a.shuffle();
        break;
      case 'deal':
        a.deal();
        break;
      case 'card_place':
        a.cardPlace();
        break;
      case 'trick_win':
        a.trickWin();
        break;
      case 'hearts':
        a.heartsHit();
        break;
      case 'queen':
        a.queenSpades();
        break;
      case 'moon':
        a.shootMoon();
        break;
      case 'invalid':
        a.invalid();
        break;
      case 'match_end':
        _onMatchEnd();
        break;
      default:
        break;
    }
  }

  void _onEngineChanged() {
    if (!mounted) return;
    // In pass-and-play, track whose turn it is for the cover screen.
    final e = _engine;
    if (e.awaitingHuman) {
      final seat = e.phase == HeartsPhase.passing
          ? e.passSeat
          : e.currentSeat;
      if (seat >= 0 && _viewSeat != seat) _viewSeat = seat;
    }
    setState(() {});
  }

  void _onMatchEnd() {
    final humanWon =
        _engine.winners.any((s) => !widget.players[s].isBot);
    final bestHuman = [
      for (int s = 0; s < 4; s++)
        if (!widget.players[s].isBot) _engine.finalTotals[s]
    ];
    widget.settings.recordGame(
      humanWon: humanWon,
      bestHumanTotal:
          bestHuman.isEmpty ? 999 : bestHuman.reduce((a, b) => a < b ? a : b),
      humanShotMoon: _engine.moonShooter != null &&
          !widget.players[_engine.moonShooter!].isBot,
    );
    if (humanWon) {
      widget.audio.win();
    } else {
      widget.audio.lose();
    }
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && !_matchDialogShown) {
        _matchDialogShown = true;
        _showMatchDialog(humanWon);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _engine.setPaused(true);
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
      if (!_dialogOpen) _engine.setPaused(false);
    }
  }

  bool _dialogOpen = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- actions
  void _onCardTap(int card) {
    final e = _engine;
    if (e.phase == HeartsPhase.passing && e.awaitingHuman) {
      widget.audio.click();
      e.togglePassCard(card);
      return;
    }
    if (e.phase == HeartsPhase.awaitingPlay && e.awaitingHuman) {
      if (e.currentSeat != _viewSeat) return;
      final ok = e.playCard(e.currentSeat, card);
      if (ok) widget.audio.cardPlace();
    }
  }

  void _confirmPass() {
    widget.audio.click();
    _engine.confirmPass();
  }

  void _openPause() {
    widget.audio.click();
    _engine.setPaused(true);
    _dialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PauseDialog(
        theme: _theme,
        audio: widget.audio,
        settings: widget.settings,
        onResume: () {
          Navigator.of(context).pop();
          _dialogOpen = false;
          widget.audio.click();
          _engine.setPaused(false);
        },
        onRestart: () {
          Navigator.of(context).pop();
          _dialogOpen = false;
          widget.audio.click();
          _matchDialogShown = false;
          _engine.startMatch();
          _engine.setPaused(false);
        },
        onQuit: () {
          Navigator.of(context).pop();
          _dialogOpen = false;
          widget.audio.startMenuMusic();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    final e = _engine;
    final showCover = _needsCover();
    return Scaffold(
      body: FeltTheme(
        theme: theme,
        child: FeltBackdrop(
          theme: theme,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _TopBar(
                      theme: theme,
                      engine: e,
                      onPause: _openPause,
                    ),
                    Expanded(child: _TableArea(
                      theme: theme,
                      cardStyle: _cardStyle,
                      engine: e,
                      viewSeat: _viewSeat,
                    )),
                    _NarrationBar(theme: theme, text: e.narration),
                    _HandArea(
                      theme: theme,
                      cardStyle: _cardStyle,
                      engine: e,
                      viewSeat: _viewSeat,
                      onCardTap: showCover ? null : _onCardTap,
                      onConfirmPass: _confirmPass,
                      audio: widget.audio,
                    ),
                  ],
                ),
                if (showCover) _CoverScreen(
                  theme: theme,
                  name: widget.players[_viewSeat].name,
                  onReveal: () {
                    widget.audio.click();
                    setState(() => _revealedSeat = _viewSeat);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pass-and-play cover: hide hands whenever the device must change hands.
  bool _needsCover() {
    if (_humanSeats() < 2) return false;
    return _revealedSeat != _viewSeat && _engine.awaitingHuman;
  }

  int _humanSeats() => widget.players.where((p) => !p.isBot).length;

  void _showMatchDialog(bool humanWon) {
    final e = _engine;
    final theme = _theme;
    _dialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: theme.railDark,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
          humanWon ? '🏆 You win!' : 'Match over',
          style: TextStyle(color: theme.ivory),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.narration,
                style: TextStyle(
                    color: theme.accentLight,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (int s = 0; s < 4; s++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.seatColors[s],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.players[s].name}${e.winners.contains(s) ? ' 👑' : ''}',
                        style: TextStyle(color: theme.ivory),
                      ),
                    ),
                    Text('${e.finalTotals[s]} pts',
                        style: TextStyle(
                            color: theme.ivory,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _dialogOpen = false;
              widget.audio.startMenuMusic();
              Navigator.of(context).pop();
            },
            child: Text('Menu',
                style: TextStyle(color: theme.ivoryDim)),
          ),
          FeltButton(
            label: 'Play again',
            onPressed: () {
              Navigator.of(context).pop();
              _dialogOpen = false;
              widget.audio.click();
              _matchDialogShown = false;
              _engine.startMatch();
            },
          ),
        ],
      ),
    ).then((_) {
      _dialogOpen = false;
      // Sensible review moment: after a finished match, once per install.
      if (!_reviewAsked) {
        _reviewAsked = true;
        _maybeAskReview();
      }
    });
  }

  Future<void> _maybeAskReview() async {
    try {
      if (await InAppReview.instance.isAvailable()) {
        await InAppReview.instance.requestReview();
      }
    } catch (_) {
      // Not from Play / unavailable — stay silent, never crash.
    }
  }
}

// ---------------------------------------------------------------- top bar
class _TopBar extends StatelessWidget {
  final HeartsThemeDef theme;
  final HeartsEngine engine;
  final VoidCallback onPause;
  const _TopBar(
      {required this.theme, required this.engine, required this.onPause});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPause,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.45),
                border: Border.all(
                    color: theme.accent.withValues(alpha: 0.5)),
              ),
              child: Icon(Icons.pause,
                  color: theme.ivory, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  engine.phase == HeartsPhase.dealing
                      ? 'Dealing…'
                      : engine.phase == HeartsPhase.passing
                          ? 'Pass ${engine.passDirectionName} · Hand ${engine.handNumber + 1}'
                          : 'Hand ${engine.handNumber + 1} · Trick ${engine.trickNumber + 1}/13',
                  style: TextStyle(
                      color: theme.ivory,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                Text(
                  engine.heartsBroken
                      ? '♥ Hearts are broken'
                      : '♥ Hearts not broken',
                  style: TextStyle(
                      color: theme.ivoryDim, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.black.withValues(alpha: 0.45),
              border: Border.all(
                  color: theme.accent.withValues(alpha: 0.5)),
            ),
            child: Text(
              'Target ${engine.targetScore}',
              style: TextStyle(
                  color: theme.accentLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- table area
class _TableArea extends StatelessWidget {
  final HeartsThemeDef theme;
  final CardStyleDef cardStyle;
  final HeartsEngine engine;
  final int viewSeat;
  const _TableArea(
      {required this.theme,
      required this.cardStyle,
      required this.engine,
      required this.viewSeat});

  @override
  Widget build(BuildContext context) {
    // Seat geometry: 0 bottom, 1 left, 2 top, 3 right.
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        return Stack(
          children: [
            // Center: current trick.
            Center(child: _TrickCards(
              theme: theme,
              cardStyle: cardStyle,
              engine: engine,
            )),
            // Seat plates.
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: Center(
                  child: _plate(2, w)),
            ),
            Positioned(
              left: 4,
              top: h * 0.32,
              child: _plate(1, w),
            ),
            Positioned(
              right: 4,
              top: h * 0.32,
              child: _plate(3, w),
            ),
            Positioned(
              bottom: 2,
              left: 0,
              right: 0,
              child: Center(child: _plate(0, w)),
            ),
          ],
        );
      },
    );
  }

  Widget _plate(int seat, double w) {
    final e = engine;
    final active = e.phase == HeartsPhase.awaitingPlay &&
        e.currentSeat == seat;
    final passing =
        e.phase == HeartsPhase.passing && e.awaitingHuman;
    return SeatPlate(
      name: e.players[seat].name,
      color: theme.seatColors[seat],
      active: active || passing,
      isBot: e.players[seat].isBot,
      handCount: e.hands[seat].length,
      handPoints: e.handPoints[seat],
      total: e.scores[seat],
    );
  }
}

class _TrickCards extends StatelessWidget {
  final HeartsThemeDef theme;
  final CardStyleDef cardStyle;
  final HeartsEngine engine;
  const _TrickCards(
      {required this.theme,
      required this.cardStyle,
      required this.engine});

  @override
  Widget build(BuildContext context) {
    final trick = engine.trick;
    if (trick.isEmpty) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: theme.accent.withValues(alpha: 0.3), width: 2),
          color: Colors.black.withValues(alpha: 0.2),
        ),
        child: Center(
          child: Text('♥',
              style: TextStyle(
                  color:
                      theme.accent.withValues(alpha: 0.35),
                  fontSize: 40)),
        ),
      );
    }
    // 2x2 grid in play order with entrance animation.
    return SizedBox(
      width: 190,
      height: 210,
      child: Stack(
        children: [
          for (int i = 0; i < trick.length; i++)
            Positioned(
              left: 8 + (i % 2) * 92,
              top: 8 + (i ~/ 2) * 100,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(
                    'trick-${trick[i].seat}-${trick[i].card}'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration:
                    const Duration(milliseconds: 350),
                builder: (_, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, (1 - v) * 26),
                    child: Transform.scale(
                        scale: 0.7 + 0.3 * v, child: child),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.seatColors[trick[i].seat],
                      width: 2.5,
                    ),
                  ),
                  child: PlayingCard(
                    card: trick[i].card,
                    theme: theme,
                    style: cardStyle,
                    width: 76,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- narration
class _NarrationBar extends StatelessWidget {
  final HeartsThemeDef theme;
  final String text;
  const _NarrationBar({required this.theme, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withValues(alpha: 0.5),
        border: Border.all(
            color: theme.accent.withValues(alpha: 0.3)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Text(
          text,
          key: ValueKey(text),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: theme.ivory,
              fontSize: 13,
              fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ hand
class _HandArea extends StatelessWidget {
  final HeartsThemeDef theme;
  final CardStyleDef cardStyle;
  final HeartsEngine engine;
  final int viewSeat;
  final void Function(int card)? onCardTap;
  final VoidCallback onConfirmPass;
  final HeartsAudio audio;

  const _HandArea({
    required this.theme,
    required this.cardStyle,
    required this.engine,
    required this.viewSeat,
    required this.onCardTap,
    required this.onConfirmPass,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    final e = engine;
    final isPassTurn = e.phase == HeartsPhase.passing && e.awaitingHuman;
    final isPlayTurn =
        e.phase == HeartsPhase.awaitingPlay && e.awaitingHuman;
    final legal =
        isPlayTurn ? e.legalPlays(e.currentSeat) : const <int>[];
    final hand = e.hands[viewSeat];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border(
            top: BorderSide(
                color: theme.accent.withValues(alpha: 0.3))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPassTurn)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Select ${e.passSelected.length}/3 to pass ${e.passDirectionName}',
                    style: TextStyle(
                        color: theme.accentLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  FeltButton(
                    label: 'Pass ✓',
                    onPressed: e.passSelected.length == 3
                        ? onConfirmPass
                        : null,
                  ),
                ],
              ),
            ),
          if (e.phase == HeartsPhase.dealing)
            _DealProgress(theme: theme, engine: e)
          else if (hand.isEmpty)
            SizedBox(
              height: 92,
              child: Center(
                child: Text('Waiting for the deal…',
                    style: TextStyle(
                        color: theme.ivoryDim, fontSize: 13)),
              ),
            )
          else
            _HandFan(
              theme: theme,
              cardStyle: cardStyle,
              hand: hand,
              legal: legal,
              isPlayTurn: isPlayTurn && viewSeat == e.currentSeat,
              isPassTurn: isPassTurn,
              passSelected: e.passSelected,
              faceDown: onCardTap == null,
              onCardTap: onCardTap,
            ),
        ],
      ),
    );
  }
}

class _DealProgress extends StatelessWidget {
  final HeartsThemeDef theme;
  final HeartsEngine engine;
  const _DealProgress({required this.theme, required this.engine});

  @override
  Widget build(BuildContext context) {
    final dealt =
        engine.dealProgress.fold(0, (a, b) => a + b);
    return SizedBox(
      height: 92,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                value: dealt / 52,
                backgroundColor:
                    Colors.black.withValues(alpha: 0.4),
                color: theme.accent,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text('Dealing… $dealt/52',
                style: TextStyle(
                    color: theme.ivoryDim, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _HandFan extends StatelessWidget {
  final HeartsThemeDef theme;
  final CardStyleDef cardStyle;
  final List<int> hand;
  final List<int> legal;
  final bool isPlayTurn;
  final bool isPassTurn;
  final List<int> passSelected;
  final bool faceDown;
  final void Function(int card)? onCardTap;

  const _HandFan({
    required this.theme,
    required this.cardStyle,
    required this.hand,
    required this.legal,
    required this.isPlayTurn,
    required this.isPassTurn,
    required this.passSelected,
    required this.faceDown,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const cardW = 52.0;
        final n = hand.length;
        final maxW = box.maxWidth - 16;
        final step = n <= 1
            ? 0.0
            : (maxW - cardW) / (n - 1);
        final useStep = step.clamp(14.0, 52.0);
        final totalW = cardW + useStep * (n - 1);
        return SizedBox(
          height: 96,
          child: Center(
            child: SizedBox(
              width: totalW,
              height: 96,
              child: Stack(
                children: [
                  for (int i = 0; i < n; i++)
                    Positioned(
                      left: i * useStep,
                      top: _lift(hand[i]),
                      child: faceDown
                          ? PlayingCard(
                              card: hand[i],
                              theme: theme,
                              style: cardStyle,
                              width: cardW,
                              faceUp: false,
                            )
                          : PlayingCard(
                              card: hand[i],
                              theme: theme,
                              style: cardStyle,
                              width: cardW,
                              highlighted: isPassTurn &&
                                  passSelected
                                      .contains(hand[i]),
                              dimmed: (isPlayTurn &&
                                      !legal.contains(hand[i])) ||
                                  (isPassTurn &&
                                      passSelected.length >= 3 &&
                                      !passSelected
                                          .contains(hand[i])),
                              onTap: (isPlayTurn || isPassTurn) &&
                                      onCardTap != null
                                  ? () =>
                                      onCardTap!(hand[i])
                                  : null,
                            ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _lift(int card) {
    if (isPassTurn && passSelected.contains(card)) return 0;
    if (isPlayTurn && legal.contains(card)) return 0;
    return 14;
  }
}

// ----------------------------------------------------------------- cover
class _CoverScreen extends StatelessWidget {
  final HeartsThemeDef theme;
  final String name;
  final VoidCallback onReveal;
  const _CoverScreen(
      {required this.theme, required this.name, required this.onReveal});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: theme.feltDark,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🂠',
                  style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text('Pass the phone to',
                  style: TextStyle(
                      color: theme.ivoryDim, fontSize: 15)),
              const SizedBox(height: 6),
              Text(name,
                  style: TextStyle(
                      color: theme.ivory,
                      fontSize: 32,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              FeltButton(
                  label: 'I\'m $name — show my cards',
                  onPressed: onReveal),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- pause
class _PauseDialog extends StatelessWidget {
  final HeartsThemeDef theme;
  final HeartsAudio audio;
  final HeartsSettings settings;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _PauseDialog({
    required this.theme,
    required this.audio,
    required this.settings,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: theme.railDark,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: Text('Paused',
          style: TextStyle(color: theme.ivory)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleRow(
            theme: theme,
            label: 'Music',
            value: settings.musicOn,
            onChanged: (v) {
              settings.setMusic(v);
              audio.configure(
                  musicOn: settings.musicOn,
                  sfxOn: settings.sfxOn,
                  volume: settings.volume);
              if (v) audio.startGameMusic();
            },
          ),
          _ToggleRow(
            theme: theme,
            label: 'Sound effects',
            value: settings.sfxOn,
            onChanged: (v) {
              settings.setSfx(v);
              audio.configure(
                  musicOn: settings.musicOn,
                  sfxOn: settings.sfxOn,
                  volume: settings.volume);
            },
          ),
          Row(
            children: [
              Text('Volume',
                  style: TextStyle(color: theme.ivory)),
              Expanded(
                child: Slider(
                  value: settings.volume,
                  activeColor: theme.accent,
                  onChanged: (v) {
                    settings.setVolume(v);
                    audio.configure(
                        musicOn: settings.musicOn,
                        sfxOn: settings.sfxOn,
                        volume: settings.volume);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FeltButton(
                  label: 'Restart',
                  primary: false,
                  onPressed: onRestart),
              FeltButton(label: 'Quit', primary: false, onPressed: onQuit),
            ],
          ),
        ],
      ),
      actions: [
        FeltButton(label: 'Resume', onPressed: onResume),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final HeartsThemeDef theme;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
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
          onChanged: onChanged,
        ),
      ],
    );
  }
}
