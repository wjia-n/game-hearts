import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/hearts_themes.dart';

/// Persisted settings + stats for Hearts. Survives app restarts.
///
/// Stores: audio toggles, player names (4 seats), theme/appearance choices
/// (incl. custom theme colors), game-mode setup (bot seats, difficulty),
/// Pro unlock state, and lifetime stats.
///
/// Player names are stored as ONE JSON string — Android's SharedPreferences
/// stores StringLists as an unordered StringSet, so a StringList would
/// scramble name order on every app restart. Never use a StringList here.
class HeartsSettings extends ChangeNotifier {
  static const _kMusic = 'hearts_music_on';
  static const _kSfx = 'hearts_sfx_on';
  static const _kVolume = 'hearts_volume';
  static const _kDifficulty = 'hearts_bot_difficulty'; // 0 easy, 1 medium, 2 hard
  static const _kNamesJson = 'hearts_player_names_json';
  static const _kNamesLegacy = 'hearts_player_names'; // legacy unordered key
  static const _kTheme = 'hearts_theme_id';
  static const _kCardStyle = 'hearts_card_style_id';
  static const _kBotSeatsJson = 'hearts_bot_seats_json';
  static const _kWins = 'hearts_wins';
  static const _kGames = 'hearts_games_played';
  static const _kBestScore = 'hearts_best_score'; // lowest match total, 0 = none
  static const _kMoons = 'hearts_moons_shot';
  static const _kIsPro = 'hearts_is_pro';
  static const _kCustomPrefix = 'hearts_custom_';

  static const defaultNames = ['You', 'Ruby', 'Sam', 'Noor'];

  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 4) {
        return [for (int i = 0; i < 4; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  int difficulty = 1; // medium default
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'classic';
  String cardStyleId = 'ivory';
  List<int> botSeats = [1, 2, 3]; // seat 0 is human by default
  int wins = 0;
  int gamesPlayed = 0;
  int bestScore = 0;
  int moonsShot = 0;
  bool isPro = true; // everything unlocked — no Pro version

  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'felt': 0xFF1E5B3A,
    'feltDark': 0xFF0E3320,
    'rail': 0xFF5C3A21,
    'railDark': 0xFF2E1C0F,
    'accent': 0xFFC9A227,
    'accentLight': 0xFFE8CE7A,
    'ivory': 0xFFF5EFE0,
    'redSuit': 0xFFB3122E,
    'blackSuit': 0xFF1A1A22,
  };

  HeartsThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return HeartsThemeDef(
      id: 'custom',
      name: 'My Creation',
      felt: c('felt'),
      feltDark: c('feltDark'),
      rail: c('rail'),
      railDark: c('railDark'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      ivory: c('ivory'),
      ivoryDim: Color(0xFFCFC3A8),
      redSuit: c('redSuit'),
      blackSuit: c('blackSuit'),
      seatColors: const [
        Color(0xFFC9A227),
        Color(0xFF8FB8D8),
        Color(0xFFD98E8E),
        Color(0xFF9FD8A8),
      ],
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    final namesRaw = p.getString(_kNamesJson);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getStringList(_kNamesLegacy);
      playerNames = (legacy != null && legacy.length == 4)
          ? [for (int i = 0; i < 4; i++) _cleanName(i, legacy[i])]
          : List.of(defaultNames);
    }
    themeId = p.getString(_kTheme) ?? 'classic';
    cardStyleId = p.getString(_kCardStyle) ?? 'ivory';
    try {
      final raw = p.getString(_kBotSeatsJson);
      if (raw != null) {
        final d = jsonDecode(raw);
        if (d is List) {
          final seats =
              d.whereType<int>().where((s) => s >= 0 && s < 4).toList();
          if (seats.isNotEmpty && seats.length < 4) botSeats = seats;
        }
      }
    } catch (_) {}
    wins = p.getInt(_kWins) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    bestScore = p.getInt(_kBestScore) ?? 0;
    moonsShot = p.getInt(_kMoons) ?? 0;
    isPro = true; // everything unlocked
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setInt(_kDifficulty, difficulty);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kNamesLegacy);
    await p.setString(_kTheme, themeId);
    await p.setString(_kCardStyle, cardStyleId);
    await p.setString(_kBotSeatsJson, jsonEncode(botSeats));
    await p.setInt(_kWins, wins);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kBestScore, bestScore);
    await p.setInt(_kMoons, moonsShot);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || HeartsThemes.isProTheme(themeId)) {
      themeId = 'classic';
      changed = true;
    }
    if (HeartsThemes.isProCardStyle(cardStyleId)) {
      cardStyleId = 'ivory';
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return;
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  /// Full mode setup. [botSeats] lists seats that are AI (length 0..3);
  /// at least one human must remain. [difficulty] 0 easy / 1 medium / 2 hard.
  Future<void> setSetup({
    required List<int> botSeats,
    required int difficulty,
  }) async {
    final seats = [
      for (final s in botSeats)
        if (s >= 0 && s < 4) s
    ];
    if (seats.length >= 4) seats.removeRange(3, seats.length);
    this.botSeats = seats.isEmpty ? [] : seats;
    this.difficulty = difficulty.clamp(0, 2);
    if (!isPro && this.difficulty > 1) this.difficulty = 1;
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index > 3) return;
    final clean = name.trim();
    playerNames[index] = clean.isEmpty ? defaultNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || HeartsThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setCardStyle(String id) async {
    if (!isPro && HeartsThemes.isProCardStyle(id)) return;
    cardStyleId = id;
    notifyListeners();
    await _save();
  }

  Future<void> recordGame(
      {required bool humanWon,
      required int bestHumanTotal,
      required bool humanShotMoon}) async {
    gamesPlayed++;
    if (humanWon) {
      wins++;
      if (bestScore == 0 || bestHumanTotal < bestScore) {
        bestScore = bestHumanTotal;
      }
    }
    if (humanShotMoon) moonsShot++;
    notifyListeners();
    await _save();
  }
}
