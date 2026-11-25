<?php
declare(strict_types=1);

/*
 * Roda Sabtu - logika server acuan (PHP 8.2+), setara dengan
 * package:roda_sabtu 3.0.0 (lib/src/schedule.dart, spin_engine.dart,
 * wheel_slices.dart, wheel_opening.dart).
 *
 * Hari WIB  : wibDay = intdiv(unixSeconds + 7 * 3600, 86400)
 * Hari ke-  : ((wibDay + 3) % 7) + 1, 1 = Senin .. 7 = Minggu (hari 0 = Kamis)
 * Sabtu     : weekday == 6
 * Peluang   : basis poin, total selalu 10000. Kuota produk 0 -> produk 0;
 *             bagiannya pindah ke fallbackPrizeId bila diatur, selain itu
 *             dibagi proporsional ke hadiah Kelopak (largest remainder, seri
 *             ke hadiah yang lebih awal).
 * Undian    : roll 0..9999 dari random_int, dipetakan ke bobot efektif
 *             kumulatif dalam urutan konfigurasi.
 * Roda      : 1 unit tata letak = 500 basis poin = 18 derajat; satu irisan
 *             paling lebar 3 unit (54 derajat). Roda hanya tampilan: hasil
 *             undian tidak pernah bergantung pada susunan irisan.
 *
 * `php server/spin.php` menjalankan swa-uji dengan tabel yang sama seperti tes
 * Dart. Di SAPI web berkas ini tidak mengeluarkan apa pun.
 */

const RODA_TOTAL_WEIGHT = 10000;
const RODA_SATURDAY = 6;
const RODA_WHEEL_UNIT_WEIGHT = 500;
const RODA_MAX_SLICE_WEIGHT = 1500;

/**
 * Kampanye contoh v3 (nilai demo): produk gratis 5% selama kuota ada,
 * 10 Kelopak 5%, 5 Kelopak 15%, 3 Kelopak 30%, 1 Kelopak 45%; kuota habis ->
 * bagian produk pindah ke 1 Kelopak.
 *
 * @return array{version: string, prizes: list<array{id: string, kind: string, label: string, kelopak: int, weight: int, productCode: ?string}>, shippingNote: string, fallbackPrizeId: ?string, wheelLayout: ?list<array{prizeId: string, units: int}>}
 */
function rodaDemoConfig(): array
{
    return [
        'version' => 'demo-v3-2026-11',
        'prizes' => [
            ['id' => 'product', 'kind' => 'product', 'label' => 'Produk gratis', 'kelopak' => 0, 'weight' => 500, 'productCode' => null],
            ['id' => 'kelopak-10', 'kind' => 'kelopak', 'label' => '10 Kelopak', 'kelopak' => 10, 'weight' => 500, 'productCode' => null],
            ['id' => 'kelopak-5', 'kind' => 'kelopak', 'label' => '5 Kelopak', 'kelopak' => 5, 'weight' => 1500, 'productCode' => null],
            ['id' => 'kelopak-3', 'kind' => 'kelopak', 'label' => '3 Kelopak', 'kelopak' => 3, 'weight' => 3000, 'productCode' => null],
            ['id' => 'kelopak-1', 'kind' => 'kelopak', 'label' => '1 Kelopak', 'kelopak' => 1, 'weight' => 4500, 'productCode' => null],
        ],
        'shippingNote' => 'Dikirim bersama pesanan belanja berikutnya, tanpa ongkir tambahan',
        'fallbackPrizeId' => 'kelopak-1',
        'wheelLayout' => [
            ['prizeId' => 'product', 'units' => 1],
            ['prizeId' => 'kelopak-1', 'units' => 3],
            ['prizeId' => 'kelopak-3', 'units' => 3],
            ['prizeId' => 'kelopak-1', 'units' => 3],
            ['prizeId' => 'kelopak-10', 'units' => 1],
            ['prizeId' => 'kelopak-5', 'units' => 3],
            ['prizeId' => 'kelopak-3', 'units' => 3],
            ['prizeId' => 'kelopak-1', 'units' => 3],
        ],
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
 * Sabtu pertama setelah $today yang putarannya masih bisa dipakai; sama
 * dengan nextSpinSaturday() di Dart.
 */
function rodaNextSpinSaturday(int $today, ?int $lastSpinDay): int
{
    $from = ($lastSpinDay !== null && $lastSpinDay >= $today) ? $lastSpinDay : $today;
    $days = rodaDaysUntilSaturday($from);
    return $from + ($days === 0 ? 7 : $days);
}

/** Menolak konfigurasi yang tidak sah; urutan setara _checkConfig di Dart. */
function rodaCheckConfig(array $config): void
{
    $prizes = $config['prizes'] ?? [];
    if ($prizes === []) {
        throw new InvalidArgumentException('Konfigurasi roda tidak punya hadiah.');
    }
    $kinds = [];
    foreach ($prizes as $prize) {
        if ((int) $prize['weight'] < 0) {
            throw new InvalidArgumentException('Bobot hadiah tidak boleh negatif.');
        }
        if (isset($kinds[$prize['id']])) {
            throw new InvalidArgumentException('ID hadiah harus unik.');
        }
        $kinds[$prize['id']] = $prize['kind'];
    }
    $fallbackId = $config['fallbackPrizeId'] ?? null;
    if ($fallbackId !== null && ($kinds[$fallbackId] ?? null) !== 'kelopak') {
        throw new InvalidArgumentException('fallbackPrizeId harus menunjuk hadiah Kelopak di kampanye.');
    }
    foreach ($config['wheelLayout'] ?? [] as $spec) {
        if (!isset($kinds[$spec['prizeId']])) {
            throw new InvalidArgumentException('wheelLayout menyebut hadiah yang tidak ada di kampanye.');
        }
        if ((int) $spec['units'] < 1) {
            throw new InvalidArgumentException('Irisan wheelLayout butuh minimal 1 unit.');
        }
    }
}

/**
 * Bobot efektif per hadiah (urutan konfigurasi), selalu berjumlah 10000.
 *
 * @return list<int>
 */
function rodaEffectiveWeights(array $config, int $productStock): array
{
    rodaCheckConfig($config);
    $productAvailable = $productStock > 0;
    $fallbackId = $config['fallbackPrizeId'] ?? null;
    $base = [];
    $freed = 0;
    $fallbackIndex = null;
    foreach (array_values($config['prizes']) as $i => $prize) {
        $weight = (int) $prize['weight'];
        $isProduct = $prize['kind'] === 'product';
        $base[$i] = ($isProduct && !$productAvailable) ? 0 : $weight;
        if ($isProduct) {
            $freed += $weight;
        }
        if ($prize['id'] === $fallbackId) {
            $fallbackIndex = $i;
        }
    }
    if (!$productAvailable && $fallbackIndex !== null) {
        $base[$fallbackIndex] += $freed;
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
    $prizes = array_values($config['prizes']);
    $upper = 0;
    foreach (rodaEffectiveWeights($config, $productStock) as $i => $weight) {
        $upper += $weight;
        if ($roll < $upper) {
            return $prizes[$i];
        }
    }
    throw new LogicException('Bobot efektif tidak mencakup roll ' . $roll . '.');
}

/**
 * Irisan roda untuk $config dengan sisa kuota produk $productQuotaLeft;
 * cermin buildWheelSlices() di Dart. Luas tiap hadiah = peluang efektifnya,
 * hadiah berpeluang 0 tidak digambar. `weight` adalah lebar irisan dalam
 * basis poin; startDeg dan sweepDeg turunannya (derajat, searah jarum jam
 * dari arah jam 12).
 *
 * @return list<array{prizeId: string, startDeg: float, sweepDeg: float, index: int, weight: int}>
 */
function rodaBuildWheelSlices(array $config, int $productQuotaLeft): array
{
    $weights = rodaEffectiveWeights($config, $productQuotaLeft);
    $odds = [];
    foreach (array_values($config['prizes']) as $i => $prize) {
        $odds[] = ['id' => (string) $prize['id'], 'kind' => (string) $prize['kind'], 'weight' => $weights[$i]];
    }
    $parts = rodaExplicitParts($odds, $config['wheelLayout'] ?? null) ?? rodaAutoParts($odds);
    $slices = [];
    $cursor = 0;
    foreach ($parts as $index => [$prizeId, $weight]) {
        $slices[] = [
            'prizeId' => $prizeId,
            'startDeg' => (float) ($cursor * 360 / RODA_TOTAL_WEIGHT),
            'sweepDeg' => (float) ($weight * 360 / RODA_TOTAL_WEIGHT),
            'index' => $index,
            'weight' => $weight,
        ];
        $cursor += $weight;
    }
    return $slices;
}

/**
 * Tata letak kampanye dipakai apa adanya bila jumlah unit tiap hadiah sama
 * dengan bobot efektifnya, tiap irisan 1..3 unit, dan tidak ada dua irisan
 * bersebelahan (melingkar) yang berhadiah sama. Selain itu null.
 *
 * @param list<array{id: string, kind: string, weight: int}> $odds
 * @return ?list<array{0: string, 1: int}>
 */
function rodaExplicitParts(array $odds, ?array $layout): ?array
{
    if ($layout === null || $layout === []) {
        return null;
    }
    $layout = array_values($layout);
    $count = count($layout);
    $maxUnits = intdiv(RODA_MAX_SLICE_WEIGHT, RODA_WHEEL_UNIT_WEIGHT);
    $units = [];
    foreach ($layout as $i => $spec) {
        $specUnits = (int) $spec['units'];
        if ($specUnits < 1 || $specUnits > $maxUnits) {
            return null;
        }
        if ($count > 1 && $spec['prizeId'] === $layout[($i + 1) % $count]['prizeId']) {
            return null;
        }
        $units[$spec['prizeId']] = ($units[$spec['prizeId']] ?? 0) + $specUnits;
    }
    $matched = 0;
    foreach ($odds as $entry) {
        $laidOut = $units[$entry['id']] ?? null;
        if (($laidOut ?? 0) * RODA_WHEEL_UNIT_WEIGHT !== $entry['weight']) {
            return null;
        }
        if ($laidOut !== null) {
            $matched++;
        }
    }
    if ($matched !== count($units)) {
        return null;
    }
    return array_map(
        static fn (array $spec): array => [(string) $spec['prizeId'], (int) $spec['units'] * RODA_WHEEL_UNIT_WEIGHT],
        $layout,
    );
}

/**
 * Susunan otomatis deterministik: tiap hadiah dipecah menjadi irisan hampir
 * sama besar (maks. 54 derajat); hadiah dengan irisan terbanyak lebih dulu
 * (seri: urutan konfigurasi) mengisi posisi genap lalu ganjil; roda diputar
 * supaya irisan pertama adalah hadiah produk pertama, atau hadiah pertama
 * bila tidak ada produk.
 *
 * @param list<array{id: string, kind: string, weight: int}> $odds
 * @return list<array{0: string, 1: int}>
 */
function rodaAutoParts(array $odds): array
{
    $visible = array_values(array_filter($odds, static fn (array $entry): bool => $entry['weight'] > 0));
    $pieces = array_map(static fn (array $entry): array => rodaSplitWeight($entry['weight']), $visible);
    $ranked = array_keys($visible);
    usort($ranked, static fn (int $a, int $b): int => [count($pieces[$b]), $a] <=> [count($pieces[$a]), $b]);
    $sequence = [];
    foreach ($ranked as $index) {
        foreach ($pieces[$index] as $weight) {
            $sequence[] = [$visible[$index]['id'], $weight];
        }
    }
    $count = count($sequence);
    $ring = [];
    $next = 0;
    for ($position = 0; $position < $count; $position += 2) {
        $ring[$position] = $sequence[$next++];
    }
    for ($position = 1; $position < $count; $position += 2) {
        $ring[$position] = $sequence[$next++];
    }
    ksort($ring);
    $anchor = $visible[0]['id'];
    foreach ($visible as $entry) {
        if ($entry['kind'] === 'product') {
            $anchor = $entry['id'];
            break;
        }
    }
    $shift = 0;
    foreach ($ring as $position => [$prizeId]) {
        if ($prizeId === $anchor) {
            $shift = $position;
            break;
        }
    }
    return [...array_slice($ring, $shift), ...array_slice($ring, 0, $shift)];
}

/**
 * Memecah $weight menjadi irisan hampir sama besar (selisih paling banyak
 * 1 basis poin), tiap irisan tidak lebih dari RODA_MAX_SLICE_WEIGHT.
 *
 * @return list<int>
 */
function rodaSplitWeight(int $weight): array
{
    $count = intdiv($weight + RODA_MAX_SLICE_WEIGHT - 1, RODA_MAX_SLICE_WEIGHT);
    $base = intdiv($weight, $count);
    $extra = $weight % $count;
    $parts = [];
    for ($i = 0; $i < $count; $i++) {
        $parts[] = $base + ($i < $extra ? 1 : 0);
    }
    return $parts;
}

/**
 * Satu putaran gratis untuk akun demo pada $day (hari WIB). Mengubah $state
 * secara atomik dalam transaksi pemanggil: kuota/produk atau saldo Kelopak,
 * lalu spinDay, spinPrizeId, dan spinResult. Hadiah produk dikirim bersama
 * pesanan belanja berikutnya; pemanggil mencatatnya sebagai hadiah menunggu.
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

/** Swa-uji aturan; mengembalikan kode keluar 0 bila semua cocok. */
function rodaSelfTest(): int
{
    $failures = [];
    $checks = 0;
    $expect = static function (mixed $actual, mixed $expected, string $what) use (&$failures, &$checks): void {
        $checks++;
        if ($actual !== $expected) {
            $failures[] = $what . ': dapat ' . var_export($actual, true) . ', harus ' . var_export($expected, true);
        }
    };
    $throws = static function (callable $run, string $class): bool {
        try {
            $run();
        } catch (Throwable $error) {
            return $error instanceof $class;
        }
        return false;
    };
    $at = static fn (string $iso): int => (new DateTimeImmutable($iso))->getTimestamp();
    $ids = static fn (array $slices): array => array_column($slices, 'prizeId');
    $widths = static fn (array $slices): array => array_column($slices, 'weight');
    $prize = static fn (string $id, string $kind, int $weight): array => [
        'id' => $id,
        'kind' => $kind,
        'label' => $id,
        'kelopak' => $kind === 'kelopak' ? 1 : 0,
        'weight' => $weight,
        'productCode' => null,
    ];
    $campaign = static fn (array $prizes): array => ['version' => 'uji', 'prizes' => $prizes, 'shippingNote' => ''];

    $v3 = rodaDemoConfig();
    $v2 = [
        'version' => 'demo-2026-11',
        'prizes' => [
            ['id' => 'product', 'kind' => 'product', 'label' => 'Produk gratis', 'kelopak' => 0, 'weight' => 1000],
            ['id' => 'kelopak-3', 'kind' => 'kelopak', 'label' => '3 Kelopak', 'kelopak' => 3, 'weight' => 9000],
        ],
        'shippingNote' => 'Gratis ongkir (Demo)',
    ];
    $saturday = rodaWibDayOf($at('2026-11-28T03:00:00Z'));

    $expect($saturday, 20785, 'hari WIB 28 Nov 2026');
    $expect(rodaWibDayOf($at('2026-11-27T16:59:59Z')), $saturday - 1, 'Jumat 23.59.59 WIB');
    $expect(rodaWibDayOf($at('2026-11-27T17:00:00Z')), $saturday, 'Sabtu 00.00 WIB');
    $expect(rodaWeekday(0), 4, 'hari 0 Kamis');
    $expect(rodaWeekday(-1), 3, 'hari -1 Rabu');
    $expect(rodaIsSaturdayWib($saturday), true, '28 Nov 2026 Sabtu');
    $expect(rodaDaysUntilSaturday($saturday), 0, 'Sabtu: 0 hari');
    $expect(rodaDaysUntilSaturday($saturday + 1), 6, 'Minggu: 6 hari');
    $expect(rodaDaysUntilSaturday($saturday - 1), 1, 'Jumat: 1 hari');
    $expect(rodaSpinEligibility($saturday, null, false), 'promoInactive', 'promo mati');
    $expect(rodaSpinEligibility($saturday - 1, null, true), 'notSaturday', 'bukan Sabtu');
    $expect(rodaSpinEligibility($saturday, $saturday, true), 'alreadySpun', 'sudah memutar');
    $expect(rodaSpinEligibility($saturday, $saturday + 7, true), 'alreadySpun', 'jam dimundurkan');
    $expect(rodaSpinEligibility($saturday, $saturday - 7, true), 'available', 'Sabtu baru');
    $expect(rodaNextSpinSaturday($saturday - 3, null), $saturday, 'Rabu -> Sabtu ini');
    $expect(rodaNextSpinSaturday($saturday, null), $saturday + 7, 'Sabtu -> pekan depan');
    $expect(rodaNextSpinSaturday($saturday, $saturday), $saturday + 7, 'sudah memutar -> pekan depan');
    $expect(rodaNextSpinSaturday($saturday - 2, $saturday + 7), $saturday + 14, 'jam mundur setelah memutar');

    $expect(rodaEffectiveWeights($v2, 1), [1000, 9000], 'v2 ada stok');
    $expect(rodaEffectiveWeights($v2, 0), [0, 10000], 'v2 stok habis');
    $expect(rodaEffectiveWeights($v2, -4), [0, 10000], 'v2 stok negatif');
    $expect(rodaEffectiveWeights($v3, 5), [500, 500, 1500, 3000, 4500], 'v3 ada kuota');
    $expect(rodaEffectiveWeights($v3, 0), [0, 500, 1500, 3000, 5000], 'v3 kuota habis: pindah ke 1 Kelopak');
    $expect(rodaEffectiveWeights(['fallbackPrizeId' => null] + $v3, 0), [0, 526, 1579, 3158, 4737], 'v3 tanpa cadangan: proporsional');
    $thirds = $campaign([$prize('p', 'product', 1000), $prize('a', 'kelopak', 3000), $prize('b', 'kelopak', 3000), $prize('c', 'kelopak', 3000)]);
    $expect(rodaEffectiveWeights($thirds, 0), [0, 3334, 3333, 3333], 'sisa terbesar, seri ke yang lebih awal');

    $expect(rodaResolveSpin($v2, 1, 0)['id'], 'product', 'v2 roll 0');
    $expect(rodaResolveSpin($v2, 1, 999)['id'], 'product', 'v2 roll 999');
    $expect(rodaResolveSpin($v2, 1, 1000)['id'], 'kelopak-3', 'v2 roll 1000');
    $expect(rodaResolveSpin($v2, 0, 0)['id'], 'kelopak-3', 'v2 stok habis roll 0');
    $bounds = [
        0 => 'product', 499 => 'product', 500 => 'kelopak-10', 999 => 'kelopak-10', 1000 => 'kelopak-5',
        2499 => 'kelopak-5', 2500 => 'kelopak-3', 5499 => 'kelopak-3', 5500 => 'kelopak-1', 9999 => 'kelopak-1',
    ];
    foreach ($bounds as $roll => $id) {
        $expect(rodaResolveSpin($v3, 3, $roll)['id'], $id, "v3 roll $roll");
    }
    $emptyBounds = [
        0 => 'kelopak-10', 499 => 'kelopak-10', 500 => 'kelopak-5', 1999 => 'kelopak-5',
        2000 => 'kelopak-3', 4999 => 'kelopak-3', 5000 => 'kelopak-1', 9999 => 'kelopak-1',
    ];
    foreach ($emptyBounds as $roll => $id) {
        $expect(rodaResolveSpin($v3, 0, $roll)['id'], $id, "v3 kuota habis roll $roll");
    }
    $tally = [];
    for ($roll = 0; $roll < RODA_TOTAL_WEIGHT; $roll++) {
        $id = rodaResolveSpin($v3, 1, $roll)['id'];
        $tally[$id] = ($tally[$id] ?? 0) + 1;
    }
    $expect($tally, ['product' => 500, 'kelopak-10' => 500, 'kelopak-5' => 1500, 'kelopak-3' => 3000, 'kelopak-1' => 4500], 'v3: 10000 roll = bobot');
    $expect($throws(static fn () => rodaResolveSpin($v3, 1, -1), RangeException::class), true, 'roll -1 ditolak');
    $expect($throws(static fn () => rodaResolveSpin($v3, 1, 10000), RangeException::class), true, 'roll 10000 ditolak');

    $invalid = static fn (array $config, int $stock = 1): bool => $throws(
        static fn () => rodaEffectiveWeights($config, $stock),
        InvalidArgumentException::class,
    );
    $expect($invalid($campaign([])), true, 'tanpa hadiah ditolak');
    $expect($invalid($campaign([$prize('a', 'kelopak', -1)])), true, 'bobot negatif ditolak');
    $expect($invalid($campaign([$prize('a', 'kelopak', 1), $prize('a', 'kelopak', 1)])), true, 'ID ganda ditolak');
    $expect($invalid($campaign([$prize('p', 'product', 1000)]), 0), true, 'hanya produk tanpa stok ditolak');
    $expect($invalid(['fallbackPrizeId' => 'product'] + $v3), true, 'cadangan berupa produk ditolak');
    $expect($invalid(['fallbackPrizeId' => 'tidak-ada'] + $v3), true, 'cadangan tak dikenal ditolak');
    $expect($invalid(['wheelLayout' => [['prizeId' => 'tidak-ada', 'units' => 1]]] + $v3), true, 'tata letak: hadiah tak dikenal ditolak');
    $expect($invalid(['wheelLayout' => [['prizeId' => 'product', 'units' => 0]]] + $v3), true, 'tata letak: 0 unit ditolak');

    $demo = rodaBuildWheelSlices($v3, 5);
    $expect($ids($demo), ['product', 'kelopak-1', 'kelopak-3', 'kelopak-1', 'kelopak-10', 'kelopak-5', 'kelopak-3', 'kelopak-1'], 'v3 urutan irisan');
    $expect($widths($demo), [500, 1500, 1500, 1500, 500, 1500, 1500, 1500], 'v3 lebar irisan');
    $expect(array_column($demo, 'sweepDeg'), [18.0, 54.0, 54.0, 54.0, 18.0, 54.0, 54.0, 54.0], 'v3 sudut irisan');
    $expect(array_column($demo, 'startDeg'), [0.0, 18.0, 72.0, 126.0, 180.0, 198.0, 252.0, 306.0], 'v3 awal irisan');
    $expect(array_column($demo, 'index'), [0, 1, 2, 3, 4, 5, 6, 7], 'v3 indeks irisan');
    $expect(rodaBuildWheelSlices($v3, 1), $demo, 'v3: sisa kuota berapa pun memberi roda yang sama');
    $empty = rodaBuildWheelSlices($v3, 0);
    $expect($ids($empty), ['kelopak-10', 'kelopak-1', 'kelopak-5', 'kelopak-1', 'kelopak-3', 'kelopak-1', 'kelopak-3', 'kelopak-1'], 'v3 kuota habis: urutan otomatis');
    $expect($widths($empty), [500, 1250, 1500, 1250, 1500, 1250, 1500, 1250], 'v3 kuota habis: lebar');
    $expect(rodaBuildWheelSlices($v3, -2), $empty, 'v3: kuota negatif = habis');
    $v2Slices = rodaBuildWheelSlices($v2, 1);
    $expect($ids($v2Slices), ['product', 'kelopak-3', 'kelopak-3', 'kelopak-3', 'kelopak-3', 'kelopak-3', 'kelopak-3'], 'v2: produk lalu enam irisan');
    $expect($widths($v2Slices), [1000, 1500, 1500, 1500, 1500, 1500, 1500], 'v2: lebar');
    $expect($widths(rodaBuildWheelSlices($v2, 0)), [1429, 1428, 1429, 1428, 1429, 1428, 1429], 'v2 stok habis: tujuh irisan');
    $tooWide = ['wheelLayout' => [['prizeId' => 'product', 'units' => 2], ['prizeId' => 'kelopak-3', 'units' => 18]]] + $v2;
    $expect(rodaBuildWheelSlices($tooWide, 1), $v2Slices, 'tata letak dengan irisan di atas 3 unit: susunan otomatis');
    $mismatch = ['wheelLayout' => [['prizeId' => 'product', 'units' => 1], ['prizeId' => 'kelopak-3', 'units' => 3]]] + $v2;
    $expect(rodaBuildWheelSlices($mismatch, 1), $v2Slices, 'tata letak tidak cocok dengan peluang: susunan otomatis');
    $reversed = rodaBuildWheelSlices(['wheelLayout' => array_reverse($v3['wheelLayout'])] + $v3, 2);
    $expect($ids($reversed), array_reverse($ids($demo)), 'tata letak sah lain dipakai apa adanya');
    $expect($ids(rodaBuildWheelSlices(['fallbackPrizeId' => null] + $v3, 0))[0], 'kelopak-10', 'kuota habis tanpa cadangan: tata letak demo tidak cocok, susunan otomatis');

    mt_srand(20261128);
    $propertyFailures = 0;
    $propertyCases = 0;
    for ($case = 0; $case < 1500; $case++) {
        $prizeCount = mt_rand(1, 6);
        $cuts = [];
        while (count($cuts) < $prizeCount - 1) {
            $cut = mt_rand(0, 3) === 0 ? mt_rand(1, RODA_TOTAL_WEIGHT - 1) : mt_rand(1, 19) * RODA_WHEEL_UNIT_WEIGHT;
            $cuts[$cut] = true;
        }
        $limits = array_keys($cuts);
        sort($limits);
        $limits[] = RODA_TOTAL_WEIGHT;
        $prizes = [];
        $previous = 0;
        foreach ($limits as $i => $limit) {
            $kind = ($i > 0 || $prizeCount === 1 || mt_rand(0, 1) === 0) ? 'kelopak' : 'product';
            $prizes[] = $prize("p$i", $kind, $limit - $previous);
            $previous = $limit;
        }
        $config = $campaign($prizes);
        if ($prizeCount > 1 && mt_rand(0, 2) === 0) {
            $config['fallbackPrizeId'] = 'p' . mt_rand(1, $prizeCount - 1);
        }
        foreach ([0, 2] as $quota) {
            $propertyCases++;
            $weights = rodaEffectiveWeights($config, $quota);
            $slices = rodaBuildWheelSlices($config, $quota);
            $sliceCount = count($slices);
            $area = [];
            $pieces = [];
            foreach ($slices as $i => $slice) {
                $area[$slice['prizeId']] = ($area[$slice['prizeId']] ?? 0) + $slice['weight'];
                $pieces[$slice['prizeId']] = ($pieces[$slice['prizeId']] ?? 0) + 1;
            }
            $ok = $sliceCount > 0
                && array_sum($widths($slices)) === RODA_TOTAL_WEIGHT
                && max($widths($slices)) <= RODA_MAX_SLICE_WEIGHT
                && min($widths($slices)) > 0
                && $slices === rodaBuildWheelSlices($config, $quota);
            foreach ($prizes as $i => $candidate) {
                $ok = $ok && ($area[$candidate['id']] ?? 0) === $weights[$i];
            }
            if ($sliceCount >= 2 && max($pieces) <= intdiv($sliceCount, 2)) {
                foreach ($slices as $i => $slice) {
                    $ok = $ok && $slice['prizeId'] !== $slices[($i + 1) % $sliceCount]['prizeId'];
                }
            }
            if (!$ok) {
                $propertyFailures++;
            }
        }
    }
    $expect($propertyCases, 3000, 'uji sifat acak: jumlah kasus');
    $expect($propertyFailures, 0, 'uji sifat acak: 360 derajat, luas = peluang, maks. 54 derajat, berselang, deterministik');

    $state = ['stock' => 1, 'balance' => 0, 'products' => 0];
    $won = claimSaturdaySpin($state, $saturday, 0);
    $expect($won['id'], 'product', 'klaim: roll 0 produk');
    $expect([$state['stock'], $state['products'], $state['balance']], [0, 1, 0], 'klaim: kuota berkurang, hak produk bertambah');
    $expect([$state['spinDay'], $state['spinPrizeId'], $state['spinResult']], [$saturday, 'product', 'Produk gratis'], 'klaim: hasil tercatat');
    $duplicate = $throws(static function () use (&$state, $saturday): void {
        claimSaturdaySpin($state, $saturday, 0);
    }, DomainException::class);
    $expect($duplicate, true, 'klaim ganda ditolak');
    $next = claimSaturdaySpin($state, $saturday + 7, 0);
    $expect($next['id'], 'kelopak-10', 'kuota habis: roll 0 jatuh ke 10 Kelopak');
    $expect($state['balance'], 10, 'saldo bertambah 10');
    $fallback = ['stock' => 0, 'balance' => 0];
    $expect(claimSaturdaySpin($fallback, $saturday, 9999)['id'], 'kelopak-1', 'kuota habis: roll 9999 hadiah cadangan');
    $expect($fallback['balance'], 1, 'hadiah cadangan menambah 1 Kelopak');
    $weekday = ['stock' => 1];
    $rejected = $throws(static function () use (&$weekday, $saturday): void {
        claimSaturdaySpin($weekday, $saturday - 1, 0);
    }, DomainException::class);
    $expect($rejected, true, 'bukan Sabtu ditolak');
    $expect($weekday, ['stock' => 1], 'penolakan tidak mengubah state');

    foreach ($failures as $failure) {
        fwrite(STDERR, 'GAGAL ' . $failure . PHP_EOL);
    }
    fwrite(STDOUT, sprintf('spin.php swa-uji: %d cek, %d gagal', $checks, count($failures)) . PHP_EOL);
    return $failures === [] ? 0 : 1;
}

if (PHP_SAPI === 'cli' && realpath((string) ($_SERVER['SCRIPT_FILENAME'] ?? '')) === __FILE__) {
    exit(rodaSelfTest());
}
