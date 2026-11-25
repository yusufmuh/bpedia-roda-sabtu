import 'package:roda_sabtu/roda_sabtu.dart';

/// Kampanye demo v2 (produk 10% selama stok ada, 3 Kelopak 90%), tanpa
/// hadiah cadangan dan tanpa tata letak roda. Tes aturan v2 memakainya
/// supaya asersi lama tetap berlaku setelah `demoSpinConfig` berisi nilai v3.
const SpinConfig v2SpinConfig = SpinConfig(
  version: 'demo-2026-11',
  prizes: <SpinPrize>[
    SpinPrize(
      id: 'product',
      kind: PrizeKind.product,
      label: 'Produk gratis',
      kelopak: 0,
      weight: 1000,
    ),
    SpinPrize(
      id: 'kelopak-3',
      kind: PrizeKind.kelopak,
      label: '3 Kelopak',
      kelopak: 3,
      weight: 9000,
    ),
  ],
  shippingNote: 'Gratis ongkir (Demo)',
);
