/// Rupiah value of one Kelopak (SPEC-CONTRACT section 1).
const int rupiahPerKelopak = 100;

const List<String> _weekdayNames = <String>[
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const List<String> _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// Groups digits with dots, Indonesian style: `1250000` -> `1.250.000`.
String groupThousands(int value) {
  final String digits = value.abs().toString();
  final StringBuffer out = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Same output as the shared hub formatter: `Rp10.000`, `-Rp25.000`.
String formatRupiah(int amount) => amount < 0
    ? '-Rp${groupThousands(-amount)}'
    : 'Rp${groupThousands(amount)}';

/// Basis points (1/100 percent) as an Indonesian percentage:
/// `1000` -> `10%`, `1250` -> `12,5%`, `1` -> `0,01%`.
String formatPercent(int basisPoints) {
  assert(basisPoints >= 0, 'basisPoints must not be negative');
  final int whole = basisPoints ~/ 100;
  final int fraction = basisPoints % 100;
  if (fraction == 0) return '${groupThousands(whole)}%';
  final String decimals = fraction % 10 == 0
      ? '${fraction ~/ 10}'
      : fraction.toString().padLeft(2, '0');
  return '${groupThousands(whole)},$decimals%';
}

/// Nama hari dari hari WIB (hari sejak 1 Jan 1970, UTC+7): "Sabtu".
String weekdayName(int wibDay) => _weekdayNames[(wibDay + 3) % 7];

/// Tanggal pendek dari hari WIB: "28 Nov".
String shortDateLabel(int wibDay) {
  final DateTime date = DateTime.utc(1970).add(Duration(days: wibDay));
  return '${date.day} ${_monthNames[date.month - 1]}';
}

/// Hari lengkap dari hari WIB: "Sabtu, 28 Nov 2026".
String spinDayLabel(int wibDay) {
  final DateTime date = DateTime.utc(1970).add(Duration(days: wibDay));
  return '${weekdayName(wibDay)}, ${shortDateLabel(wibDay)} ${date.year}';
}

/// Sisa waktu: "2 hari 3 jam", "5 jam 12 menit", "45 menit", atau
/// "kurang dari 1 menit".
String countdownLabel(Duration remaining) {
  if (remaining < const Duration(minutes: 1)) return 'kurang dari 1 menit';
  final int days = remaining.inDays;
  final int hours = remaining.inHours % Duration.hoursPerDay;
  final int minutes = remaining.inMinutes % Duration.minutesPerHour;
  if (days > 0) return hours > 0 ? '$days hari $hours jam' : '$days hari';
  if (hours > 0) {
    return minutes > 0 ? '$hours jam $minutes menit' : '$hours jam';
  }
  return '$minutes menit';
}
