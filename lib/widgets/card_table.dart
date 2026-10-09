import 'package:flutter/material.dart';
import '../engine/hearts_engine.dart';
import '../theme/hearts_themes.dart';

/// Pseudo-3D playing cards + felt table dressing for Hearts.
/// Cards are drawn as physical objects: ivory faces, rounded corners,
/// drop shadows, embossed backs — never flat neon panels.

class FeltBackdrop extends StatelessWidget {
  final HeartsThemeDef theme;
  final Widget child;
  const FeltBackdrop({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 1.15,
          colors: [theme.felt, theme.feltDark],
        ),
      ),
      child: child,
    );
  }
}

/// A single playing card rendered as a physical object.
/// [faceUp] false draws the decorative back.
class PlayingCard extends StatelessWidget {
  final int card;
  final HeartsThemeDef theme;
  final CardStyleDef style;
  final double width;
  final bool faceUp;
  final bool highlighted;
  final bool dimmed;
  final VoidCallback? onTap;

  const PlayingCard({
    super.key,
    required this.card,
    required this.theme,
    required this.style,
    this.width = 56,
    this.faceUp = true,
    this.highlighted = false,
    this.dimmed = false,
    this.onTap,
  });

  double get height => width * 1.42;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            offset: Offset(0, width * 0.06),
            blurRadius: width * 0.1,
          ),
          if (highlighted)
            BoxShadow(
              color: theme.accent.withValues(alpha: 0.75),
              blurRadius: width * 0.14,
            ),
        ],
      ),
      child: CustomPaint(
        painter: _CardPainter(
          card: card,
          theme: theme,
          style: style,
          faceUp: faceUp,
        ),
      ),
    );
    final wrapped = dimmed
        ? Opacity(opacity: 0.45, child: body)
        : body;
    if (onTap == null) return wrapped;
    return GestureDetector(onTap: onTap, child: wrapped);
  }
}

/// Card-face labels shared by the painter (mirrors engine rank/suit order).
const _ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
const _suitGlyphs = ['♣', '♦', '♠', '♥'];

class _CardPainter extends CustomPainter {
  final int card;
  final HeartsThemeDef theme;
  final CardStyleDef style;
  final bool faceUp;

  _CardPainter({
    required this.card,
    required this.theme,
    required this.style,
    required this.faceUp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.width * 0.12);
    final rect = Offset.zero & size;

    // Card body.
    final bodyPaint = Paint()
      ..color = faceUp ? style.front : style.back;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, r), bodyPaint);

    // Subtle top-light bevel for physical depth.
    final bevel = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: faceUp ? 0.35 : 0.18),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.12),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, r), bevel);

    if (faceUp) {
      _paintFace(canvas, size);
    } else {
      _paintBack(canvas, size, r);
    }

    // Thin edge.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.75), r),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = faceUp
            ? style.frontEdge
            : style.backBorder.withValues(alpha: 0.9),
    );
  }

  void _paintFace(Canvas canvas, Size size) {
    final red = isRedSuit(card);
    final color = red ? theme.redSuit : theme.blackSuit;
    final rank = _ranksOf(card);
    final glyph = _glyphOf(card);
    final w = size.width;

    final cornerStyle = TextStyle(
      color: color,
      fontSize: w * 0.24,
      fontWeight: FontWeight.w700,
      height: 1.0,
    );
    final glyphStyle = TextStyle(
      color: color,
      fontSize: w * 0.2,
      height: 1.0,
    );

    void corner(Offset o) {
      _text(canvas, rank, cornerStyle, o, align: TextAlign.center);
      _text(canvas, glyph, glyphStyle, o + Offset(0, w * 0.26),
          align: TextAlign.center);
    }

    corner(Offset(w * 0.16, w * 0.1));
    // Bottom-right corner, rotated.
    canvas.save();
    canvas.translate(size.width - w * 0.16, size.height - w * 0.1);
    canvas.rotate(3.14159);
    canvas.translate(-(w * 0.16), -(w * 0.1));
    corner(Offset(w * 0.16, w * 0.1));
    canvas.restore();

    // Big center pip.
    final bigStyle = TextStyle(
      color: color,
      fontSize: w * (rank == '10' ? 0.42 : 0.52),
      fontWeight: FontWeight.w700,
      height: 1.0,
    );
    if (rank == 'A') {
      _text(canvas, glyph,
          TextStyle(color: color, fontSize: w * 0.85, height: 1.0),
          Offset(size.width / 2, size.height / 2),
          align: TextAlign.center);
    } else if ('JQK'.contains(rank)) {
      // Court cards: framed medallion with the rank initial.
      final c = Offset(size.width / 2, size.height / 2);
      final frame = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: w * 0.62, height: w * 0.72),
        Radius.circular(w * 0.08),
      );
      canvas.drawRRect(
          frame,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.03
            ..color = color.withValues(alpha: 0.7));
      _text(canvas, rank, bigStyle, c, align: TextAlign.center);
      _text(
          canvas,
          glyph,
          TextStyle(color: color, fontSize: w * 0.26, height: 1.0),
          c + Offset(0, w * 0.34),
          align: TextAlign.center);
    } else {
      _text(canvas, rank, bigStyle,
          Offset(size.width / 2, size.height / 2 - w * 0.12),
          align: TextAlign.center);
      _text(
          canvas,
          glyph,
          TextStyle(color: color, fontSize: w * 0.4, height: 1.0),
          Offset(size.width / 2, size.height / 2 + w * 0.24),
          align: TextAlign.center);
    }
  }

  void _paintBack(Canvas canvas, Size size, Radius r) {
    final rect = Offset.zero & size;
    // Inner border.
    final inner = rect.deflate(size.width * 0.09);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(size.width * 0.07)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.03
        ..color = style.backBorder.withValues(alpha: 0.85),
    );
    // Pattern.
    final pat = Paint()..color = style.backPattern.withValues(alpha: 0.5);
    final step = size.width * 0.18;
    final area = inner.deflate(size.width * 0.05);
    switch (style.pattern) {
      case 'diamond':
        for (double y = area.top; y < area.bottom; y += step) {
          for (double x = area.left; x < area.right; x += step) {
            final p = Path()
              ..moveTo(x + step / 2, y)
              ..lineTo(x + step, y + step / 2)
              ..lineTo(x + step / 2, y + step)
              ..lineTo(x, y + step / 2)
              ..close();
            canvas.drawPath(p, pat);
          }
        }
        break;
      case 'checker':
        bool flip = false;
        for (double y = area.top; y < area.bottom; y += step) {
          flip = !flip;
          for (double x = area.left; x < area.right; x += step) {
            if (flip = !flip) {
              canvas.drawRect(Rect.fromLTWH(x, y, step, step), pat);
            }
          }
        }
        break;
      case 'scroll':
        for (double y = area.top + step / 2;
            y < area.bottom;
            y += step) {
          for (double x = area.left + step / 2;
              x < area.right;
              x += step) {
            canvas.drawCircle(Offset(x, y), step * 0.28, pat);
          }
        }
        break;
      case 'floral':
        for (double y = area.top + step / 2;
            y < area.bottom;
            y += step) {
          for (double x = area.left + step / 2;
              x < area.right;
              x += step) {
            for (int k = 0; k < 4; k++) {
              final a = k * 1.5708;
              canvas.drawCircle(
                  Offset(x, y) + Offset.fromDirection(a, step * 0.2),
                  step * 0.16,
                  pat);
            }
          }
        }
        break;
    }
  }

  void _text(Canvas canvas, String s, TextStyle style, Offset center,
      {required TextAlign align}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  String _ranksOf(int c) => _ranks[cardRank(c)];
  String _glyphOf(int c) => _suitGlyphs[cardSuit(c)];

  @override
  bool shouldRepaint(covariant _CardPainter old) =>
      old.card != card ||
      old.faceUp != faceUp ||
      old.theme != theme ||
      old.style != style;
}

/// Player name plate shown at a seat.
class SeatPlate extends StatelessWidget {
  final String name;
  final Color color;
  final bool active;
  final bool isBot;
  final int handCount;
  final int handPoints;
  final int total;

  const SeatPlate({
    super.key,
    required this.name,
    required this.color,
    required this.active,
    required this.isBot,
    required this.handCount,
    required this.handPoints,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(
          color: active ? color : Colors.white.withValues(alpha: 0.18),
          width: active ? 2.5 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.5), blurRadius: 10)
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (isBot)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text('🤖',
                      style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '🂠 $handCount   ♥ $handPoints   Σ $total',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Brass-style button fitting the card-table art direction.
class FeltButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;

  const FeltButton({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = _ThemeOf(context);
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: primary
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [theme.accentLight, theme.accent],
                )
              : null,
          color: primary ? null : Colors.black.withValues(alpha: 0.5),
          border: Border.all(
            color: primary
                ? theme.accentLight.withValues(alpha: 0.6)
                : theme.ivory.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon,
                        size: 18,
                        color: primary
                            ? theme.railDark
                            : theme.ivory),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: primary ? theme.railDark : theme.ivory,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

HeartsThemeDef _ThemeOf(BuildContext context) {
  final t = context
      .dependOnInheritedWidgetOfExactType<_ThemeScope>()
      ?.theme;
  return t ?? HeartsThemes.all.first;
}

class _ThemeScope extends InheritedWidget {
  final HeartsThemeDef theme;
  const _ThemeScope({required this.theme, required super.child});

  @override
  bool updateShouldNotify(covariant _ThemeScope old) =>
      old.theme != theme;
}

/// Wrap children in both scopes (ThemeScope delegates to _ThemeScope).
class FeltTheme extends StatelessWidget {
  final HeartsThemeDef theme;
  final Widget child;
  const FeltTheme({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return _ThemeScope(theme: theme, child: child);
  }
}
