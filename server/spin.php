<?php
declare(strict_types=1);

/*
 * Roda Sabtu - logika server demo, setara dengan package:roda_sabtu (Dart).
 *
 * Hari WIB  : wibDay = intdiv(unixSeconds + 7 * 3600, 86400)
 * Hari ke-  : ((wibDay + 3) % 7) + 1, 1 = Senin .. 7 = Minggu (hari 0 = Kamis)
 * Sabtu     : weekday == 6
 * Peluang   : basis poin, total selalu 10000. Stok produk 0 -> produk 0,
 *             sisanya dibagi proporsional ke hadiah Kelopak (largest remainder,
 *             seri ke hadiah yang lebih awal).
 * Undian    : roll 0..9999 dari random_int; demo: produk bila stok > 0 dan
 *             roll < 1000, selain itu 3 Kelopak.
 */

const RODA_TOTAL_WEIGHT = 10000;
const RODA_SATURDAY = 6;

/**
 * @return array{version: string, prizes: list<array{id: string, kind: string, label: string, kelopak: int, weight: int}>, shippingNote: string}
 */
function rodaDemoConfig(): array
{
    return [
        'version' => 'demo-2026-11',
        'prizes' => [
            ['id' => 'product', 'kind' => 'product', 'label' => 'Produk gratis', 'kelopak' => 0, 'weight' => 1000],
            ['id' => 'kelopak-3', 'kind' => 'kelopak', 'label' => '3 Kelopak', 'kelopak' => 3, 'weight' => 9000],
        ],
        'shippingNote' => 'Gratis ongkir (Demo)',
    ];
}

function rodaWibDayOf(int $unixSeconds): int
{
    return intdiv($unixSeconds + 7 * 3600, 86400);
}

function rodaWeekday(int $wibDay): int
{
    return ((($wibDay + 3) % 7) + 7) % 7 + 1;
}

function rodaIsSaturdayWib(int $wibDay): bool
{
    return rodaWeekday($wibDay) === RODA_SATURDAY;
}

function rodaDaysUntilSaturday(int $wibDay): int
{
    return (RODA_SATURDAY - rodaWeekday($wibDay) + 7) % 7;
}

/**
 * Sama urutannya dengan spinEligibility() di Dart.
 *
 * @return 'available'|'alreadySpun'|'notSaturday'|'promoInactive'
 */
function rodaSpinEligibility(int $today, ?int $lastSpinDay, bool $promoActive): string
{
    if (!$promoActive) {
        return 'promoInactive';
    }
    if (!rodaIsSaturdayWib($today)) {
        return 'notSaturday';
    }
    if ($lastSpinDay !== null && $lastSpinDay >= $today) {
        return 'alreadySpun';
    }
    return 'available';
}

/**
 * Bobot efektif per hadiah (urutan konfigurasi), selalu berjumlah 10000.
 *
 * @return list<int>
 */
function rodaEffectiveWeights(array $config, int $productStock): array
{
    $base = [];
    $ids = [];
    foreach ($config['prizes'] as $prize) {
        $weight = (int) $prize['weight'];
        if ($weight < 0) {
            throw new InvalidArgumentException('Bobot hadiah tidak boleh negatif.');
        }
        if (isset($ids[$prize['id']])) {
            throw new InvalidArgumentException('ID hadiah harus unik.');
        }
        $ids[$prize['id']] = true;
        $base[] = ($prize['kind'] === 'product' && $productStock <= 0) ? 0 : $weight;
    }
    $sum = array_sum($base);
    if ($sum <= 0) {
        throw new InvalidArgumentException('Konfigurasi roda butuh minimal satu hadiah Kelopak berbobot.');
    }
    $weights = [];
    $remainders = [];
    $assigned = 0;
    foreach ($base as $i => $weight) {
        $scaled = RODA_TOTAL_WEIGHT * $weight;
        $weights[$i] = intdiv($scaled, $sum);
        $remainders[$i] = $scaled % $sum;
        $assigned += $weights[$i];
    }
    $order = array_keys($base);
    usort($order, static fn (int $a, int $b): int => [$remainders[$b], $a] <=> [$remainders[$a], $b]);
    $left = RODA_TOTAL_WEIGHT - $assigned;
    foreach ($order as $index) {
        if ($left === 0) {
            break;
        }
        $weights[$index]++;
        $left--;
    }
    return $weights;
}

/**
 * Hadiah untuk roll 0..9999 berdasarkan bobot efektif kumulatif.
 *
 * @return array{id: string, kind: string, label: string, kelopak: int, weight: int}
 */
function rodaResolveSpin(array $config, int $productStock, int $roll): array
{
    if ($roll < 0 || $roll >= RODA_TOTAL_WEIGHT) {
        throw new RangeException('roll harus di antara 0 dan ' . (RODA_TOTAL_WEIGHT - 1) . '.');
    }
    $upper = 0;
    foreach (rodaEffectiveWeights($config, $productStock) as $i => $weight) {
        $upper += $weight;
        if ($roll < $upper) {
            return $config['prizes'][$i];
        }
    }
    throw new LogicException('Bobot efektif tidak mencakup roll ' . $roll . '.');
}

/**
 * Satu putaran gratis untuk akun demo pada $day (hari WIB). Mengubah $state
 * secara atomik dalam transaksi pemanggil: stok/produk atau saldo Kelopak,
 * lalu spinDay, spinPrizeId, dan spinResult.
 *
 * $roll wajib 0..9999, misalnya random_int(0, RODA_TOTAL_WEIGHT - 1).
 *
 * @return array{id: string, kind: string, label: string, kelopak: int, weight: int}
 */
function claimSaturdaySpin(array &$state, int $day, int $roll, ?array $config = null): array
{
    $config ??= rodaDemoConfig();
    $lastSpinDay = isset($state['spinDay']) ? (int) $state['spinDay'] : null;
    $promoActive = (bool) ($state['promoActive'] ?? true);
    $eligibility = rodaSpinEligibility($day, $lastSpinDay, $promoActive);
    if ($eligibility !== 'available') {
        throw new DomainException(match ($eligibility) {
            'promoInactive' => 'Promo Roda Sabtu sedang tidak aktif.',
            'notSaturday' => 'Roda Sabtu buka setiap Sabtu, 00.00-23.59 WIB.',
            default => 'Putaran gratis Sabtu ini sudah dipakai.',
        });
    }
    $stock = (int) ($state['stock'] ?? 0);
    $prize = rodaResolveSpin($config, $stock, $roll);
    if ($prize['kind'] === 'product') {
        $state['stock'] = $stock - 1;
        $state['products'] = (int) ($state['products'] ?? 0) + 1;
    } else {
        $state['balance'] = (int) ($state['balance'] ?? 0) + (int) $prize['kelopak'];
    }
    $state['spinDay'] = $day;
    $state['spinPrizeId'] = $prize['id'];
    $state['spinResult'] = $prize['label'];
    return $prize;
}
