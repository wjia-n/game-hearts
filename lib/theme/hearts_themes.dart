import 'package:flutter/material.dart';

/// Theme catalog for Hearts — a real card-table material world.
/// Felt tables, wooden rails, brass accents. No neon anywhere.
class HeartsThemeDef {
  final String id;
  final String name;
  final Color felt; // table surface
  final Color feltDark; // table vignette
  final Color rail; // wooden rail
  final Color railDark;
  final Color accent; // brass / gold
  final Color accentLight;
  final Color ivory; // readable text
  final Color ivoryDim;
  final Color redSuit;
  final Color blackSuit;
  final List<Color> seatColors;

  const HeartsThemeDef({
    required this.id,
    required this.name,
    required this.felt,
    required this.feltDark,
    required this.rail,
    required this.railDark,
    required this.accent,
    required this.accentLight,
    required this.ivory,
    required this.ivoryDim,
    required this.redSuit,
    required this.blackSuit,
    required this.seatColors,
  });
}

class CardStyleDef {
  final String id;
  final String name;
  final Color front;
  final Color frontEdge;
  final Color back;
  final Color backPattern;
  final Color backBorder;
  final String pattern; // 'diamond' | 'scroll' | 'checker' | 'floral'

  const CardStyleDef({
    required this.id,
    required this.name,
    required this.front,
    required this.frontEdge,
    required this.back,
    required this.backPattern,
    required this.backBorder,
    required this.pattern,
  });
}

class HeartsThemes {
  /// First 4 are the FREE starter themes. The rest unlock with Pro.
  static const List<String> freeThemeIds = [
    'classic',
    'emerald',
    'walnut',
    'midnight',
  ];

  /// First 3 card styles are free; the rest unlock with Pro.
  static const List<String> freeCardStyleIds = [
    'ivory',
    'parchment',
    'porcelain',
  ];

  static bool isProTheme(String id) => !freeThemeIds.contains(id);
  static bool isProCardStyle(String id) => !freeCardStyleIds.contains(id);

  static const List<HeartsThemeDef> all = [
    HeartsThemeDef(
      id: 'classic',
      name: 'Classic Casino',
      felt: Color(0xFF1E5B3A),
      feltDark: Color(0xFF0E3320),
      rail: Color(0xFF5C3A21),
      railDark: Color(0xFF2E1C0F),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      ivory: Color(0xFFF5EFE0),
      ivoryDim: Color(0xFFCFC3A8),
      redSuit: Color(0xFFB3122E),
      blackSuit: Color(0xFF1A1A22),
      seatColors: [
        Color(0xFFC9A227),
        Color(0xFF8FB8D8),
        Color(0xFFD98E8E),
        Color(0xFF9FD8A8),
      ],
    ),
    HeartsThemeDef(
      id: 'emerald',
      name: 'Emerald Room',
      felt: Color(0xFF0F6E4E),
      feltDark: Color(0xFF073B2A),
      rail: Color(0xFF3E2A16),
      railDark: Color(0xFF1D130A),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF2DD9A),
      ivory: Color(0xFFF7F2E4),
      ivoryDim: Color(0xFFD3C9AE),
      redSuit: Color(0xFFC01330),
      blackSuit: Color(0xFF14141C),
      seatColors: [
        Color(0xFFD4AF37),
        Color(0xFF7FD0C0),
        Color(0xFFF0A8A8),
        Color(0xFFB8E08A),
      ],
    ),
    HeartsThemeDef(
      id: 'walnut',
      name: 'Walnut Study',
      felt: Color(0xFF4A6741),
      feltDark: Color(0xFF283B24),
      rail: Color(0xFF4A2E18),
      railDark: Color(0xFF241407),
      accent: Color(0xFFB98A2F),
      accentLight: Color(0xFFE3BE6E),
      ivory: Color(0xFFF3EBD6),
      ivoryDim: Color(0xFFC9B998),
      redSuit: Color(0xFFA30E28),
      blackSuit: Color(0xFF201A14),
      seatColors: [
        Color(0xFFB98A2F),
        Color(0xFF9AB8D0),
        Color(0xFFD08A8A),
        Color(0xFFA8C890),
      ],
    ),
    HeartsThemeDef(
      id: 'midnight',
      name: 'Midnight Blue',
      felt: Color(0xFF1F3A5F),
      feltDark: Color(0xFF0E1C33),
      rail: Color(0xFF2E2018),
      railDark: Color(0xFF150E08),
      accent: Color(0xFFC0C8D8),
      accentLight: Color(0xFFE8ECF5),
      ivory: Color(0xFFF0EFE8),
      ivoryDim: Color(0xFFC2C0B4),
      redSuit: Color(0xFFD21F3C),
      blackSuit: Color(0xFF0E0E14),
      seatColors: [
        Color(0xFFC0C8D8),
        Color(0xFF7FB8E0),
        Color(0xFFE08A8A),
        Color(0xFF90D8A0),
      ],
    ),
    // ------------------------------ PRO themes ------------------------------
    HeartsThemeDef(
      id: 'burgundy',
      name: 'Burgundy Velvet',
      felt: Color(0xFF6E1F2E),
      feltDark: Color(0xFF3A0F18),
      rail: Color(0xFF3A2415),
      railDark: Color(0xFF1A1008),
      accent: Color(0xFFD4A24A),
      accentLight: Color(0xFFF0CE8A),
      ivory: Color(0xFFF6EEE2),
      ivoryDim: Color(0xFFD2C2AC),
      redSuit: Color(0xFFC8102E),
      blackSuit: Color(0xFF181018),
      seatColors: [
        Color(0xFFD4A24A),
        Color(0xFF9AC8E0),
        Color(0xFFE8B8B8),
        Color(0xFFB0D898),
      ],
    ),
    HeartsThemeDef(
      id: 'cherry',
      name: 'Cherrywood',
      felt: Color(0xFF2E6E4E),
      feltDark: Color(0xFF173B29),
      rail: Color(0xFF6E2A1A),
      railDark: Color(0xFF38130B),
      accent: Color(0xFFE0B34A),
      accentLight: Color(0xFFF5DC9A),
      ivory: Color(0xFFF7F0E0),
      ivoryDim: Color(0xFFD4C4A4),
      redSuit: Color(0xFFB8122C),
      blackSuit: Color(0xFF1C1410),
      seatColors: [
        Color(0xFFE0B34A),
        Color(0xFF8AC0D8),
        Color(0xFFE09A9A),
        Color(0xFFA0D090),
      ],
    ),
    HeartsThemeDef(
      id: 'slate',
      name: 'Slate & Steel',
      felt: Color(0xFF3E4A54),
      feltDark: Color(0xFF20272E),
      rail: Color(0xFF2A2018),
      railDark: Color(0xFF120D08),
      accent: Color(0xFFB8C0CC),
      accentLight: Color(0xFFDEE4EC),
      ivory: Color(0xFFF2F0EA),
      ivoryDim: Color(0xFFC8C4B8),
      redSuit: Color(0xFFC81834),
      blackSuit: Color(0xFF101418),
      seatColors: [
        Color(0xFFB8C0CC),
        Color(0xFF88B8D8),
        Color(0xFFD89898),
        Color(0xFF98C898),
      ],
    ),
    HeartsThemeDef(
      id: 'olive',
      name: 'Olive Grove',
      felt: Color(0xFF5A6234),
      feltDark: Color(0xFF30351B),
      rail: Color(0xFF4A3018),
      railDark: Color(0xFF221408),
      accent: Color(0xFFC9A44A),
      accentLight: Color(0xFFE8CE8A),
      ivory: Color(0xFFF4EEDC),
      ivoryDim: Color(0xFFCFC09E),
      redSuit: Color(0xFFB0142E),
      blackSuit: Color(0xFF1E1A12),
      seatColors: [
        Color(0xFFC9A44A),
        Color(0xFF9ABED8),
        Color(0xFFD89A9A),
        Color(0xFFA8D098),
      ],
    ),
    HeartsThemeDef(
      id: 'charcoal',
      name: 'Charcoal Club',
      felt: Color(0xFF2E2E34),
      feltDark: Color(0xFF141416),
      rail: Color(0xFF201812),
      railDark: Color(0xFF0E0A06),
      accent: Color(0xFFD0B060),
      accentLight: Color(0xFFEAD89A),
      ivory: Color(0xFFF0ECE0),
      ivoryDim: Color(0xFFC4BCA8),
      redSuit: Color(0xFFD42040),
      blackSuit: Color(0xFF08080C),
      seatColors: [
        Color(0xFFD0B060),
        Color(0xFF8AC0DC),
        Color(0xFFE0A0A0),
        Color(0xFFA0D8A0),
      ],
    ),
    HeartsThemeDef(
      id: 'ivorysalon',
      name: 'Ivory Salon',
      felt: Color(0xFFD8CFB8),
      feltDark: Color(0xFFA89A78),
      rail: Color(0xFF4A2E18),
      railDark: Color(0xFF241407),
      accent: Color(0xFF8A6D1A),
      accentLight: Color(0xFFB8943A),
      ivory: Color(0xFF2E2418),
      ivoryDim: Color(0xFF5C5142),
      redSuit: Color(0xFF9E0C26),
      blackSuit: Color(0xFF1A1410),
      seatColors: [
        Color(0xFF8A6D1A),
        Color(0xFF3A6E9E),
        Color(0xFF9E3A3A),
        Color(0xFF3A7E4A),
      ],
    ),
    HeartsThemeDef(
      id: 'rosewood',
      name: 'Rosewood',
      felt: Color(0xFF7E3A4E),
      feltDark: Color(0xFF421C28),
      rail: Color(0xFF3E1E12),
      railDark: Color(0xFF1C0D06),
      accent: Color(0xFFDCB45A),
      accentLight: Color(0xFFF2DA9A),
      ivory: Color(0xFFF6EFE0),
      ivoryDim: Color(0xFFD4C6AE),
      redSuit: Color(0xFFC41230),
      blackSuit: Color(0xFF181214),
      seatColors: [
        Color(0xFFDCB45A),
        Color(0xFF92BEE0),
        Color(0xFFE4A4A4),
        Color(0xFFA4D49A),
      ],
    ),
    HeartsThemeDef(
      id: 'forest',
      name: 'Deep Forest',
      felt: Color(0xFF14452E),
      feltDark: Color(0xFF082416),
      rail: Color(0xFF33220F),
      railDark: Color(0xFF170F06),
      accent: Color(0xFFB8922E),
      accentLight: Color(0xFFE0BE62),
      ivory: Color(0xFFF2ECDC),
      ivoryDim: Color(0xFFC8BE9E),
      redSuit: Color(0xFFB8102C),
      blackSuit: Color(0xFF121A14),
      seatColors: [
        Color(0xFFB8922E),
        Color(0xFF88B8D4),
        Color(0xFFD89494),
        Color(0xFF9CCC8E),
      ],
    ),
    HeartsThemeDef(
      id: 'teal',
      name: 'Teal Harbour',
      felt: Color(0xFF1E5A5E),
      feltDark: Color(0xFF0E3034),
      rail: Color(0xFF3A2A16),
      railDark: Color(0xFF1A1208),
      accent: Color(0xFFC9A44A),
      accentLight: Color(0xFFE6CC84),
      ivory: Color(0xFFF2EEE0),
      ivoryDim: Color(0xFFC6C0A8),
      redSuit: Color(0xFFC01432),
      blackSuit: Color(0xFF10181C),
      seatColors: [
        Color(0xFFC9A44A),
        Color(0xFF7EC8D4),
        Color(0xFFE09C9C),
        Color(0xFF9AD49C),
      ],
    ),
  ];

  static HeartsThemeDef byId(String id, {required HeartsThemeDef custom}) {
    if (id == 'custom') return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static const List<CardStyleDef> cardStyles = [
    CardStyleDef(
      id: 'ivory',
      name: 'Classic Ivory',
      front: Color(0xFFFDFBF4),
      frontEdge: Color(0xFFE4DCC6),
      back: Color(0xFF1E4D72),
      backPattern: Color(0xFFD8E2EC),
      backBorder: Color(0xFFFDFBF4),
      pattern: 'diamond',
    ),
    CardStyleDef(
      id: 'parchment',
      name: 'Aged Parchment',
      front: Color(0xFFF2E8D0),
      frontEdge: Color(0xFFD4C4A0),
      back: Color(0xFF7E2A22),
      backPattern: Color(0xFFF2E8D0),
      backBorder: Color(0xFFF2E8D0),
      pattern: 'scroll',
    ),
    CardStyleDef(
      id: 'porcelain',
      name: 'Porcelain',
      front: Color(0xFFFFFFFF),
      frontEdge: Color(0xFFDDE0E4),
      back: Color(0xFF2E5E3E),
      backPattern: Color(0xFFE8F0E4),
      backBorder: Color(0xFFFFFFFF),
      pattern: 'checker',
    ),
    CardStyleDef(
      id: 'sapphire',
      name: 'Midnight Sapphire',
      front: Color(0xFFF4F6FA),
      frontEdge: Color(0xFFC8D0DC),
      back: Color(0xFF101E3A),
      backPattern: Color(0xFFC0CCDD),
      backBorder: Color(0xFFF4F6FA),
      pattern: 'diamond',
    ),
    CardStyleDef(
      id: 'emeraldback',
      name: 'Emerald Felt',
      front: Color(0xFFF8F4E8),
      frontEdge: Color(0xFFD8D0B4),
      back: Color(0xFF0F4E30),
      backPattern: Color(0xFFD8E8D4),
      backBorder: Color(0xFFF8F4E8),
      pattern: 'floral',
    ),
    CardStyleDef(
      id: 'velvet',
      name: 'Burgundy Velvet',
      front: Color(0xFFFBF6EC),
      frontEdge: Color(0xFFE0D2B8),
      back: Color(0xFF5E1E2E),
      backPattern: Color(0xFFF0DCC8),
      backBorder: Color(0xFFFBF6EC),
      pattern: 'scroll',
    ),
    CardStyleDef(
      id: 'silk',
      name: 'Charcoal Silk',
      front: Color(0xFFF0EDE6),
      frontEdge: Color(0xFFCFC8B8),
      back: Color(0xFF23232A),
      backPattern: Color(0xFFB8B4A8),
      backBorder: Color(0xFFF0EDE6),
      pattern: 'checker',
    ),
    CardStyleDef(
      id: 'goldleaf',
      name: 'Gold Leaf',
      front: Color(0xFFFFFDF4),
      frontEdge: Color(0xFFE8DCB8),
      back: Color(0xFF8A6D1A),
      backPattern: Color(0xFFFFF0C8),
      backBorder: Color(0xFFFFFDF4),
      pattern: 'floral',
    ),
  ];

  static CardStyleDef cardStyleById(String id) {
    for (final s in cardStyles) {
      if (s.id == id) return s;
    }
    return cardStyles.first;
  }
}
