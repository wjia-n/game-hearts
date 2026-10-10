import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/hearts_themes.dart';
import '../widgets/card_table.dart';

/// Pro screen: Free-vs-Pro comparison, Pro unlock, tip jar, restore.
/// Honest when the store isn't configured yet — never a fake buy button.
class ProScreen extends StatefulWidget {
  final HeartsAudio audio;
  final HeartsSettings settings;
  final HeartsStore store;
  const ProScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.lastThanks.addListener(_onThanks);
    widget.settings.addListener(_refresh);
    widget.store.init();
  }

  
  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg != null && mounted) {
      widget.audio.win();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
      widget.store.lastThanks.value = null;
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.store.lastThanks.removeListener(_onThanks);
    widget.settings.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final theme = HeartsThemes.byId(
      settings.themeId,
      custom: settings.customTheme,
    );
    final store = widget.store;
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
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: theme.ivory),
                      onPressed: () {
                        widget.audio.click();
                        Navigator.of(context).pop();
                      },
                    ),
                    Text('Hearts PRO',
                        style: TextStyle(
                            color: theme.ivory,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                _CompareTable(theme: theme, isPro: settings.isPro),
                const SizedBox(height: 16),
                if (settings.isPro)
                  _ProActiveCard(theme: theme)
                else if (!store.storeReady)
                  _NotConfiguredCard(
                      theme: theme, error: store.error)
                else
                                  _TipJar(
                    theme: theme,
                    store: store,
                    audio: widget.audio),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareTable extends StatelessWidget {
  final HeartsThemeDef theme;
  final bool isPro;
  const _CompareTable({required this.theme, required this.isPro});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Full game — no ads, ever', true, true),
      ('4 table themes', true, true),
      ('3 classic card styles', true, true),
      ('Easy + Medium bots', true, true),
      ('Hard bot difficulty 🔥', false, true),
      ('All 13 table themes', false, true),
      ('All 8 card styles', false, true),
      ('Custom theme creator 🎨', false, true),
      ('Pass-and-play stats boost', false, true),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(
            color: theme.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                  width: 64,
                  child: Center(
                      child: Text('Free',
                          style: TextStyle(
                              color: theme.ivoryDim,
                              fontWeight: FontWeight.w700)))),
              SizedBox(
                  width: 64,
                  child: Center(
                      child: Text('PRO',
                          style: TextStyle(
                              color: theme.accentLight,
                              fontWeight: FontWeight.w800)))),
            ],
          ),
          const Divider(color: Colors.white24),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                      child: Text(r.$1,
                          style: TextStyle(
                              color: theme.ivory,
                              fontSize: 13))),
                  SizedBox(
                      width: 64,
                      child: Center(
                          child: _mark(r.$2, theme))),
                  SizedBox(
                      width: 64,
                      child: Center(
                          child: _mark(r.$3, theme,
                              gold: true))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _mark(bool yes, HeartsThemeDef theme,
      {bool gold = false}) {
    return Text(yes ? '✓' : '—',
        style: TextStyle(
            color: yes
                ? (gold ? theme.accentLight : theme.ivory)
                : theme.ivoryDim.withValues(alpha: 0.5),
            fontWeight: FontWeight.w800,
            fontSize: 16));
  }
}

class _ProActiveCard extends StatelessWidget {
  final HeartsThemeDef theme;
  const _ProActiveCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: [
          theme.accent.withValues(alpha: 0.35),
          theme.accent.withValues(alpha: 0.12),
        ]),
        border: Border.all(color: theme.accent),
      ),
      child: Row(
        children: [
          const Text('👑', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You are PRO — every theme, card style and the Hard bots are yours. Thanks for supporting indie games! ♥️',
              style: TextStyle(
                  color: theme.ivory,
                  fontSize: 14,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotConfiguredCard extends StatelessWidget {
  final HeartsThemeDef theme;
  final String? error;
  const _NotConfiguredCard({required this.theme, required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(
            color: theme.ivory.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text('🂠',
              style: TextStyle(
                  fontSize: 36,
                  color: theme.ivoryDim)),
          const SizedBox(height: 8),
          Text(
            'Pro unlocks are being set up in the store.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: theme.ivory,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'The full game stays free — Pro goodies will appear here automatically once the store listing is live.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: theme.ivoryDim, fontSize: 13),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error!,
                style: TextStyle(
                    color: theme.ivoryDim, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _TipJar extends StatelessWidget {
  final HeartsThemeDef theme;
  final HeartsStore store;
  final HeartsAudio audio;
  const _TipJar(
      {required this.theme,
      required this.store,
      required this.audio});

  @override
  Widget build(BuildContext context) {
    if (!store.storeReady) return const SizedBox.shrink();
    final tips = [
      (store.coffeeProduct, '☕', 'Coffee'),
      (store.chocolateProduct, '🍫', 'Chocolate'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(
            color: theme.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text('Love the game? Tip the maker ♥️',
              style: TextStyle(
                  color: theme.ivory,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final t in tips)
                if (t.$1 != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6),
                    child: FeltButton(
                      label: '${t.$2} ${t.$1!.price}',
                      primary: false,
                      onPressed: () {
                        audio.click();
                        store.buyTip(t.$1!);
                      },
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 6),
          Text('100% optional — the game is fully free.',
              style: TextStyle(
                  color: theme.ivoryDim, fontSize: 11)),
        ],
      ),
    );
  }
}
