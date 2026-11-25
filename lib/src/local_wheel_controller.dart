import 'dart:math' as math;

import 'kit/game_cue.dart';
import 'spin_engine.dart';
import 'wheel_view.dart';

/// Pengendali dalam memori di atas aturan murni, untuk `example/`, tes, dan
/// pratinjau. Tidak menyimpan apa pun ke perangkat.
///
/// Undian memakai `Random.secure()` (atau [random] bila diberikan). Aksi
/// navigasi dicatat di [opened] dan diteruskan ke [onOpen] bila ada.
class LocalWheelController extends WheelController {
  /// Membuat pengendali lokal.
  LocalWheelController({
    SpinConfig config = demoSpinConfig,
    DateTime Function() clock = DateTime.now,
    bool signedIn = true,
    bool promoActive = true,
    int balance = 0,
    int productQuotaLeft = 3,
    int? lastSpinDay,
    List<WheelSpinRecord> history = const <WheelSpinRecord>[],
    WheelPrizeProduct? product,
    bool reminderSupported = true,
    bool reminderOn = false,
    bool? soundOn,
    this.latency = Duration.zero,
    math.Random? random,
    this.onOpen,
  }) : _clock = clock,
       _random = random ?? math.Random.secure(),
       _state = WheelViewState(
         signedIn: signedIn,
         today: wheelWibDayOf(clock()),
         config: config,
         productQuotaLeft: productQuotaLeft,
         promoActive: promoActive,
         lastSpinDay: signedIn ? lastSpinDay : null,
         balance: signedIn ? balance : 0,
         product: product,
         history: signedIn ? history : const <WheelSpinRecord>[],
         reminderSupported: reminderSupported,
         reminderOn: reminderOn,
         soundOn: soundOn,
       );

  final DateTime Function() _clock;
  final math.Random _random;
  Duration _offset = Duration.zero;
  String? _forcedPrizeId;
  WheelViewState _state;

  /// Jeda buatan untuk meniru jaringan.
  final Duration latency;

  /// Dipanggil tiap aksi navigasi (`login`, `shop`, `cart`, `terms`,
  /// `product:<kode>`).
  final void Function(String target)? onOpen;

  /// Aksi navigasi yang sudah diminta halaman, urut waktu.
  final List<String> opened = <String>[];

  /// Suara yang diminta halaman, urut waktu.
  final List<GameCue> cues = <GameCue>[];

  @override
  WheelViewState get state => _state;

  @override
  DateTime now() => _clock().add(_offset);

  /// Geseran jam (panel uji "ganti hari").
  Duration get timeOffset => _offset;

  /// Hadiah yang dipaksa keluar pada putaran berikutnya, bila ada.
  String? get forcedPrizeId => _forcedPrizeId;

  void _emit(WheelViewState next) {
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<void> refresh() async {
    _emit(_state.copyWith(today: wheelWibDayOf(now())));
  }

  /// Menggeser jam sejauh [offset] dari jam asli lalu memuat ulang hari.
  void setTimeOffset(Duration offset) {
    _offset = offset;
    _emit(_state.copyWith(today: wheelWibDayOf(now())));
  }

  /// Masuk sebagai pengguna demo dengan saldo [balance].
  void signIn({int balance = 0}) {
    _emit(_state.copyWith(signedIn: true, balance: balance));
  }

  /// Keluar: kembali menjadi tamu (riwayat dan saldo dikosongkan).
  void signOut() {
    _emit(
      _state.copyWith(
        signedIn: false,
        balance: 0,
        clearLastSpin: true,
        history: const <WheelSpinRecord>[],
        reminderOn: false,
      ),
    );
  }

  /// Menyalakan atau mematikan promo roda.
  void setPromoActive(bool value) => _emit(_state.copyWith(promoActive: value));

  /// Mengatur sisa kuota produk minggu ini.
  void setProductQuota(int value) =>
      _emit(_state.copyWith(productQuotaLeft: math.max(0, value)));

  /// Menghapus putaran minggu ini supaya bisa memutar lagi.
  void resetSpin() => _emit(_state.copyWith(clearLastSpin: true));

  /// Memaksa hadiah [prizeId] keluar pada putaran berikutnya (`null` =
  /// undian biasa). Hadiah berpeluang 0 saat itu tidak bisa dipaksa.
  void forceNextPrize(String? prizeId) => _forcedPrizeId = prizeId;

  int _roll() {
    final String? forced = _forcedPrizeId;
    if (forced != null) {
      int lower = 0;
      for (final SpinOdds entry in _state.odds) {
        if (entry.prize.id == forced && entry.weight > 0) {
          return lower + _random.nextInt(entry.weight);
        }
        lower += entry.weight;
      }
    }
    return _random.nextInt(SpinRules.totalWeight);
  }

  @override
  Future<WheelSpinResult?> spin() async {
    if (!_state.canSpin) return null;
    _emit(_state.copyWith(busy: true));
    await _wait();
    final WheelViewState current = _state;
    final SpinPrize prize = resolveSpin(
      current.config,
      productStock: current.productQuotaLeft,
      roll: _roll(),
    );
    _forcedPrizeId = null;
    final bool product = prize.kind == PrizeKind.product;
    final WheelPrizeProduct? won = product ? current.product : null;
    final int balance = current.balance + prize.kelopak;
    _emit(
      current.copyWith(
        busy: false,
        lastSpinDay: current.today,
        balance: balance,
        productQuotaLeft: product
            ? math.max(0, current.productQuotaLeft - 1)
            : current.productQuotaLeft,
        history: <WheelSpinRecord>[
          WheelSpinRecord.fromPrize(
            prize,
            day: current.today,
            productName: won?.name,
          ),
          ...current.history,
        ],
      ),
    );
    return WheelSpinResult(
      prize: prize,
      landingSeed: _random.nextInt(1 << 20),
      balance: balance,
      product: won,
    );
  }

  void _open(String target) {
    opened.add(target);
    onOpen?.call(target);
  }

  @override
  void openLogin() => _open('login');

  @override
  void openShop() => _open('shop');

  @override
  void openCart() => _open('cart');

  @override
  void openProduct(String code) => _open('product:$code');

  @override
  void openTerms() => _open('terms');

  @override
  Future<void> setReminder(bool on) async {
    if (!_state.reminderSupported) return;
    _emit(_state.copyWith(reminderOn: on));
  }

  @override
  void playCue(GameCue cue) => cues.add(cue);

  @override
  void setSoundOn(bool value) => _emit(_state.copyWith(soundOn: value));
}
