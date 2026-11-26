import 'package:flutter/material.dart';

/// `ColorScheme` token SPEC-V3 §2.1 untuk [brightness], dipetakan sama
/// seperti `BpTheme` aplikasi Bpedia (`surfaceContainerHigh` =
/// `surfaceRaised`). Dipakai `example/` dan tes modul serta hub supaya panel
/// gelap seragam antarmodul; aplikasi induk memakai temanya sendiri.
ColorScheme festivePreviewScheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final canvas = dark ? const Color(0xFF0F0E10) : const Color(0xFFF5F5F7);
  final surface = dark ? const Color(0xFF1A181B) : const Color(0xFFFFFFFF);
  final muted = dark ? const Color(0xFF242126) : const Color(0xFFF3F3F5);
  final raised = dark ? const Color(0xFF242126) : const Color(0xFFFFFFFF);
  final line = dark ? const Color(0xFF2E2A30) : const Color(0xFFECECEF);
  final text = dark ? const Color(0xFFF4F0F2) : const Color(0xFF1F1A1D);
  final textMuted = dark ? const Color(0xFFB5ADB2) : const Color(0xFF6B6468);
  final textFaint = dark ? const Color(0xFF857D82) : const Color(0xFF9A9398);
  final brand = dark ? const Color(0xFFFF7AA0) : const Color(0xFFD81F57);
  final onBrand = dark ? const Color(0xFF2A0A18) : const Color(0xFFFFFFFF);
  final brandStrong = dark ? const Color(0xFFF9A2C1) : const Color(0xFFB3164B);
  final brandTint = dark ? const Color(0xFF3B1026) : const Color(0xFFFDE7EC);
  final goldTint = dark ? const Color(0xFF3A2C0A) : const Color(0xFFFFF4DB);
  final onGoldTint = dark ? const Color(0xFFFFD98A) : const Color(0xFF8A5A00);
  final danger = dark ? const Color(0xFFFF5C7A) : const Color(0xFFE5173F);
  final dangerTint = dark ? const Color(0xFF3A1414) : const Color(0xFFFDECEC);
  return ColorScheme(
    brightness: brightness,
    primary: brand,
    onPrimary: onBrand,
    primaryContainer: brandTint,
    onPrimaryContainer: brandStrong,
    secondary: brandStrong,
    onSecondary: dark ? onBrand : surface,
    secondaryContainer: brandTint,
    onSecondaryContainer: brandStrong,
    tertiary: onGoldTint,
    onTertiary: dark ? goldTint : surface,
    tertiaryContainer: goldTint,
    onTertiaryContainer: onGoldTint,
    error: danger,
    onError: dark ? onBrand : surface,
    errorContainer: dangerTint,
    onErrorContainer: danger,
    surface: surface,
    onSurface: text,
    onSurfaceVariant: textMuted,
    surfaceDim: canvas,
    surfaceBright: raised,
    surfaceContainerLowest: surface,
    surfaceContainerLow: surface,
    surfaceContainer: muted,
    surfaceContainerHigh: raised,
    surfaceContainerHighest: muted,
    outline: textFaint,
    outlineVariant: line,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: dark ? text : const Color(0xFF1F1A1D),
    onInverseSurface: dark ? canvas : const Color(0xFFFFFFFF),
    inversePrimary: dark ? const Color(0xFFD81F57) : const Color(0xFFFF7AA0),
    surfaceTint: Colors.transparent,
  );
}

/// `ThemeData` pratinjau bertoken Bpedia untuk [brightness]: skema
/// [festivePreviewScheme], latar `canvas`, dan [fontFamily] (bawaan Poppins,
/// berkas fontnya disediakan host).
ThemeData festivePreviewTheme(Brightness brightness, {String? fontFamily = 'Poppins'}) {
  final scheme = festivePreviewScheme(brightness);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: fontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceDim,
    canvasColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: scheme.outlineVariant,
    ),
  );
}
