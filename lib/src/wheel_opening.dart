import 'package:flutter/foundation.dart';

import 'format.dart';
import 'schedule.dart';

const int _wibOffsetMillis = 7 * Duration.millisecondsPerHour;

int _wibMillisOf(DateTime instant) =>
    instant.millisecondsSinceEpoch + _wibOffsetMillis;

int _wibDayOf(DateTime instant) {
  final int shifted = _wibMillisOf(instant);
  return (shifted - shifted % Duration.millisecondsPerDay) ~/
      Duration.millisecondsPerDay;
}

/// Pembukaan Roda Sabtu pada 00.00 WIB hari [day], dilihat dari sekarang.
///
/// Semua layar yang menyebut kapan roda buka memakai [opensAtLabel] dan
/// [remainingLabel] supaya kalimatnya selalu sama: hari kalender utuh sampai
/// sehari sebelumnya ("3 hari lagi"), lalu sisa waktu nyata
/// ("22 jam 40 menit lagi").
@immutable
final class WheelOpening {
  const WheelOpening({
    required this.day,
    required this.daysLeft,
    required this.timeLeft,
  });

  /// Hari WIB (Sabtu) saat roda buka.
  final int day;

  /// Hari kalender dari hari ini sampai [day] (1 pada hari sebelumnya).
  final int daysLeft;

  /// Sisa waktu nyata sampai 00.00 WIB hari [day].
  final Duration timeLeft;

  /// "Sabtu, 28 Nov".
  String get dayLabel => '${weekdayName(day)}, ${shortDateLabel(day)}';

  /// "Sabtu, 28 Nov · 00.00 WIB".
  String get opensAtLabel => '$dayLabel · 00.00 WIB';

  /// "3 hari lagi" selama [daysLeft] lebih dari 1, lalu sisa waktu nyata:
  /// "22 jam 40 menit lagi", "30 menit lagi", "kurang dari 1 menit lagi".
  String get remainingLabel =>
      daysLeft > 1 ? '$daysLeft hari lagi' : '${countdownLabel(timeLeft)} lagi';

  /// Apakah [remainingLabel] menghitung jam dan menit, sehingga berubah tiap
  /// menit dan bukan sekali sehari.
  bool get countsClockTime => daysLeft <= 1;

  @override
  bool operator ==(Object other) =>
      other is WheelOpening &&
      other.day == day &&
      other.daysLeft == daysLeft &&
      other.timeLeft == timeLeft;

  @override
  int get hashCode => Object.hash(day, daysLeft, timeLeft);

  @override
  String toString() => 'WheelOpening($day, $daysLeft hari, $timeLeft)';
}

/// Sabtu pertama setelah [today] yang putarannya masih bisa dipakai:
/// biasanya Sabtu berikutnya (sepekan lagi bila hari ini Sabtu); lebih jauh
/// bila putaran terakhir bertanggal hari ini atau sesudahnya (sudah memutar
/// hari ini, atau jam perangkat dimundurkan setelah memutar).
int nextSpinSaturday({required int today, required int? lastSpinDay}) {
  final int from = lastSpinDay != null && lastSpinDay >= today
      ? lastSpinDay
      : today;
  final int days = daysUntilSaturday(from);
  return from + (days == 0 ? DateTime.daysPerWeek : days);
}

/// Pembukaan roda pada hari WIB [saturday], dilihat dari waktu [now].
///
/// [now] adalah waktu yang dipakai aplikasi (termasuk geseran hari Mode
/// Demo bila ada); zona waktunya tidak berpengaruh. Bila [saturday] sudah
/// tiba atau lewat, [WheelOpening.timeLeft] nol.
WheelOpening wheelOpening({required int saturday, required DateTime now}) {
  final int daysLeft = saturday - _wibDayOf(now);
  return WheelOpening(
    day: saturday,
    daysLeft: daysLeft,
    timeLeft: daysLeft <= 0
        ? Duration.zero
        : Duration(
            milliseconds:
                saturday * Duration.millisecondsPerDay - _wibMillisOf(now),
          ),
  );
}

/// Pembukaan roda berikutnya: [wheelOpening] pada [nextSpinSaturday].
WheelOpening nextWheelOpening({
  required DateTime now,
  required int? lastSpinDay,
}) => wheelOpening(
  saturday: nextSpinSaturday(today: _wibDayOf(now), lastSpinDay: lastSpinDay),
  now: now,
);
