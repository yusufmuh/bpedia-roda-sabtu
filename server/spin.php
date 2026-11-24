<?php
declare(strict_types=1);

function claimSpin(array &$state, int $day, int $draw): string {
    if ($day < $state['start'] || $day >= $state['start'] + 365 ||
        gmdate('N', $day * 86400) !== '6') {
        throw new DomainException('Roda tersedia pada Sabtu selama promo demo.');
    }
    if ($state['spinDay'] === $day) throw new DomainException('Putaran Sabtu ini sudah digunakan.');
    // Each demo account has an isolated promotional inventory.
    $product = $state['stock'] > 0 && $draw < 10;
    if ($product) {
        $state['stock']--;
        $state['products']++;
    } else {
        $state['balance'] += 3;
    }
    $state['spinDay'] = $day;
    $state['spinResult'] = $product ? '1 produk demo' : '3 Kelopak';
    return 'Roda Sabtu · ' . $state['spinResult'];
}
