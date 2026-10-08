import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

const _suits = ['♠', '♥', '♦', '♣'];
bool _red(int s) => s == 1 || s == 2;
String _rs(int r) => r == 1 ? 'A' : r == 11 ? 'J' : r == 12 ? 'Q' : r == 13 ? 'K' : '$r';

class _C {
  final int s, r;
  _C(this.s, this.r);
}

class _Seat {
  final Player p;
  final hand = <_C>[];
  List<_C>? passed;
  _Seat(this.p);
}

class _Play {
  final int seat;
  final _C card;
  _Play(this.seat, this.card);
}

class HeartsScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const HeartsScreen({super.key, required this.players, required this.callbacks});

  @override
  State<HeartsScreen> createState() => _HeartsScreenState();
}

class _HeartsScreenState extends State<HeartsScreen> {
  late List<_Seat> seats;
  int phase = 0; // 0 = passing, 1 = playing
  int passDir = 0; // 0 left, 1 right, 2 across, 3 none
  int passTurn = 0; // whose turn to pass (pass-and-play)
  final sel = <_C>{};
  final trick = <_Play>[];
  int turn = 0, handNo = 0;
  bool heartsBroken = false, firstTrick = true, busy = false, finished = false;
  var pts = [0, 0, 0, 0];
  final passNames = ['⬅️ left', '➡️ right', '↔️ across', '🚫 no pass'];

  bool get solo => widget.players.length == 1;
  int get viewSeat => phase == 0 ? passTurn : (solo ? 0 : turn);

  @override
  void initState() {
    super.initState();
    seats = widget.players.length == 4
        ? widget.players.map((p) => _Seat(p)).toList()
        : [_Seat(widget.players[0]), for (var i = 1; i < 4; i++) _Seat(PlayerPresets.make(i, isBot: true))];
    _newHand();
  }

  void _newHand() {
    final deck = [for (var s = 0; s < 4; s++) for (var r = 1; r <= 13; r++) _C(s, r)]..shuffle(Random());
    for (var i = 0; i < 4; i++) {
      seats[i].hand
        ..clear()
        ..addAll(deck.sublist(i * 13, i * 13 + 13));
      _sortHand(i);
      seats[i].passed = null;
    }
    setState(() {
      pts = [0, 0, 0, 0];
      trick.clear();
      sel.clear();
      handNo++;
      passDir = (handNo - 1) % 4;
      passTurn = 0;
      heartsBroken = false;
      firstTrick = true;
      busy = false;
    });
    if (passDir == 3) {
      _beginPlay();
    } else {
      setState(() => phase = 0);
      if (solo) {
        for (var i = 1; i < 4; i++) {
          _botPass(i);
        }
      }
    }
  }

  void _sortHand(int i) {
    seats[i].hand.sort((a, b) => a.s != b.s ? a.s.compareTo(b.s) : a.r.compareTo(b.r));
  }

  int _danger(_C c) {
    if (c.s == 0 && c.r == 12) return 100;
    if (c.s == 0 && c.r == 1) return 90;
    if (c.s == 0 && c.r == 13) return 80;
    if (c.s == 1) return 20 + c.r;
    return c.r;
  }

  void _botPass(int i) {
    final h = [...seats[i].hand]..sort((a, b) => _danger(b).compareTo(_danger(a)));
    seats[i].passed = h.take(3).toList();
    seats[i].hand.removeWhere((c) => seats[i].passed!.contains(c));
  }

  void _doPass() {
    if (sel.length != 3) return;
    setState(() {
      seats[passTurn].passed = sel.toList();
      seats[passTurn].hand.removeWhere((c) => sel.contains(c));
      sel.clear();
      if (!solo && passTurn < 3) passTurn++;
    });
    Sfx.move();
    if (solo || passTurn == 3 && seats.every((s) => s.passed != null)) {
      _swapPasses();
    }
  }

  void _swapPasses() {
    final offset = passDir == 0 ? 1 : passDir == 1 ? 3 : 2;
    final incoming = <int, List<_C>>{};
    for (var i = 0; i < 4; i++) {
      incoming[(i + offset) % 4] = seats[i].passed!;
      seats[i].passed = null;
    }
    setState(() {
      for (var i = 0; i < 4; i++) {
        seats[i].hand.addAll(incoming[i]!);
        _sortHand(i);
      }
    });
    _beginPlay();
  }

  void _beginPlay() {
    var leader = 0;
    for (var i = 0; i < 4; i++) {
      if (seats[i].hand.any((c) => c.s == 3 && c.r == 2)) leader = i;
    }
    setState(() {
      phase = 1;
      turn = leader;
    });
    widget.callbacks.setActivePlayer(turn);
    _maybeBotMove();
  }

  void _maybeBotMove() {
    if (finished || phase != 1 || !seats[turn].p.isBot) return;
    setState(() => busy = true);
    Future.delayed(Duration(milliseconds: 650 + Random().nextInt(350)), () {
      if (!mounted || finished || phase != 1) return;
      _playCard(turn, _botCard(turn));
    });
  }

  bool _isPoint(_C c) => c.s == 1 || (c.s == 0 && c.r == 12);

  List<_C> _legal(int seat) {
    final hand = seats[seat].hand;
    if (trick.isEmpty) {
      if (firstTrick) return hand.where((c) => c.s == 3 && c.r == 2).toList();
      final nonHearts = hand.where((c) => c.s != 1).toList();
      if (!heartsBroken && nonHearts.isNotEmpty) return nonHearts;
      return [...hand];
    }
    final led = trick.first.card.s;
    final follow = hand.where((c) => c.s == led).toList();
    if (follow.isNotEmpty) {
      if (firstTrick) {
        final safe = follow.where((c) => !_isPoint(c)).toList();
        return safe.isNotEmpty ? safe : follow;
      }
      return follow;
    }
    if (firstTrick) {
      final safe = hand.where((c) => !_isPoint(c)).toList();
      return safe.isNotEmpty ? safe : [...hand];
    }
    return [...hand];
  }

  _C _botCard(int seat) {
    final legal = _legal(seat);
    if (trick.isEmpty) {
      final cands = legal.where((c) => c.s != 1).toList();
      final pool = (cands.isNotEmpty ? cands : legal)..sort((a, b) => a.r.compareTo(b.r));
      final qOut = seats.any((s) => s.hand.any((c) => c.s == 0 && c.r == 12));
      for (final c in pool) {
        if (qOut && c.s == 0 && c.r >= 13) continue;
        return c;
      }
      return pool.first;
    }
    final led = trick.first.card.s;
    final follow = legal.where((c) => c.s == led).toList();
    if (follow.isEmpty) {
      final q = legal.where((c) => c.s == 0 && c.r == 12);
      if (q.isNotEmpty) return q.first;
      final hearts = legal.where((c) => c.s == 1).toList()..sort((a, b) => b.r.compareTo(a.r));
      if (hearts.isNotEmpty) return hearts.first;
      final sp = legal.where((c) => c.s == 0 && c.r >= 13).toList()..sort((a, b) => b.r.compareTo(a.r));
      if (sp.isNotEmpty) return sp.first;
      final sorted = [...legal]..sort((a, b) => b.r.compareTo(a.r));
      return sorted.first;
    }
    final q = follow.where((c) => c.s == 0 && c.r == 12);
    if (led == 0 && q.isNotEmpty) return q.first;
    var winRank = -1;
    for (final p in trick) {
      if (p.card.s == led && p.card.r > winRank) winRank = p.card.r;
    }
    final under = follow.where((c) => c.r < winRank).toList()..sort((a, b) => b.r.compareTo(a.r));
    if (under.isNotEmpty) return under.first;
    follow.sort((a, b) => a.r.compareTo(b.r));
    return follow.first;
  }

  void _tapCard(_C c) {
    if (finished || busy) return;
    if (phase == 0) {
      if (seats[passTurn].p.isBot) return;
      setState(() {
        if (sel.contains(c)) {
          sel.remove(c);
        } else if (sel.length < 3) {
          sel.add(c);
        }
      });
      Sfx.tap();
      return;
    }
    if (turn != viewSeat || seats[turn].p.isBot) return;
    if (!_legal(turn).contains(c)) {
      Sfx.tap();
      return;
    }
    _playCard(turn, c);
  }

  void _playCard(int seat, _C card) {
    setState(() {
      seats[seat].hand.remove(card);
      trick.add(_Play(seat, card));
      busy = false;
    });
    Sfx.tap();
    if (trick.length == 4) {
      setState(() => busy = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || finished) return;
        _resolveTrick();
      });
    } else {
      setState(() => turn = (turn + 1) % 4);
      widget.callbacks.setActivePlayer(turn);
      _maybeBotMove();
    }
  }

  void _resolveTrick() {
    final led = trick.first.card.s;
    var win = trick.first;
    var points = 0;
    for (final p in trick) {
      if (p.card.s == 1) {
        points += 1;
        heartsBroken = true;
      }
      if (p.card.s == 0 && p.card.r == 12) points += 13;
      if (p.card.s == led && p.card.r > win.card.r) win = p;
    }
    setState(() {
      pts[win.seat] += points;
      trick.clear();
      turn = win.seat;
      firstTrick = false;
      busy = false;
    });
    Sfx.move();
    widget.callbacks.setActivePlayer(turn);
    if (seats.every((s) => s.hand.isEmpty)) {
      _endHand();
    } else {
      _maybeBotMove();
    }
  }

  void _endHand() {
    final moon = pts.indexWhere((p) => p == 26);
    setState(() {
      for (var i = 0; i < 4; i++) {
        seats[i].p.score += moon == -1 ? pts[i] : (i == moon ? 0 : 26);
      }
    });
    widget.callbacks.refreshHud();
    Sfx.win();
    final matchOver = seats.any((s) => s.p.score >= 100);
    final t = ThemeController.of(context).theme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WajihaDialog(
        emoji: moon == -1 ? '🃏' : '🌙',
        title: moon == -1 ? 'Hand $handNo done!' : '${seats[moon].p.name} shot the MOON! 🌙',
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${seats[i].p.emoji} ${seats[i].p.name}: +${moon == -1 ? pts[i] : (i == moon ? 0 : 26)} → ${seats[i].p.score}',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.text, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          const SizedBox(height: 6),
          Text(
              matchOver
                  ? 'Match over — lowest score takes the crown! 👑'
                  : 'Lowest score wins. Keep dodging! 💨',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.muted, fontSize: 13)),
          const SizedBox(height: 14),
          WajihaButton(
            label: matchOver ? 'See results 🏁' : 'Next hand 🃏',
            onTap: () {
              Navigator.pop(context);
              if (matchOver) {
                _finishMatch();
              } else {
                _newHand();
              }
            },
          ),
        ],
      ),
    );
  }

  void _finishMatch() {
    if (finished) return;
    finished = true;
    var w = 0;
    for (var i = 1; i < 4; i++) {
      if (seats[i].p.score < seats[w].p.score) w = i;
    }
    final scores = seats.map((s) => '${s.p.emoji} ${s.p.name}: ${s.p.score}').join('   •   ');
    widget.callbacks.finish(
      headline: '🏆 ${seats[w].p.name} wins the match!',
      subline:
          'Final scores — $scores. ${w == 0 ? 'You dodged like a legend! 💛' : 'The bots send their regards. 🤖'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final vs = viewSeat;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        if (solo) ScoreChips(players: seats.map((s) => s.p).toList(), activeIndex: phase == 1 ? turn : 0),
        const SizedBox(height: 6),
        _opponents(t),
        const SizedBox(height: 8),
        Expanded(child: _table(t)),
        const SizedBox(height: 8),
        if (phase == 0) _passBar(t) else _turnInfo(t),
        const SizedBox(height: 8),
        _hand(t, vs),
      ]),
    );
  }

  Widget _opponents(GameTheme t) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [for (var i = 1; i < 4; i++) _oppSeat(t, i)],
      );

  Widget _oppSeat(GameTheme t, int i) {
    final s = seats[i];
    final active = phase == 1 && turn == i;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? s.p.color.withValues(alpha: 0.25) : t.surface,
        borderRadius: t.radius,
        border: Border.all(
            color: active ? s.p.color : t.muted.withValues(alpha: 0.3), width: active ? 2.5 : 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${s.p.emoji} ${s.p.name}',
            style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🂠', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text('${s.hand.length}',
              style: TextStyle(color: t.muted, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text('💔 ${s.p.score}',
              style: TextStyle(color: t.muted, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _table(GameTheme t) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.surface.withValues(alpha: 0.5),
          borderRadius: t.radius,
          border: Border.all(color: t.primary.withValues(alpha: 0.25)),
        ),
        child: trick.isEmpty
            ? Center(
                child: Text(
                  phase == 0
                      ? '📨 ${solo ? 'Pick 3 cards to pass' : '${seats[passTurn].p.name}, pick 3'} ${passNames[passDir]}'
                      : '🃏 Waiting for ${seats[turn].p.name}…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.muted, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              )
            : Center(
                child: Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final p in trick)
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        _miniCard(t, p.card, 54),
                        const SizedBox(height: 2),
                        Text(seats[p.seat].p.emoji, style: const TextStyle(fontSize: 14)),
                      ]),
                  ],
                ),
              ),
      );

  Widget _turnInfo(GameTheme t) {
    final cur = seats[turn];
    final label = cur.p.isBot
        ? '${cur.p.emoji} ${cur.p.name} is thinking… 🤖'
        : solo
            ? 'Your turn — play a card! 👆'
            : '${cur.p.emoji} ${cur.p.name}, your turn! 👆';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [cur.p.color.withValues(alpha: 0.85), cur.p.color.withValues(alpha: 0.55)]),
          borderRadius: t.radius),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
    );
  }

  Widget _passBar(GameTheme t) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(solo ? 'Selected ${sel.length}/3' : '${seats[passTurn].p.name}: ${sel.length}/3',
            style: TextStyle(color: t.text, fontWeight: FontWeight.w800)),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: sel.length == 3 ? _doPass : null,
          child: Opacity(
            opacity: sel.length == 3 ? 1 : 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                  gradient: sel.length == 3 ? t.headerGradient : null,
                  color: sel.length == 3 ? null : t.surface,
                  borderRadius: t.radius),
              child: Text('Pass ${passNames[passDir]} 📨',
                  style: TextStyle(
                      color: sel.length == 3 ? Colors.white : t.muted,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ]);

  Widget _hand(GameTheme t, int vs) {
    final hand = seats[vs].hand;
    final legal = phase == 1 && turn == vs && !seats[vs].p.isBot ? _legal(vs).toSet() : null;
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hand.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final c = hand[i];
          final isSel = sel.contains(c);
          final playable = phase == 0 || legal == null ? true : legal.contains(c);
          return GestureDetector(
            onTap: () => _tapCard(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              transform: Matrix4.translationValues(0, isSel ? -10 : 0, 0),
              child: Opacity(
                opacity: playable ? 1 : 0.45,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: isSel ? Border.all(color: t.accent, width: 3) : null,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: _miniCard(t, c, 62),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _miniCard(GameTheme t, _C c, double w) {
    final h = w * 1.42;
    final col = _red(c.s) ? Colors.red.shade700 : Colors.grey.shade900;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      padding: EdgeInsets.all(w * 0.08),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_rs(c.r),
            style: TextStyle(fontSize: w * 0.30, fontWeight: FontWeight.w900, color: col, height: 1)),
        Text(_suits[c.s], style: TextStyle(fontSize: w * 0.30, color: col, height: 1.1)),
        const Spacer(),
        Align(
            alignment: Alignment.bottomRight,
            child: Text(_suits[c.s], style: TextStyle(fontSize: w * 0.34, height: 1))),
      ]),
    );
  }
}
