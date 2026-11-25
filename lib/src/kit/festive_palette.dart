import 'package:flutter/material.dart';

/// Palet pesta zona game (SPEC-V3 §2.1.3). Sama di tema terang dan gelap.
abstract final class FestivePalette {
  static const Color festTop = Color(0xFFFF8FB1);
  static const Color festMid = Color(0xFFF0447A);
  static const Color festBottom = Color(0xFFB3164B);
  static const Color festDeep = Color(0xFF6B1439);
  static const Color festCream = Color(0xFFFFF6E9);
  static const Color festBlush = Color(0xFFFFE3EC);
  static const Color festPetal = Color(0xFFFF8FB1);

  static const Color goldLight = Color(0xFFFFE08A);
  static const Color gold = Color(0xFFF5B83D);
  static const Color goldDeep = Color(0xFFC98A0A);

  static const Color candyTop = Color(0xFFFF6B98);
  static const Color candyBottom = Color(0xFFD81F57);
  static const Color candyLip = Color(0xFF9E1242);

  /// Teks gelap di atas emas (kontras 7:1 terhadap [gold]).
  static const Color onGold = Color(0xFF4A2A00);

  /// Gradasi hero, atas ke bawah.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[festTop, festMid, festBottom],
    stops: <double>[0, 0.52, 1],
  );

  /// Gradasi radial panggung (latar roda, lembar hasil).
  static const RadialGradient stage = RadialGradient(
    center: Alignment(0, -0.3),
    radius: 1.15,
    colors: <Color>[festTop, candyBottom, festDeep],
    stops: <double>[0, 0.55, 1],
  );

  static const LinearGradient goldSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[goldLight, gold, goldDeep],
  );

  static const LinearGradient candy = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[candyTop, candyBottom],
  );

  /// Warna partikel konfeti.
  static const List<Color> confetti = <Color>[
    Color(0xFFFFFFFF),
    goldLight,
    gold,
    festTop,
    festMid,
    Color(0xFFD81F57),
    Color(0xFF8FE3C8),
    Color(0xFF9CC8FF),
  ];

  /// Bayangan panel pesta: `0 10 30 rgba(179,22,75,.16)`.
  static const List<BoxShadow> panelShadow = <BoxShadow>[
    BoxShadow(color: Color(0x29B3164B), blurRadius: 30, offset: Offset(0, 10)),
  ];

  /// Warna panel di atas latar host: `surface` pada tema terang, sedikit
  /// terangkat pada tema gelap supaya terpisah dari latar tanpa bayangan.
  static Color panelColor(ColorScheme scheme) {
    if (scheme.brightness == Brightness.light) return scheme.surface;
    return Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.06), scheme.surface);
  }

  /// Garis tipis panel dan pemisah.
  static Color lineColor(ColorScheme scheme) =>
      Color.alphaBlend(scheme.onSurface.withValues(alpha: scheme.brightness == Brightness.light ? 0.08 : 0.12), scheme.surface);
}
