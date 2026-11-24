import 'package:flutter/material.dart';

/// Light ColorScheme of the hub (SPEC-CONTRACT section 3), so module widgets
/// are exercised with the same roles they get in the app.
ThemeData brandTestTheme() {
  const ColorScheme scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFD81F57),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFDE7EC),
    onPrimaryContainer: Color(0xFF45122B),
    secondary: Color(0xFFB3164B),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFBCFDB),
    onSecondaryContainer: Color(0xFF45122B),
    tertiary: Color(0xFFF5B83D),
    onTertiary: Color(0xFF2A0A18),
    tertiaryContainer: Color(0xFFFFF4DB),
    onTertiaryContainer: Color(0xFF8A5A00),
    error: Color(0xFFC62828),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFFFF7F8),
    onSurface: Color(0xFF45122B),
    onSurfaceVariant: Color(0xFF6E4556),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFF7F8),
    surfaceContainer: Color(0xFFFDE7EC),
    outline: Color(0xFF9C7E8A),
    outlineVariant: Color(0xFFF3D3DD),
  );
  return ThemeData(colorScheme: scheme);
}

/// Wraps [child] in an app with the brand theme inside a vertical scroll
/// view, like the hub's Roda Sabtu screen.
Widget harness(
  Widget child, {
  bool disableAnimations = false,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: brandTestTheme(),
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}
