import 'package:flutter/material.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

void main() => runApp(const WheelExampleApp());

/// Produk hadiah roda dari katalog demo Bpedia (bergilir tiap minggu).
const List<WheelPrizeProduct> demoPrizeProducts = <WheelPrizeProduct>[
  WheelPrizeProduct(
    code: 'P21P03C01000082',
    name: 'Pinkflash Duo Lipgloss Pf-L13 - D02',
    image: AssetImage('assets/products/P21P03C01000082.webp'),
    price: 23230,
  ),
  WheelPrizeProduct(
    code: 'P21F02C01000031',
    name: 'Focallure Air Fit Matte Liquid Lipstick Or01',
    image: AssetImage('assets/products/P21F02C01000031.webp'),
    price: 49091,
  ),
  WheelPrizeProduct(
    code: 'P21P03C01000171',
    name: 'Pinkflash L02 Lasting Glossy Lipgloss - G03',
    image: AssetImage('assets/products/P21P03C01000171.webp'),
    price: 11439,
  ),
  WheelPrizeProduct(
    code: 'P21P03C01000189',
    name: 'Pinkflash Lasting Moist Lipbalm Pf-L03 - #4',
    image: AssetImage('assets/products/P21P03C01000189.webp'),
    price: 14000,
  ),
];

/// Produk hadiah untuk minggu yang memuat hari WIB [day].
WheelPrizeProduct prizeOfWeek(int day) =>
    demoPrizeProducts[(day ~/ 7) % demoPrizeProducts.length];

/// Tema contoh: Poppins dan token warna SPEC-V3 (terang putih, gelap netral).
ThemeData exampleTheme(Brightness brightness) {
  final bool light = brightness == Brightness.light;
  return ThemeData(
    fontFamily: 'Poppins',
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: light ? const Color(0xFFD81F57) : const Color(0xFFFF7AA0),
      onPrimary: light ? Colors.white : const Color(0xFF2A0A18),
      primaryContainer: light
          ? const Color(0xFFFDE7EC)
          : const Color(0xFF3B1026),
      onPrimaryContainer: light
          ? const Color(0xFFB3164B)
          : const Color(0xFFF9A2C1),
      secondary: light ? const Color(0xFFB3164B) : const Color(0xFFF9A2C1),
      onSecondary: light ? Colors.white : const Color(0xFF2A0A18),
      tertiary: const Color(0xFFF5B83D),
      onTertiary: const Color(0xFF2A0A18),
      error: light ? const Color(0xFFC62828) : const Color(0xFFFF8A80),
      onError: light ? Colors.white : const Color(0xFF2A0A18),
      surface: light ? Colors.white : const Color(0xFF1A181B),
      onSurface: light ? const Color(0xFF1F1A1D) : const Color(0xFFF4F0F2),
      onSurfaceVariant: light
          ? const Color(0xFF6B6468)
          : const Color(0xFFB5ADB2),
      surfaceContainerHighest: light
          ? const Color(0xFFF3F3F5)
          : const Color(0xFF242126),
      outline: light ? const Color(0xFF9A9398) : const Color(0xFF857D82),
      outlineVariant: light ? const Color(0xFFECECEF) : const Color(0xFF2E2A30),
    ),
  );
}

/// Aplikasi contoh: halaman Roda Sabtu di atas [LocalWheelController] dan
/// panel uji untuk mengganti hari, status, kuota, hasil, dan tema.
class WheelExampleApp extends StatefulWidget {
  /// Membuat aplikasi contoh.
  const WheelExampleApp({super.key, this.controller});

  /// Pengendali yang dipakai; bawaan: saldo 24 Kelopak, kuota 3.
  final LocalWheelController? controller;

  @override
  State<WheelExampleApp> createState() => _WheelExampleAppState();
}

class _WheelExampleAppState extends State<WheelExampleApp> {
  final GlobalKey<ScaffoldMessengerState> _messenger =
      GlobalKey<ScaffoldMessengerState>();
  late final LocalWheelController _controller =
      widget.controller ??
      LocalWheelController(
        balance: 24,
        product: prizeOfWeek(wheelWibDayOf(DateTime.now())),
        soundOn: true,
        onOpen: _onOpen,
      );
  ThemeMode _themeMode = ThemeMode.light;
  bool _reduceMotion = false;

  void _onOpen(String target) {
    final String message = switch (target) {
      'login' => 'Masuk sebagai pengguna demo.',
      'shop' => 'Host membuka katalog belanja.',
      'cart' => 'Host membuka keranjang.',
      'terms' => 'Host membuka syarat dan ketentuan.',
      _ => 'Host membuka detail produk ${target.split(':').last}.',
    };
    if (target == 'login') _controller.signIn(balance: 24);
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roda Sabtu',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      theme: exampleTheme(Brightness.light),
      darkTheme: exampleTheme(Brightness.dark),
      themeMode: _themeMode,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: _reduceMotion),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Builder(
        builder: (BuildContext context) => WheelPage(
          controller: _controller,
          onBack: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (BuildContext sheet) => TestPanel(
              controller: _controller,
              themeMode: _themeMode,
              reduceMotion: _reduceMotion,
              onThemeMode: (ThemeMode mode) =>
                  setState(() => _themeMode = mode),
              onReduceMotion: (bool value) =>
                  setState(() => _reduceMotion = value),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hari yang bisa dipilih di panel uji.
enum DemoDay {
  /// Kamis: roda tutup, hitung mundur 2 hari.
  thursday('Kamis', -2),

  /// Jumat: hitung mundur jam dan menit.
  friday('Jumat', -1),

  /// Sabtu: roda buka.
  saturday('Sabtu', 0),

  /// Minggu: roda tutup lagi.
  sunday('Minggu', 1);

  const DemoDay(this.label, this.fromSaturday);

  /// Label chip.
  final String label;

  /// Selisih hari dari Sabtu terdekat.
  final int fromSaturday;
}

/// Geseran jam supaya hari WIB jatuh pada [day] di minggu yang memuat
/// Sabtu terdekat dari [now] (jam dalam sehari dipertahankan).
Duration offsetFor(DemoDay day, DateTime now) {
  final int today = wheelWibDayOf(now);
  final int target = today + daysUntilSaturday(today) + day.fromSaturday;
  return Duration(days: target - today);
}

/// Panel uji: hari, status pengguna, promo, kuota, hasil berikutnya, tema,
/// dan kurangi gerak.
class TestPanel extends StatefulWidget {
  /// Membuat panel untuk [controller].
  const TestPanel({
    super.key,
    required this.controller,
    required this.themeMode,
    required this.reduceMotion,
    required this.onThemeMode,
    required this.onReduceMotion,
  });

  /// Pengendali yang diatur.
  final LocalWheelController controller;

  /// Tema saat ini.
  final ThemeMode themeMode;

  /// Kurangi gerak menyala.
  final bool reduceMotion;

  /// Mengganti tema.
  final ValueChanged<ThemeMode> onThemeMode;

  /// Mengganti kurangi gerak.
  final ValueChanged<bool> onReduceMotion;

  @override
  State<TestPanel> createState() => _TestPanelState();
}

class _TestPanelState extends State<TestPanel> {
  late ThemeMode _themeMode = widget.themeMode;
  late bool _reduceMotion = widget.reduceMotion;

  LocalWheelController get _c => widget.controller;

  DemoDay? get _day {
    final DateTime real = _c.now().subtract(_c.timeOffset);
    for (final DemoDay day in DemoDay.values) {
      if (offsetFor(day, real) == _c.timeOffset) return day;
    }
    return null;
  }

  void _update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WheelViewState state = _c.state;
    final DateTime real = _c.now().subtract(_c.timeOffset);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Panel uji', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Data demo di memori. Hari WIB ${weekdayName(state.today)}, '
              '${shortDateLabel(state.today)}.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text('Hari', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final DemoDay day in DemoDay.values)
                  ChoiceChip(
                    label: Text(day.label),
                    selected: _day == day,
                    onSelected: (_) => _update(
                      () => _c.setTimeOffset(offsetFor(day, real)),
                    ),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sudah masuk'),
              value: state.signedIn,
              onChanged: (bool on) => _update(
                () => on ? _c.signIn(balance: 24) : _c.signOut(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Promo aktif'),
              value: state.promoActive,
              onChanged: (bool on) => _update(() => _c.setPromoActive(on)),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Kuota produk: ${state.productQuotaLeft}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Kurangi kuota',
                  onPressed: () => _update(
                    () => _c.setProductQuota(state.productQuotaLeft - 1),
                  ),
                  icon: const Icon(Icons.remove_rounded),
                ),
                IconButton(
                  tooltip: 'Tambah kuota',
                  onPressed: () => _update(
                    () => _c.setProductQuota(state.productQuotaLeft + 1),
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Hasil putaran berikutnya', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Acak'),
                  selected: _c.forcedPrizeId == null,
                  onSelected: (_) => _update(() => _c.forceNextPrize(null)),
                ),
                for (final SpinPrize prize in state.config.prizes)
                  ChoiceChip(
                    label: Text(prize.label),
                    selected: _c.forcedPrizeId == prize.id,
                    onSelected: (_) =>
                        _update(() => _c.forceNextPrize(prize.id)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: state.lastSpinDay == null
                  ? null
                  : () => _update(_c.resetSpin),
              child: const Text('Hapus putaran minggu ini'),
            ),
            const SizedBox(height: 16),
            Text('Tema', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Text('Terang'),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Text('Gelap'),
                ),
              ],
              selected: <ThemeMode>{_themeMode},
              onSelectionChanged: (Set<ThemeMode> value) {
                _update(() => _themeMode = value.first);
                widget.onThemeMode(value.first);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kurangi gerak'),
              value: _reduceMotion,
              onChanged: (bool on) {
                _update(() => _reduceMotion = on);
                widget.onReduceMotion(on);
              },
            ),
          ],
        ),
      ),
    );
  }
}
