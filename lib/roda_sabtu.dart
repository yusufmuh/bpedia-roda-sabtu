/// Roda Sabtu: one free prize-wheel spin per Saturday (WIB) for Bpedia
/// Preview, with odds, product quota and shipping shown before spinning.
library;

export 'src/format.dart' show countdownLabel, shortDateLabel, weekdayName;
export 'src/odds_table.dart' show OddsTable;
export 'src/saturday_wheel.dart' show SaturdayWheel;
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
export 'src/wheel_geometry.dart' show WheelGeometry;
export 'src/wheel_opening.dart'
    show WheelOpening, nextSpinSaturday, nextWheelOpening, wheelOpening;
export 'src/wheel_slices.dart'
    show WheelSlice, buildWheelSlices, buildWheelSlicesFromOdds;
