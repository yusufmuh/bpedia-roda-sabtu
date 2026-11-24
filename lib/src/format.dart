/// Rupiah value of one Kelopak (SPEC-CONTRACT section 1).
const int rupiahPerKelopak = 100;

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
