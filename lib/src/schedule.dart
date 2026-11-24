/// Weekday of a WIB day number, 1 = Monday .. 7 = Sunday (day 0 is Thursday
/// 1 January 1970).
int _wibWeekday(int wibDay) => ((wibDay + 3) % 7) + 1;

/// Whether [wibDay] (see SPEC-CONTRACT: `(utcMillis + 7h) ~/ 1 day`) is a
/// Saturday in Western Indonesian Time.
bool isSaturdayWib(int wibDay) => _wibWeekday(wibDay) == DateTime.saturday;

/// Days from [wibDay] to the next Saturday; 0 when [wibDay] is a Saturday.
int daysUntilSaturday(int wibDay) =>
    (DateTime.saturday - _wibWeekday(wibDay)) % 7;

/// Why the free spin can or cannot be used right now.
enum SpinEligibility { available, alreadySpun, notSaturday, promoInactive }

/// One free spin per account per Saturday (WIB) while the promo is active.
///
/// A recorded spin on [today] or later (clock moved back) counts as used.
SpinEligibility spinEligibility({
  required int today,
  required int? lastSpinDay,
  required bool promoActive,
}) {
  if (!promoActive) return SpinEligibility.promoInactive;
  if (!isSaturdayWib(today)) return SpinEligibility.notSaturday;
  if (lastSpinDay != null && lastSpinDay >= today) {
    return SpinEligibility.alreadySpun;
  }
  return SpinEligibility.available;
}
