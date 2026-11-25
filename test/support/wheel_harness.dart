import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

/// Kamis, 26 November 2026 pukul 10.00 WIB.
final DateTime thursday = DateTime.utc(2026, 11, 26, 3);

/// Sabtu, 28 November 2026 pukul 10.00 WIB.
final DateTime saturday = DateTime.utc(2026, 11, 28, 3);

/// Hari WIB Sabtu 28 Nov 2026.
final int saturdayDay = wheelWibDayOf(saturday);

/// Produk hadiah minggu ini dari katalog demo (gambar dari `example/`).
final WheelPrizeProduct demoPrizeProduct = WheelPrizeProduct(
  code: 'P21P03C01000082',
  name: 'Pinkflash Duo Lipgloss Pf-L13 - D02',
  image: FileImage(File('example/assets/products/P21P03C01000082.webp')),
  price: 23230,
);

/// Riwayat contoh: dua Sabtu sebelumnya.
final List<WheelSpinRecord> demoHistory = <WheelSpinRecord>[
  WheelSpinRecord.fromPrize(
    demoSpinConfig.prizeById('kelopak-5')!,
    day: saturdayDay - 7,
  ),
  WheelSpinRecord.fromPrize(
    demoSpinConfig.prizeById('kelopak-1')!,
    day: saturdayDay - 14,
  ),
];

/// Pengendali lokal dengan jam tetap.
LocalWheelController localWheel({
  DateTime? now,
  bool signedIn = true,
  bool promoActive = true,
  int balance = 24,
  int quota = 3,
  int? lastSpinDay,
  List<WheelSpinRecord>? history,
  bool withProduct = true,
  bool reminderSupported = true,
  bool reminderOn = false,
  bool? soundOn = true,
  Duration latency = Duration.zero,
  int seed = 42,
}) {
  final DateTime fixed = now ?? saturday;
  return LocalWheelController(
    clock: () => fixed,
    signedIn: signedIn,
    promoActive: promoActive,
    balance: balance,
    productQuotaLeft: quota,
    lastSpinDay: lastSpinDay,
    history: history ?? demoHistory,
    product: withProduct ? demoPrizeProduct : null,
    reminderSupported: reminderSupported,
    reminderOn: reminderOn,
    soundOn: soundOn,
    latency: latency,
    random: math.Random(seed),
  );
}

/// Skema warna host sesuai token SPEC-V3 §2.1 (terang putih, gelap netral).
ColorScheme hostScheme(Brightness brightness) {
  return switch (brightness) {
    Brightness.light => const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFFD81F57),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFFDE7EC),
      onPrimaryContainer: Color(0xFFB3164B),
      secondary: Color(0xFFB3164B),
      onSecondary: Color(0xFFFFFFFF),
      tertiary: Color(0xFFF5B83D),
      onTertiary: Color(0xFF2A0A18),
      tertiaryContainer: Color(0xFFFFF4DB),
      onTertiaryContainer: Color(0xFF8A5A00),
      error: Color(0xFFC62828),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1F1A1D),
      onSurfaceVariant: Color(0xFF6B6468),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF5F5F7),
      surfaceContainer: Color(0xFFF3F3F5),
      surfaceContainerHighest: Color(0xFFF3F3F5),
      outline: Color(0xFF9A9398),
      outlineVariant: Color(0xFFECECEF),
    ),
    Brightness.dark => const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFF7AA0),
      onPrimary: Color(0xFF2A0A18),
      primaryContainer: Color(0xFF3B1026),
      onPrimaryContainer: Color(0xFFF9A2C1),
      secondary: Color(0xFFF9A2C1),
      onSecondary: Color(0xFF2A0A18),
      tertiary: Color(0xFFF5B83D),
      onTertiary: Color(0xFF2A0A18),
      tertiaryContainer: Color(0xFF3A2C0A),
      onTertiaryContainer: Color(0xFFFFD98A),
      error: Color(0xFFFF8A80),
      onError: Color(0xFF2A0A18),
      surface: Color(0xFF1A181B),
      onSurface: Color(0xFFF4F0F2),
      onSurfaceVariant: Color(0xFFB5ADB2),
      surfaceContainerLowest: Color(0xFF0F0E10),
      surfaceContainerLow: Color(0xFF1A181B),
      surfaceContainer: Color(0xFF242126),
      surfaceContainerHighest: Color(0xFF242126),
      outline: Color(0xFF857D82),
      outlineVariant: Color(0xFF2E2A30),
    ),
  };
}

/// Tema host: Poppins dan warna token.
ThemeData hostTheme(Brightness brightness) => ThemeData(
  fontFamily: 'Poppins',
  colorScheme: hostScheme(brightness),
  scaffoldBackgroundColor: brightness == Brightness.light
      ? const Color(0xFFF5F5F7)
      : const Color(0xFF0F0E10),
);

/// Aplikasi uji yang memasang [child] dengan tema host.
Widget wheelApp(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: hostTheme(Brightness.light),
    darkTheme: hostTheme(Brightness.dark),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child,
      ),
    ),
  );
}

/// Halaman Roda Sabtu lengkap di atas [controller].
Widget wheelPageApp(
  WheelController controller, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool disableAnimations = false,
  bool ambientMotion = true,
}) {
  return wheelApp(
    WheelPage(controller: controller, ambientMotion: ambientMotion),
    brightness: brightness,
    textScale: textScale,
    disableAnimations: disableAnimations,
  );
}
