import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Card encoding: int 0..51.
// suit = c ~/ 13  (0 clubs, 1 diamonds, 2 spades, 3 hearts)
// rank = c % 13   (0 = '2' .. 12 = 'A')
// ---------------------------------------------------------------------------
int cardSuit(int c) => c ~/ 13;
int cardRank(int c) => c % 13;

const rankLabels = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
const suitGlyphs = ['♣', '♦', '♠', '♥'];
const suitNames = ['Clubs', 'Diamonds', 'Spades', 'Hearts'];

String cardName(int c) => '${rankLabels[cardRank(c)]}${suitGlyphs[cardSuit(c)]}';
String cardSuitName(int c) => suitNames[cardSuit(c)];
bool isHeart(int c) => cardSuit(c) == 3;
bool isQueenOfSpades(int c) => c == 2 * 13 + 10;

/// Points a card is worth when taken in a trick.
int cardPoints(int c) {
  if (isQueenOfSpades(c)) return 13;
  if (isHeart(c)) return 1;
  return 0;
}

bool isRedSuit(int c) => cardSuit(c) == 1 || cardSuit(c) == 3;

// ---------------------------------------------------------------------------
class HeartsPlayer {
  String name;
  final bool isBot;
  HeartsPlayer({required this.name, required this.isBot});
}

/// 0 = easy, 1 = medium, 2 = hard (RULES.md §11).
enum BotDifficulty { easy, medium, hard }

/// Turn phases owned entirely by the engine. The UI only renders.
enum HeartsPhase {
  idle,
  dealing,
  passing,
  awaitingPlay, // current seat must play; awaitingHuman says who acts
  animatingPlay, // card flying to the table (brief, then trickResolve)
  trickResolve, // trick winner shown before cards clear
  handTally, // scores added, moon-shots announced
  matchOver,
}

/// One card on the table, in play order.
class TrickPlay {
  final int seat;
  final int card;
  final int order;
  TrickPlay(this.seat, this.card, this.order);
}

/// A visible action for the UI to animate (deal burst, pass exchange, play).
class PlayAnim {
  final String kind; // 'deal' | 'pass' | 'play'
  final int seat;
  final int card;
  final int id;
  PlayAnim(this.kind, this.seat, this.card, this.id);
}

// Pass directions rotate each hand: left, right, across, hold.
const _passNames = ['left', 'right', 'across', 'hold'];
int _passTarget(int seat, int handNumber) {
  switch (handNumber % 4) {
    case 0:
      return (seat + 1) % 4; // left
    case 1:
      return (seat + 3) % 4; // right
    case 2:
      return (seat + 2) % 4; // across
    default:
      return seat; // hold
  }
}

/// Full Hearts engine: rules, turn state machine, AI, scoring, watchdog.
///
/// The engine owns every phase transition on its own timers. The UI never
/// advances the game itself — it only renders and forwards human input.
/// A watchdog timer recovers any phase found without a live timer and without
/// a pending human decision, so stuck states are impossible by construction.
class HeartsEngine extends ChangeNotifier {
  final List<HeartsPlayer> players; // always 4 seats
  final BotDifficulty difficulty;
  final int targetScore;

  /// Event hook for the UI (SFX triggers, toasts). Values: 'shuffle',
  /// 'deal', 'card_place', 'trick_win', 'hearts', 'queen', 'moon',
  /// 'invalid', 'hand_start', 'match_end'.
  void Function(String event)? onEvent;

  HeartsPhase phase = HeartsPhase.idle;
  bool awaitingHuman = false;

  List<List<int>> hands = [[], [], [], []];
  List<TrickPlay> trick = [];
  List<int> scores = [0, 0, 0, 0];
  List<int> handPoints = [0, 0, 0, 0];
  bool heartsBroken = false;
  int handNumber = 0; // 0-based
  int trickNumber = 0;
  int currentSeat = 0;
  int leaderSeat = 0;
  String narration = 'Welcome to the table.';
  PlayAnim? lastAnim;
  List<int> dealProgress = [0, 0, 0, 0];
  List<int> passSelected = []; // human's chosen pass cards
  int? moonShooter; // seat that shot the moon this hand (or null)
  List<int> finalTotals = [];
  List<int> winners = [];

  final Random _rand;
  final Set<int> _playedCards = {};
  final List<List<int>> _trickPointsTaken = [[], [], [], []];

  Timer? _timer;
  int _timerGen = 0;
  Timer? _watchdog;
  int _animId = 0;
  bool _disposed = false;
  bool _trickResolved = false;
  bool _handTallied = false;

  HeartsEngine({
    required this.players,
    required this.difficulty,
    this.targetScore = 100,
    int? seed,
  }) : _rand = Random(seed);

  int get humanCount => players.where((p) => !p.isBot).length;
  String get passDirectionName => _passNames[handNumber % 4];
  bool get isHoldHand => handNumber % 4 == 3;
  /// Seat currently choosing pass cards (-1 when nobody is).
  int get passSeat => _passQueue.isEmpty ? -1 : _passQueue.first;

  // ------------------------------------------------------------ timers
  /// Schedule engine work. Any new schedule cancels the previous one; the
  /// generation token guarantees a stale callback can never fire.
  void _schedule(Duration delay, void Function() work) {
    _timer?.cancel();
    final gen = ++_timerGen;
    _timer = Timer(delay, () {
      if (_disposed || gen != _timerGen) return;
      _timer = null;
      work();
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_disposed) return;
      // A live timer, a pending human decision, or a finished game is fine.
      if (_timer != null || awaitingHuman) return;
      if (phase == HeartsPhase.idle || phase == HeartsPhase.matchOver) return;
      // No timer and nobody to wait for: recover the current phase.
      narration = 'Recovering the table…';
      notifyListeners();
      _recoverPhase();
    });
  }

  /// Re-enter the current phase's work after a watchdog trip.
  void _recoverPhase() {
    switch (phase) {
      case HeartsPhase.dealing:
        _continueDealing();
        break;
      case HeartsPhase.passing:
        _continuePassing();
        break;
      case HeartsPhase.awaitingPlay:
        _beginTurn();
        break;
      case HeartsPhase.animatingPlay:
        _afterPlayAnim();
        break;
      case HeartsPhase.trickResolve:
        _resolveTrick();
        break;
      case HeartsPhase.handTally:
        _tallyHand();
        break;
      case HeartsPhase.idle:
      case HeartsPhase.matchOver:
        break;
    }
  }

  // ------------------------------------------------------------ match flow
  void startMatch() {
    scores = [0, 0, 0, 0];
    handNumber = 0;
    finalTotals = [];
    winners = [];
    _startWatchdog();
    _startHand();
  }

  void _startHand() {
    heartsBroken = false;
    _handTallied = false;
    _trickResolved = false;
    handPoints = [0, 0, 0, 0];
    trickNumber = 0;
    moonShooter = null;
    _playedCards.clear();
    _trickPointsTaken.setAll(0, [[], [], [], []]);
    passSelected = [];
    onEvent?.call('hand_start');
    narration = 'Hand ${handNumber + 1} — shuffling…';
    phase = HeartsPhase.dealing;
    dealProgress = [0, 0, 0, 0];
    hands = [[], [], [], []];
    trick = [];
    final deck = List<int>.generate(52, (i) => i)..shuffle(_rand);
    _deck = deck;
    _dealIndex = 0;
    onEvent?.call('shuffle');
    notifyListeners();
    _schedule(const Duration(milliseconds: 500), _continueDealing);
  }

  List<int> _deck = [];
  int _dealIndex = 0;

  /// Deal one card per tick so the UI animates a real deal around the table.
  void _continueDealing() {
    if (phase != HeartsPhase.dealing) return;
    if (_dealIndex < 52) {
      final seat = _dealIndex % 4;
      final card = _deck[_dealIndex++];
      hands[seat].add(card);
      dealProgress[seat]++;
      if (_dealIndex % 4 == 0) onEvent?.call('deal');
      lastAnim = PlayAnim('deal', seat, card, ++_animId);
      notifyListeners();
      _schedule(const Duration(milliseconds: 70), _continueDealing);
      return;
    }
    for (final h in hands) {
      h.sort((a, b) {
        final s = cardSuit(a).compareTo(cardSuit(b));
        return s != 0 ? s : cardRank(a).compareTo(cardRank(b));
      });
    }
    if (isHoldHand) {
      narration = 'Hold hand — no passing this time.';
      phase = HeartsPhase.awaitingPlay;
      notifyListeners();
      _schedule(const Duration(milliseconds: 900), _beginFirstTrick);
    } else {
      narration = 'Pass 3 cards ${passDirectionName}.';
      phase = HeartsPhase.passing;
      _passQueue = [0, 1, 2, 3];
      _passChoices = [[], [], [], []];
      notifyListeners();
      _schedule(const Duration(milliseconds: 700), _continuePassing);
    }
  }

  List<int> _passQueue = [];
  List<List<int>> _passChoices = [[], [], [], []];

  void _continuePassing() {
    if (phase != HeartsPhase.passing) return;
    if (_passQueue.isEmpty) {
      _exchangePasses();
      return;
    }
    final seat = _passQueue.first;
    final player = players[seat];
    if (player.isBot) {
      awaitingHuman = false;
      narration = '${player.name} is choosing cards to pass…';
      notifyListeners();
      _schedule(Duration(milliseconds: 700 + _rand.nextInt(600)), () {
        if (phase != HeartsPhase.passing) return;
        _passChoices[seat] = _aiChoosePass(seat);
        lastAnim = PlayAnim(
            'pass', seat, _passChoices[seat].first, ++_animId);
        narration = '${player.name} passes 3 cards ${passDirectionName}.';
        _passQueue.removeAt(0);
        notifyListeners();
        _schedule(const Duration(milliseconds: 650), _continuePassing);
      });
    } else {
      awaitingHuman = true;
      passSelected = [];
      narration =
          '${player.name}, pick 3 cards to pass ${passDirectionName}.';
      notifyListeners();
      // Human acts via togglePassCard()/confirmPass(). Watchdog skips us.
    }
  }

  /// Human pass UI: toggle a card in the 3-card pass selection.
  void togglePassCard(int card) {
    if (phase != HeartsPhase.passing || !awaitingHuman) return;
    if (_passQueue.isEmpty || players[_passQueue.first].isBot) return;
    if (!hands[_passQueue.first].contains(card)) return;
    if (passSelected.contains(card)) {
      passSelected.remove(card);
    } else if (passSelected.length < 3) {
      passSelected.add(card);
    }
    notifyListeners();
  }

  /// Human confirms their 3 pass cards.
  void confirmPass() {
    if (phase != HeartsPhase.passing || !awaitingHuman) return;
    if (passSelected.length != 3) {
      onEvent?.call('invalid');
      narration = 'Pick exactly 3 cards to pass.';
      notifyListeners();
      return;
    }
    final seat = _passQueue.removeAt(0);
    _passChoices[seat] = List.of(passSelected);
    lastAnim =
        PlayAnim('pass', seat, passSelected.first, ++_animId);
    awaitingHuman = false;
    narration = '${players[seat].name} passes 3 cards ${passDirectionName}.';
    onEvent?.call('card_place');
    notifyListeners();
    _schedule(const Duration(milliseconds: 650), _continuePassing);
  }

  void _exchangePasses() {
    for (int seat = 0; seat < 4; seat++) {
      final target = _passTarget(seat, handNumber);
      for (final c in _passChoices[seat]) {
        hands[seat].remove(c);
        hands[target].add(c);
      }
    }
    for (final h in hands) {
      h.sort((a, b) {
        final s = cardSuit(a).compareTo(cardSuit(b));
        return s != 0 ? s : cardRank(a).compareTo(cardRank(b));
      });
    }
    narration = 'Cards passed ${passDirectionName}.';
    phase = HeartsPhase.awaitingPlay;
    notifyListeners();
    _schedule(const Duration(milliseconds: 900), _beginFirstTrick);
  }

  void _beginFirstTrick() {
    // Holder of the 2♣ (card 0) leads the first trick with it.
    leaderSeat = 0;
    for (int s = 0; s < 4; s++) {
      if (hands[s].contains(0)) leaderSeat = s;
    }
    currentSeat = leaderSeat;
    trick = [];
    phase = HeartsPhase.awaitingPlay;
    _beginTurn();
  }

  void _beginTurn() {
    if (phase != HeartsPhase.awaitingPlay) return;
    final player = players[currentSeat];
    if (player.isBot) {
      awaitingHuman = false;
      narration = trick.isEmpty
          ? '${player.name} is choosing a lead…'
          : '${player.name} is thinking…';
      notifyListeners();
      _schedule(Duration(milliseconds: 850 + _rand.nextInt(700)), () {
        if (phase != HeartsPhase.awaitingPlay) return;
        if (players[currentSeat].isBot) {
          final card = _aiChoosePlay(currentSeat);
          _applyPlay(currentSeat, card);
        }
      });
    } else {
      awaitingHuman = true;
      narration = trick.isEmpty
          ? '${player.name}, lead a card.'
          : '${player.name}, your play — follow ${cardSuitName(trick.first.card)} if you can.';
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ rules
  /// All legal plays for [seat] right now.
  List<int> legalPlays(int seat) {
    final hand = hands[seat];
    if (phase != HeartsPhase.awaitingPlay || trick.isEmpty) {
      return _legalLeads(seat);
    }
    final ledSuit = cardSuit(trick.first.card);
    final follow = hand.where((c) => cardSuit(c) == ledSuit).toList();
    if (follow.isNotEmpty) return follow;
    // Can't follow suit: anything goes, except the first-trick points rule.
    if (trickNumber == 0) {
      final safe = hand
          .where((c) => cardPoints(c) == 0 && c != 0)
          .toList();
      if (safe.isNotEmpty) return safe;
    }
    return List.of(hand);
  }

  List<int> _legalLeads(int seat) {
    final hand = hands[seat];
    if (trickNumber == 0 && trick.isEmpty) return [0]; // must lead 2♣
    final nonHearts = hand.where((c) => !isHeart(c)).toList();
    if (!heartsBroken && nonHearts.isNotEmpty) return nonHearts;
    return List.of(hand);
  }

  /// Attempt a human play. Returns false when the card is illegal.
  bool playCard(int seat, int card) {
    if (phase != HeartsPhase.awaitingPlay || !awaitingHuman) return false;
    if (seat != currentSeat) return false;
    if (!legalPlays(seat).contains(card)) {
      onEvent?.call('invalid');
      narration = 'Not a legal play — ${_illegalReason(seat, card)}';
      notifyListeners();
      return false;
    }
    awaitingHuman = false;
    _applyPlay(seat, card);
    return true;
  }

  String _illegalReason(int seat, int card) {
    if (!hands[seat].contains(card)) return 'that card is not in your hand';
    if (trick.isEmpty) {
      if (trickNumber == 0) return 'the 2♣ must open the hand';
      if (isHeart(card) && !heartsBroken) return 'hearts are not broken yet';
      return 'you cannot lead that yet';
    }
    final ledSuit = cardSuit(trick.first.card);
    if (hands[seat].any((c) => cardSuit(c) == ledSuit)) {
      return 'you must follow ${cardSuitName(trick.first.card)}';
    }
    if (trickNumber == 0 && cardPoints(card) > 0) {
      return 'no points on the first trick';
    }
    return 'illegal play';
  }

  void _applyPlay(int seat, int card) {
    hands[seat].remove(card);
    _playedCards.add(card);
    _trickResolved = false;
    trick.add(TrickPlay(seat, card, trick.length));
    if (isHeart(card)) heartsBroken = true;
    lastAnim = PlayAnim('play', seat, card, ++_animId);
    phase = HeartsPhase.animatingPlay;
    onEvent?.call('card_place');
    if (isQueenOfSpades(card)) {
      narration = '👑 ${players[seat].name} drops the QUEEN of spades!';
    } else if (isHeart(card) && trickNumber == 0) {
      narration = '${players[seat].name} plays ${cardName(card)}.';
    } else {
      narration =
          '${players[seat].name} plays ${cardName(card)}.';
    }
    notifyListeners();
    _schedule(const Duration(milliseconds: 650), _afterPlayAnim);
  }

  void _afterPlayAnim() {
    if (trick.length == 4) {
      _resolveTrick();
    } else {
      currentSeat = (currentSeat + 1) % 4;
      phase = HeartsPhase.awaitingPlay;
      _beginTurn();
    }
  }

  void _resolveTrick() {
    // Idempotent: a watchdog re-entry must never double-count points.
    if (_trickResolved) return;
    _trickResolved = true;
    phase = HeartsPhase.trickResolve;
    final ledSuit = cardSuit(trick.first.card);
    TrickPlay best = trick.first;
    for (final tp in trick) {
      if (cardSuit(tp.card) == ledSuit &&
          cardRank(tp.card) > cardRank(best.card)) {
        best = tp;
      }
    }
    final pts = trick.fold(0, (s, tp) => s + cardPoints(tp.card));
    handPoints[best.seat] += pts;
    final queenTaken = trick.any((t) => isQueenOfSpades(t.card));
    if (pts > 0) {
      _trickPointsTaken[best.seat].add(trickNumber);
      onEvent?.call(queenTaken ? 'queen' : 'hearts');
      narration =
          '${players[best.seat].name} takes the trick (+$pts${pts == 1 ? ' pt' : ' pts'}).';
    } else {
      onEvent?.call('trick_win');
      narration = '${players[best.seat].name} takes the trick.';
    }
    leaderSeat = best.seat;
    notifyListeners();
    _schedule(const Duration(milliseconds: 1250), () {
      trick = [];
      trickNumber++;
      if (trickNumber >= 13) {
        _tallyHand();
      } else {
        currentSeat = leaderSeat;
        phase = HeartsPhase.awaitingPlay;
        _beginTurn();
      }
    });
  }

  void _tallyHand() {
    if (_handTallied) return;
    _handTallied = true;
    phase = HeartsPhase.handTally;
    // Shooting the moon: one player took all 26 points.
    int shooter = -1;
    for (int s = 0; s < 4; s++) {
      if (handPoints[s] == 26) shooter = s;
    }
    if (shooter >= 0) {
      moonShooter = shooter;
      for (int s = 0; s < 4; s++) {
        if (s != shooter) scores[s] += 26;
      }
      onEvent?.call('moon');
      narration =
          '🌙 ${players[shooter].name} SHOOTS THE MOON! Everyone else +26.';
    } else {
      for (int s = 0; s < 4; s++) {
        scores[s] += handPoints[s];
      }
      final parts = [
        for (int s = 0; s < 4; s++)
          '${players[s].name} +${handPoints[s]} = ${scores[s]}'
      ];
      narration = 'Hand over — ${parts.join(' · ')}';
    }
    notifyListeners();
    _schedule(const Duration(milliseconds: 2400), () {
      if (scores.any((s) => s >= targetScore)) {
        _endMatch();
      } else {
        handNumber++;
        _startHand();
      }
    });
  }

  void _endMatch() {
    phase = HeartsPhase.matchOver;
    awaitingHuman = false;
    finalTotals = List.of(scores);
    final low = scores.reduce((a, b) => a < b ? a : b);
    winners = [for (int s = 0; s < 4; s++) if (scores[s] == low) s];
    final names = winners.map((s) => players[s].name).join(' & ');
    narration = winners.length == 1
        ? '🏆 $names wins the match with $low points!'
        : '🏆 Tie! $names share the win at $low points.';
    onEvent?.call('match_end');
    notifyListeners();
  }

  // ------------------------------------------------------------ AI
  List<int> _aiChoosePass(int seat) {
    final hand = List<int>.of(hands[seat]);
    if (difficulty == BotDifficulty.easy) {
      hand.shuffle(_rand);
      return hand.take(3).toList();
    }
    // Score each card: higher = more desirable to pass away.
    int score(int c) {
      int v = 0;
      if (isQueenOfSpades(c)) v += 100;
      if (c == 2 * 13 + 12) v += 70; // A♠
      if (c == 2 * 13 + 11) v += 60; // K♠
      if (isHeart(c)) v += 20 + cardRank(c) * 3;
      final suitCount =
          hand.where((x) => cardSuit(x) == cardSuit(c)).length;
      if (suitCount <= 3) v += (4 - suitCount) * 12; // void short suits
      v += cardRank(c); // prefer shedding high cards
      return v;
    }

    final hard = difficulty == BotDifficulty.hard;
    // Hard AI occasionally keeps a moon-shot hand together.
    if (hard && _moonWorthy(hand)) {
      // Pass low off-suit cards instead of breaking the moon hand.
      final lows = hand.where((c) => cardPoints(c) == 0).toList()
        ..sort((a, b) => cardRank(a).compareTo(cardRank(b)));
      if (lows.length >= 3) return lows.take(3).toList();
    }
    hand.sort((a, b) => score(b).compareTo(score(a)));
    return hand.take(3).toList();
  }

  bool _moonWorthy(List<int> hand) {
    final hearts = hand.where(isHeart).toList();
    final highHearts =
        hearts.where((c) => cardRank(c) >= 8).length; // J♥ and up
    final hasQS = hand.any(isQueenOfSpades);
    final highSpades = hand
        .where((c) => cardSuit(c) == 2 && cardRank(c) >= 10)
        .length;
    return hearts.length >= 5 && highHearts >= 3 && (hasQS || highSpades >= 2);
  }

  int _aiChoosePlay(int seat) {
    final legal = legalPlays(seat);
    if (legal.length == 1) return legal.first;
    if (difficulty == BotDifficulty.easy) {
      return legal[_rand.nextInt(legal.length)];
    }
    final hard = difficulty == BotDifficulty.hard;
    if (trick.isEmpty) return _aiLead(seat, legal, hard);
    return _aiFollow(seat, legal, hard);
  }

  int _aiLead(int seat, List<int> legal, bool hard) {
    // Never lead hearts unless forced; avoid leading into the Q♠ danger.
    final qOut = !_playedCards.any(isQueenOfSpades) &&
        !hands[seat].any(isQueenOfSpades);
    List<int> opts = legal.where((c) => !isHeart(c)).toList();
    if (opts.isEmpty) opts = legal;
    if (qOut) {
      // Don't lead A♠/K♠ while someone else may hold the queen.
      final safe = opts
          .where((c) =>
              !(cardSuit(c) == 2 && cardRank(c) >= 11))
          .toList();
      if (safe.isNotEmpty) opts = safe;
    }
    if (hard && _someoneShootingMoon(seat)) {
      // Lead your highest safe card to grab control.
      opts.sort((a, b) => cardRank(b).compareTo(cardRank(a)));
      return opts.first;
    }
    // Lead low from the longest suit — classic safe lead.
    final bySuit = <int, List<int>>{};
    for (final c in opts) {
      bySuit.putIfAbsent(cardSuit(c), () => []).add(c);
    }
    final longest = bySuit.values
        .reduce((a, b) => a.length >= b.length ? a : b)
      ..sort((a, b) => cardRank(a).compareTo(cardRank(b)));
    return longest.first;
  }

  int _aiFollow(int seat, List<int> legal, bool hard) {
    final ledSuit = cardSuit(trick.first.card);
    // Currently winning card of the led suit on the table.
    int winRank = -1;
    for (final tp in trick) {
      if (cardSuit(tp.card) == ledSuit && cardRank(tp.card) > winRank) {
        winRank = cardRank(tp.card);
      }
    }
    final pointCards = legal.where((c) => cardPoints(c) > 0).toList();
    final nonPoint = legal.where((c) => cardPoints(c) == 0).toList();

    bool moonThreat = hard && _someoneShootingMoon(seat);

    // If we must take points anyway, dump the worst (Q♠ first).
    int dumpWorst() {
      final qs = pointCards.where(isQueenOfSpades);
      if (qs.isNotEmpty) return qs.first;
      pointCards.sort((a, b) => cardPoints(b).compareTo(cardPoints(a)));
      return pointCards.first;
    }

    // Cards that would NOT win the trick right now.
    final losers =
        legal.where((c) => cardSuit(c) != ledSuit || cardRank(c) < winRank).toList();

    if (moonThreat && pointCards.isNotEmpty) {
      // Break the moon: take a point trick if we can.
      final winners = legal
          .where((c) => cardSuit(c) == ledSuit && cardRank(c) > winRank)
          .toList();
      if (winners.isNotEmpty && pointCards.isNotEmpty) {
        // Win cheaply with the lowest winner while shedding nothing extra.
        winners.sort((a, b) => cardRank(a).compareTo(cardRank(b)));
        return winners.first;
      }
    }

    if (losers.isNotEmpty) {
      // Duck: shed the most dangerous card that still loses.
      final danger = losers.where((c) => cardPoints(c) > 0).toList();
      if (danger.isNotEmpty) {
        final qs = danger.where(isQueenOfSpades);
        if (qs.isNotEmpty) return qs.first;
        danger.sort((a, b) => cardRank(b).compareTo(cardRank(a)));
        return danger.first;
      }
      // No points to shed: play high to keep low cards for later control
      // (medium), or play low to stay safe (hard plays low here).
      losers.sort((a, b) => hard
          ? cardRank(a).compareTo(cardRank(b))
          : cardRank(b).compareTo(cardRank(a)));
      return losers.first;
    }

    // We would win the trick no matter what — minimize damage.
    if (nonPoint.isNotEmpty) {
      nonPoint.sort((a, b) => cardRank(a).compareTo(cardRank(b)));
      return nonPoint.first;
    }
    return dumpWorst();
  }

  /// True when an opponent has taken points in every trick so far — the
  /// classic fingerprint of a moon attempt.
  bool _someoneShootingMoon(int seat) {
    if (trickNumber < 2) return false;
    for (int s = 0; s < 4; s++) {
      if (s == seat) continue;
      if (_trickPointsTaken[s].length == trickNumber && trickNumber >= 3) {
        return true;
      }
    }
    return false;
  }

  // ------------------------------------------------------------ lifecycle
  bool _paused = false;

  /// Pause all engine timers (pause menu / app backgrounded). The watchdog
  /// is paused too, so it cannot "recover" a deliberately paused game.
  void setPaused(bool v) {
    if (_paused == v || _disposed) return;
    _paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
      _watchdog?.cancel();
      _watchdog = null;
    } else {
      _startWatchdog();
      _recoverPhase();
    }
    notifyListeners();
  }

  void disposeEngine() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
  }

  @override
  void dispose() {
    disposeEngine();
    super.dispose();
  }
}
