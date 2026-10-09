import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Hearts — card-table sounds synthesized in code as WAV.
/// No asset files.
///
/// Reliability design (copied from the exemplar):
/// - Music clips synthesized ONCE and cached; starting music never blocks UI.
/// - A [_musicGen] generation counter serializes track changes so overlapping
///   calls can never swallow a start or leave the player half-started.
/// - Lifecycle uses pause()/resume().
/// - Every public method catches player errors; audio can never crash the app.
class HeartsAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  final Map<String, Uint8List> _cache = {};

  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  HeartsAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    this.volume = volume.clamp(0.0, 1.0);
    _music.setVolume(musicOn ? this.volume * 0.5 : 0.0);
    _sfx.setVolume(sfxOn ? this.volume : 0.0);
    if (!musicOn) stopMusic();
  }

  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  /// A card snapping onto felt: short papery click + soft thud.
  List<double> _cardSnap() {
    final n = (_rate * 0.12).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.55 * (_rand.nextDouble() * 2 - 1) * exp(-t * 160) +
              0.45 * sin(2 * pi * 220 * t) * exp(-t * 60));
    }
    return out;
  }

  /// Riffle shuffle: several papery bursts.
  List<double> _shuffle() {
    final n = (_rate * 0.6).round();
    final out = List<double>.filled(n, 0);
    for (int burst = 0; burst < 7; burst++) {
      final start = (n * burst / 8).round();
      final len = (_rate * 0.05).round();
      for (int i = 0; i < len && start + i < n; i++) {
        final t = i / _rate;
        out[start + i] += (_rand.nextDouble() * 2 - 1) *
            exp(-t * 110) *
            (0.5 + 0.5 * sin(2 * pi * (700 + burst * 120) * t));
      }
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs,
      {double harmonics = 0.2}) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: harmonics));
      out.addAll(List<double>.filled((_rate * gapSecs).round(), 0));
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0));
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // Warm parlor piano-ish pads: C – Am – F – G, 16s loop.
        final seq = [
          [261.63, 329.63, 392.0], // C
          [220.0, 261.63, 329.63], // Am
          [174.61, 220.0, 261.63], // F
          [196.0, 246.94, 293.66], // G
        ];
        final out = <double>[];
        for (final chord in seq) {
          out.addAll(_padChord(chord, 4.0));
        }
        return out;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Gentle waltz-time plucks over a soft drone, 12s loop — card-room.
        final drone = _padChord([146.83, 220.0], 12.0);
        final plucks = [523.25, 587.33, 659.25, 587.33, 523.25, 440.0];
        final n = (_rate * 12).round();
        final out = List<double>.from(drone);
        for (int k = 0; k < plucks.length; k++) {
          final start = (n * k / plucks.length).round();
          final tone = _tone(plucks[k], 0.55, harmonics: 0.3);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.3;
          }
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));
  Future<void> cardPlace() => _play(_clip('card_place', _cardSnap));
  Future<void> deal() =>
      _play(_clip('deal', () => _cardSnap()..addAll(_cardSnap())));
  Future<void> shuffle() => _play(_clip('shuffle', _shuffle));
  Future<void> invalid() =>
      _play(_clip('invalid', () => _tone(150, 0.18, harmonics: 0.5)));
  Future<void> trickWin() => _play(
      _clip('trick', () => _tone(520, 0.14, freqEnd: 780, harmonics: 0.2)));
  Future<void> heartsHit() => _play(_clip(
      'hearts', () => _tone(392, 0.25, freqEnd: 196, harmonics: 0.4)));
  Future<void> queenSpades() => _play(_clip(
      'queen', () => _tone(233, 0.5, freqEnd: 116, harmonics: 0.45)));
  Future<void> shootMoon() => _play(_clip('moon',
      () => _arp([523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5], 0.14, 0.02)));
  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(420, 0.32, freqEnd: 840)));
  Future<void> win() => _play(_clip(
      'win', () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));
  Future<void> lose() => _play(
      _clip('lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));

  // ----------------------------------------------------------------- music
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  Future<void> stopMusic() async {
    ++_musicGen;
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
