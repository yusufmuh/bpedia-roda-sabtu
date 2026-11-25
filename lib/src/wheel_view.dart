import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'format.dart';
import 'kit/game_cue.dart';
import 'schedule.dart';
import 'spin_engine.dart';
import 'wheel_opening.dart';
import 'wheel_slices.dart';

const int _wibOffsetMillis = 7 * Duration.millisecondsPerHour;

/// Hari WIB dari [instant]: `(utcMillis + 7 jam) ~/ 1 hari`, hari 0 = Kamis
/// 1 Januari 1970 (sama dengan aturan `schedule.dart`).
int wheelWibDayOf(DateTime instant) =>
    (instant.millisecondsSinceEpoch + _wibOffsetMillis) ~/
    Duration.millisecondsPerDay;

/// Produk hadiah roda minggu ini sebagai data tampilan.
///
/// Modul tidak mengenal katalog: host mengisi nama, gambar, dan harga.
@immutable
final class WheelPrizeProduct {
  /// Membuat data tampilan produk hadiah.
  const WheelPrizeProduct({
    required this.code,
    required this.name,
    required this.image,
    required this.price,
    this.strikePrice,
  });

  /// Kode produk di katalog host.
  final String code;

  /// Nama produk.
  final String name;

  /// Foto produk.
  final ImageProvider image;

  /// Harga jual (rupiah). Di halaman tampil dicoret karena hadiahnya gratis.
  final int price;

  /// Harga sebelum diskon (rupiah), bila ada.
  final int? strikePrice;

  @override
  bool operator ==(Object other) =>
      other is WheelPrizeProduct &&
      other.code == code &&
      other.name == name &&
      other.image == image &&
      other.price == price &&
      other.strikePrice == strikePrice;

  @override
  int get hashCode => Object.hash(code, name, image, price, strikePrice);
}

/// Satu putaran di riwayat pengguna.
@immutable
final class WheelSpinRecord {
  /// Membuat catatan putaran.
  const WheelSpinRecord({
    required this.day,
    required this.prizeId,
    required this.label,
    required this.kind,
    this.kelopak = 0,
    this.productName,
  });

  /// Catatan dari hadiah [prize] pada hari WIB [day].
  factory WheelSpinRecord.fromPrize(
    SpinPrize prize, {
    required int day,
    String? productName,
  }) => WheelSpinRecord(
    day: day,
    prizeId: prize.id,
    label: prize.label,
    kind: prize.kind,
    kelopak: prize.kelopak,
    productName: productName,
  );

  /// Hari WIB putaran.
  final int day;

  /// Hadiah yang keluar.
  final String prizeId;

  /// Label hadiah saat itu ("5 Kelopak", "Produk gratis").
  final String label;

  /// Jenis hadiah.
  final PrizeKind kind;

  /// Kelopak yang didapat (0 untuk produk).
  final int kelopak;

  /// Nama produk yang dimenangkan, bila hadiah produk.
  final String? productName;

  /// "Sabtu, 21 Nov".
  String get dayLabel => '${weekdayName(day)}, ${shortDateLabel(day)}';

  /// Judul baris riwayat: nama produk atau label hadiah.
  String get title => productName ?? label;

  @override
  bool operator ==(Object other) =>
      other is WheelSpinRecord &&
      other.day == day &&
      other.prizeId == prizeId &&
      other.label == label &&
      other.kind == kind &&
      other.kelopak == kelopak &&
      other.productName == productName;

  @override
  int get hashCode =>
      Object.hash(day, prizeId, label, kind, kelopak, productName);
}

/// Keadaan halaman Roda Sabtu pada satu saat. Tak-berubah.
///
/// Kelayakan, peluang efektif, irisan roda, dan Sabtu berikutnya diturunkan
/// dengan aturan murni dari nilai yang diisi host.
@immutable
final class WheelViewState {
  /// Membuat keadaan dari nilai yang sudah dihitung host.
  const WheelViewState({
    required this.signedIn,
    required this.today,
    required this.config,
    required this.productQuotaLeft,
    this.promoActive = true,
    this.lastSpinDay,
    this.balance = 0,
    this.product,
    this.history = const <WheelSpinRecord>[],
    this.reminderSupported = false,
    this.reminderOn = false,
    this.soundOn,
    this.busy = false,
  }) : assert(productQuotaLeft >= 0, 'Kuota tidak boleh negatif.');

  /// Keadaan tamu: roda, peluang, dan hadiah tetap tampil; aksi utama
  /// menjadi "Masuk untuk memutar".
  const WheelViewState.guest({
    required this.today,
    required this.config,
    required this.productQuotaLeft,
    this.promoActive = true,
    this.product,
    this.reminderSupported = false,
    this.soundOn,
  }) : signedIn = false,
       lastSpinDay = null,
       balance = 0,
       history = const <WheelSpinRecord>[],
       reminderOn = false,
       busy = false;

  /// Pengguna sudah masuk.
  final bool signedIn;

  /// Hari WIB saat ini (`wheelWibDayOf`).
  final int today;

  /// Kampanye roda (hadiah, peluang dasar, cadangan, tata letak).
  final SpinConfig config;

  /// Sisa kuota produk gratis minggu ini.
  final int productQuotaLeft;

  /// Promo roda sedang berjalan.
  final bool promoActive;

  /// Hari WIB putaran terakhir pengguna, bila ada.
  final int? lastSpinDay;

  /// Saldo Kelopak.
  final int balance;

  /// Produk hadiah minggu ini. `null` = kartu hadiah umum.
  final WheelPrizeProduct? product;

  /// Riwayat putaran, terbaru dulu.
  final List<WheelSpinRecord> history;

  /// Host bisa memasang pengingat (Android/iOS). Web: `false`.
  final bool reminderSupported;

  /// Pengingat Sabtu 09.00 WIB menyala.
  final bool reminderOn;

  /// Status suara host. `null` menyembunyikan tombol suara.
  final bool? soundOn;

  /// Sedang memuat atau mengirim putaran.
  final bool busy;

  /// Kelayakan putaran gratis hari ini menurut aturan murni.
  SpinEligibility get eligibility => spinEligibility(
    today: today,
    lastSpinDay: lastSpinDay,
    promoActive: promoActive,
  );

  /// Bisa memutar sekarang.
  bool get canSpin =>
      signedIn && !busy && eligibility == SpinEligibility.available;

  /// Peluang efektif dengan sisa kuota saat ini.
  List<SpinOdds> get odds =>
      effectiveOdds(config, productStock: productQuotaLeft);

  /// Irisan roda dengan sisa kuota saat ini.
  List<WheelSlice> get slices =>
      buildWheelSlices(config, productQuotaLeft: productQuotaLeft);

  /// Sabtu WIB berikutnya yang putarannya masih bisa dipakai.
  int get nextSaturday =>
      nextSpinSaturday(today: today, lastSpinDay: lastSpinDay);

  /// Pembukaan roda berikutnya dilihat dari [now].
  WheelOpening openingAt(DateTime now) =>
      wheelOpening(saturday: nextSaturday, now: now);

  /// Putaran Sabtu ini, bila sudah dipakai.
  WheelSpinRecord? get thisWeekSpin {
    final int? last = lastSpinDay;
    if (last == null || last < today) return null;
    for (final WheelSpinRecord record in history) {
      if (record.day == last) return record;
    }
    return null;
  }

  /// Hadiah dengan [id] di kampanye.
  SpinPrize? prizeById(String id) => config.prizeById(id);

  /// Salinan dengan sebagian nilai diganti. [lastSpinDay] dan [product]
  /// bisa dikosongkan lewat [clearLastSpin] dan [clearProduct].
  WheelViewState copyWith({
    bool? signedIn,
    int? today,
    SpinConfig? config,
    int? productQuotaLeft,
    bool? promoActive,
    int? lastSpinDay,
    bool clearLastSpin = false,
    int? balance,
    WheelPrizeProduct? product,
    bool clearProduct = false,
    List<WheelSpinRecord>? history,
    bool? reminderSupported,
    bool? reminderOn,
    bool? soundOn,
    bool? busy,
  }) {
    return WheelViewState(
      signedIn: signedIn ?? this.signedIn,
      today: today ?? this.today,
      config: config ?? this.config,
      productQuotaLeft: productQuotaLeft ?? this.productQuotaLeft,
      promoActive: promoActive ?? this.promoActive,
      lastSpinDay: clearLastSpin ? null : lastSpinDay ?? this.lastSpinDay,
      balance: balance ?? this.balance,
      product: clearProduct ? null : product ?? this.product,
      history: history ?? this.history,
      reminderSupported: reminderSupported ?? this.reminderSupported,
      reminderOn: reminderOn ?? this.reminderOn,
      soundOn: soundOn ?? this.soundOn,
      busy: busy ?? this.busy,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WheelViewState &&
      other.signedIn == signedIn &&
      other.today == today &&
      other.config == config &&
      other.productQuotaLeft == productQuotaLeft &&
      other.promoActive == promoActive &&
      other.lastSpinDay == lastSpinDay &&
      other.balance == balance &&
      other.product == product &&
      listEquals(other.history, history) &&
      other.reminderSupported == reminderSupported &&
      other.reminderOn == reminderOn &&
      other.soundOn == soundOn &&
      other.busy == busy;

  @override
  int get hashCode => Object.hash(
    signedIn,
    today,
    config,
    productQuotaLeft,
    promoActive,
    lastSpinDay,
    balance,
    product,
    Object.hashAll(history),
    reminderSupported,
    reminderOn,
    soundOn,
    busy,
  );

  @override
  String toString() =>
      'WheelViewState(signedIn: $signedIn, today: $today, '
      'quota: $productQuotaLeft, lastSpinDay: $lastSpinDay, busy: $busy)';
}

/// Hasil satu putaran yang sudah ditetapkan sebelum animasi.
@immutable
final class WheelSpinResult {
  /// Membuat hasil putaran.
  const WheelSpinResult({
    required this.prize,
    required this.landingSeed,
    required this.balance,
    this.product,
  });

  /// Hadiah yang keluar (dari undian 0..9999 milik host atau server).
  final SpinPrize prize;

  /// Benih titik berhenti di dalam irisan hadiah (tampilan saja).
  final int landingSeed;

  /// Saldo Kelopak setelah putaran.
  final int balance;

  /// Produk yang dimenangkan bila [prize] berupa produk dan host tahu
  /// produknya.
  final WheelPrizeProduct? product;
}

/// Jembatan halaman ke sumber data. Halaman hanya membaca [state] dan
/// memanggil aksi; host menentukan data datang dari mana (lokal atau
/// server).
///
/// Panggil `notifyListeners` tiap kali [state] berubah.
abstract class WheelController extends ChangeNotifier {
  /// Keadaan terkini.
  WheelViewState get state;

  /// Jam yang dipakai hitung mundur ke Sabtu 00.00 WIB.
  DateTime now() => DateTime.now();

  /// Memuat ulang keadaan (mis. saat hari WIB berganti).
  Future<void> refresh();

  /// Memutar roda. Mengembalikan `null` bila putaran tidak tersedia
  /// (bukan Sabtu, sudah memutar, promo mati, atau tamu); melempar bila
  /// putaran gagal dikirim. Hasil sudah final sebelum roda berputar.
  Future<WheelSpinResult?> spin();

  /// Membuka halaman Masuk.
  void openLogin();

  /// Membuka katalog belanja.
  void openShop();

  /// Membuka keranjang (hadiah produk menunggu di sana).
  void openCart();

  /// Membuka detail produk [code].
  void openProduct(String code);

  /// Membuka syarat dan ketentuan lengkap.
  void openTerms();

  /// Menyalakan atau mematikan pengingat Sabtu 09.00 WIB. Hanya dipanggil
  /// bila `state.reminderSupported`.
  Future<void> setReminder(bool on) async {}

  /// Memutar suara [cue]. Getar sudah ditangani halaman.
  void playCue(GameCue cue) {}

  /// Menyalakan atau mematikan suara host.
  void setSoundOn(bool value) {}
}
