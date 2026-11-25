import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

import 'support/harness.dart';
import 'support/v2_fixtures.dart';

Widget table(int stock, {SpinConfig config = v2SpinConfig}) => OddsTable(
  odds: effectiveOdds(config, productStock: stock),
  productStock: stock,
  shippingNote: config.shippingNote,
);

void main() {
  testWidgets('shows odds, quota, shipping and the fairness note', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(table(1)));
    expect(find.text('Peluang & ketentuan'), findsOneWidget);
    expect(find.text('Produk gratis'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    expect(find.text('Sisa kuota: 1'), findsOneWidget);
    expect(find.text('3 Kelopak'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('Setara Rp300'), findsOneWidget);
    expect(find.text('Pengiriman hadiah produk'), findsOneWidget);
    expect(find.text('Gratis ongkir (Demo)'), findsOneWidget);
    expect(
      find.text('Hasil ditentukan sistem secara acak sesuai peluang di atas.'),
      findsOneWidget,
    );
  });

  testWidgets('sold out: product 0% with "Kuota habis"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(table(0)));
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Kuota habis'), findsOneWidget);
    expect(find.textContaining('Sisa kuota'), findsNothing);
  });

  testWidgets('formats large quota and decimal percentages', (
    WidgetTester tester,
  ) async {
    const SpinConfig decimal = SpinConfig(
      version: 'decimal',
      prizes: <SpinPrize>[
        SpinPrize(
          id: 'product',
          kind: PrizeKind.product,
          label: 'Produk gratis',
          kelopak: 0,
          weight: 1250,
        ),
        SpinPrize(
          id: 'kelopak-5',
          kind: PrizeKind.kelopak,
          label: '5 Kelopak',
          kelopak: 5,
          weight: 8750,
        ),
      ],
      shippingNote: 'Ongkir ditanggung Bpedia',
    );
    await tester.pumpWidget(harness(table(1500, config: decimal)));
    expect(find.text('12,5%'), findsOneWidget);
    expect(find.text('87,5%'), findsOneWidget);
    expect(find.text('Sisa kuota: 1.500'), findsOneWidget);
    expect(find.text('Setara Rp500'), findsOneWidget);
    expect(find.text('Ongkir ditanggung Bpedia'), findsOneWidget);
  });

  testWidgets('each row is one semantics node and the title is a header', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(table(1)));
    final SemanticsNode product = tester.getSemantics(find.text('10%'));
    expect(product.label, contains('Produk gratis'));
    expect(product.label, contains('Sisa kuota: 1'));
    expect(product.label, contains('10%'));
    final SemanticsNode kelopak = tester.getSemantics(find.text('90%'));
    expect(kelopak.label, contains('3 Kelopak'));
    expect(kelopak.label, contains('Setara Rp300'));
    expect(
      tester.getSemantics(find.text('Peluang & ketentuan')),
      isSemantics(isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('heading and footnote stay separate from the page around them', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    const String note =
        'Hasil ditentukan sistem secara acak sesuai peluang di atas.';
    // A list item is a semantics container (IndexedSemantics in a ListView):
    // loose text inside it becomes the item's own label.
    await tester.pumpWidget(
      harness(
        Semantics(
          container: true,
          child: Column(
            children: <Widget>[
              const Text('Buka Sabtu, 5 Des · 00.00 WIB'),
              table(1),
              const Text('Tombol aktif Sabtu, 5 Des · 00.00 WIB.'),
            ],
          ),
        ),
      ),
    );
    final SemanticsNode heading = tester.getSemantics(
      find.text('Peluang & ketentuan'),
    );
    expect(heading, isSemantics(label: 'Peluang & ketentuan', isHeader: true));
    expect(heading.childrenCount, 0);
    expect(tester.getSemantics(find.text(note)), isSemantics(label: note));
    handle.dispose();
  });

  testWidgets('wheel and table fit 360x740 at 200% text without overflow', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 740)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final List<SpinOdds> odds = effectiveOdds(v2SpinConfig, productStock: 1);
    await tester.pumpWidget(
      harness(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              SaturdayWheel(
                odds: odds,
                resultPrizeId: 'kelopak-3',
                spinToken: 0,
                landingSeed: 5,
              ),
              const SizedBox(height: 16),
              OddsTable(
                odds: odds,
                productStock: 1,
                shippingNote: v2SpinConfig.shippingNote,
              ),
            ],
          ),
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Sisa kuota: 1'), findsOneWidget);
    final RichText percent = tester.widget<RichText>(
      find.descendant(of: find.text('10%'), matching: find.byType(RichText)),
    );
    expect(percent.textScaler, const TextScaler.linear(2));
    expect(
      tester.getSize(
        find.descendant(
          of: find.byType(SaturdayWheel),
          matching: find.byType(Stack),
        ),
      ),
      const Size(320, 320),
    );
  });

  testWidgets('sold-out table also fits at 200% text', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 740)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        Padding(padding: const EdgeInsets.all(16), child: table(0)),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Kuota habis'), findsOneWidget);
  });
}
