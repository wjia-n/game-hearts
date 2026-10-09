import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final audio = HeartsAudio();
  final settings = HeartsSettings();
  await settings.load();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  // Keep audio in sync when settings change anywhere.
  settings.addListener(() {
    audio.configure(
      musicOn: settings.musicOn,
      sfxOn: settings.sfxOn,
      volume: settings.volume,
    );
    if (!settings.musicOn) {
      audio.stopMusic();
    }
  });
  runApp(HeartsApp(audio: audio, settings: settings));
}

class HeartsApp extends StatefulWidget {
  final HeartsAudio audio;
  final HeartsSettings settings;
  const HeartsApp(
      {super.key, required this.audio, required this.settings});

  @override
  State<HeartsApp> createState() => _HeartsAppState();
}

class _HeartsAppState extends State<HeartsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The game screen also observes lifecycle for engine pausing; the app
    // shell owns music pause/resume so it always happens exactly once.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    widget.settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hearts by WAJIHA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: SplashScreen(
        audio: widget.audio,
        settings: widget.settings,
      ),
    );
  }
}
