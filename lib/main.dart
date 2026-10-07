import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const HeartsApp());

class HeartsApp extends StatelessWidget {
  const HeartsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Hearts',
      tagline: 'Dodge the hearts, ditch the queen, and become the lowest scorer in the room!',
      emoji: '♥️',
      slug: 'hearts',
      howToPlay:
          '• You + 3 rivals, 13 cards each. Avoid taking hearts (1 pt each) and the Q♠ (13 pts!).\n• Pass 3 cards before each hand — left, right, across, then no pass.\n• Follow suit if you can. Hearts can\'t lead until broken.\n• Take ALL 26 points to shoot the moon 🌙 — you get 0, everyone else gets 26!\n• Lowest score wins. First to 100 ends the match. Play solo vs bots or pass-and-play!',
      playerOptions: const [1, 4],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => HeartsScreen(players: players, callbacks: cb),
    );
  }
}
