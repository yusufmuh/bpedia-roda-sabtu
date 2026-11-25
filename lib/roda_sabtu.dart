/// Roda Sabtu untuk Bpedia Demo v3: satu putaran gratis tiap Sabtu WIB,
/// peluang, kuota produk, dan ketentuan pengiriman tampil sebelum memutar.
///
/// Pola: aturan murni, lalu [WheelViewState] tak-berubah, lalu
/// [WheelController] abstrak, lalu [WheelPage]. Host mengisi satu
/// pengendali; [LocalWheelController] tersedia untuk contoh dan tes.
library;

export 'src/format.dart'
    show
        countdownLabel,
        formatPercent,
        formatRupiah,
        groupThousands,
        rupiahPerKelopak,
        shortDateLabel,
        weekdayName;
export 'src/kit/game_cue.dart' show GameCue, GameCueSink;
export 'src/local_wheel_controller.dart';
export 'src/odds_table.dart';
export 'src/pages/wheel_page.dart';
export 'src/prize_wheel.dart';
export 'src/schedule.dart'
    show SpinEligibility, daysUntilSaturday, isSaturdayWib, spinEligibility;
export 'src/spin_engine.dart'
    show
        PrizeKind,
        SpinConfig,
        SpinOdds,
        SpinPrize,
        SpinRules,
        WheelSliceSpec,
        demoSpinConfig,
        effectiveOdds,
        resolveSpin;
export 'src/wheel_assets.dart';
export 'src/wheel_geometry.dart' show WheelGeometry;
export 'src/wheel_opening.dart'
    show WheelOpening, nextSpinSaturday, nextWheelOpening, wheelOpening;
export 'src/wheel_slices.dart'
    show WheelSlice, buildWheelSlices, buildWheelSlicesFromOdds;
export 'src/wheel_spin_curve.dart';
export 'src/wheel_view.dart';
export 'src/widgets/lively_pose.dart';
export 'src/widgets/wheel_countdown.dart';
export 'src/widgets/wheel_history.dart';
export 'src/widgets/wheel_how_it_works.dart';
export 'src/widgets/wheel_prize_card.dart';
