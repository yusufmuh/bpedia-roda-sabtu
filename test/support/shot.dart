/// Alat tangkap layar untuk tes widget.
///
/// Merender widget ke PNG dengan font, gambar, dan bayangan asli supaya hasil
/// kerja UI bisa dilihat tanpa menjalankan aplikasi. Keluaran: `build/shots/`.
///
/// ```dart
/// testWidgets('beranda', (tester) async {
///   await shot(tester, buildApp(), name: 'beranda_terang');
/// });
/// ```
///
/// Berkas ini sama di semua repo Bpedia Demo. Jangan diubah per repo.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ukuran ponsel acuan (dp).
const Size shotPhone = Size(390, 844);

/// Ponsel kecil untuk uji luapan.
const Size shotSmallPhone = Size(360, 640);

const GlobalObjectKey _boundaryKey = GlobalObjectKey('bpedia-shot-boundary');

bool _fontsLoaded = false;

/// Memuat font tes: semua keluarga di `FontManifest.json`, lalu Poppins dari
/// berkas bila paket yang diuji tidak membundelnya (modul game mewarisi font host).
///
/// Semua baca berkas berjalan di dalam `runAsync` karena badan `testWidgets`
/// memakai jam palsu.
Future<void> loadShotFonts(WidgetTester tester) async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  await tester.runAsync<void>(_loadFonts);
}

Future<void> _loadFonts() async {
  final loaded = <String>{};
  try {
    final manifest = json.decode(await rootBundle.loadString('FontManifest.json'));
    if (manifest is List<Object?>) {
      for (final entry in manifest) {
        if (entry is! Map<String, Object?>) continue;
        final family = entry['family'];
        final fonts = entry['fonts'];
        if (family is! String || fonts is! List<Object?>) continue;
        final loader = FontLoader(family);
        for (final font in fonts) {
          if (font is Map<String, Object?> && font['asset'] is String) {
            loader.addFont(rootBundle.load(font['asset']! as String));
          }
        }
        await loader.load();
        loaded.add(family);
      }
    }
  } on Object {
    // Paket tanpa font: lanjut ke berkas.
  }
  for (final family in const <String>['Poppins', 'Fraunces']) {
    if (loaded.contains(family)) continue;
    for (final dir in const <String>['assets/fonts', 'example/assets/fonts', 'test/support/fonts']) {
      final folder = Directory(dir);
      if (!folder.existsSync()) continue;
      final files = folder
          .listSync()
          .whereType<File>()
          .where((f) => f.uri.pathSegments.last.startsWith(family) && f.path.endsWith('.ttf'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      if (files.isEmpty) continue;
      final loader = FontLoader(family);
      for (final file in files) {
        loader.addFont(file.readAsBytes().then(ByteData.sublistView));
      }
      await loader.load();
      loaded.add(family);
      break;
    }
  }
  if (!loaded.contains('MaterialIcons')) {
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icons.existsSync()) {
        final loader = FontLoader('MaterialIcons')
          ..addFont(icons.readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
  }
}

/// Memasang [app] pada layar berukuran [size] (dp) dan menyiapkan penangkapan.
///
/// [app] sebaiknya sudah berupa `MaterialApp` bertema; modul game memakai
/// `ThemeData(fontFamily: 'Poppins')` supaya teks terbaca.
Future<void> pumpShot(
  WidgetTester tester,
  Widget app, {
  Size size = shotPhone,
  double pixelRatio = 2.0,
}) async {
  await loadShotFonts(tester);
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.physicalSize = size * pixelRatio;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(RepaintBoundary(key: _boundaryKey, child: app));
  await settleImages(tester);
}

/// Memberi waktu nyata supaya gambar aset dan lembar sprite selesai didekode.
Future<void> settleImages(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync<void>(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
}

void _repaintAll(WidgetTester tester) {
  void visit(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
}

/// Tes mematikan bayangan secara bawaan; bingkai yang ditangkap dilukis ulang
/// dengan bayangan asli, lalu bendera dikembalikan supaya invarian tes terjaga.
Future<ui.Image> _capture(WidgetTester tester, double pixelRatio) async {
  debugDisableShadows = false;
  try {
    _repaintAll(tester);
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
    final image = await tester.runAsync<ui.Image>(() => boundary.toImage(pixelRatio: pixelRatio));
    return image!;
  } finally {
    debugDisableShadows = true;
    _repaintAll(tester);
  }
}

Future<File> _writePng(WidgetTester tester, ui.Image image, String name) async {
  final file = File('build/shots/$name.png');
  await tester.runAsync<void>(() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
  });
  return file;
}

/// Menyimpan tampilan saat ini ke `build/shots/<name>.png`.
Future<File> saveShot(WidgetTester tester, String name, {double pixelRatio = 2.0}) async {
  final image = await _capture(tester, pixelRatio);
  final file = await _writePng(tester, image, name);
  image.dispose();
  return file;
}

/// Pasang [app], tunggu [settle] (animasi masuk), lalu simpan PNG.
///
/// Untuk halaman panjang, beri [size] yang lebih tinggi (mis. `Size(390, 2200)`)
/// supaya seluruh isi terlihat dalam satu gambar.
Future<File> shot(
  WidgetTester tester,
  Widget app, {
  required String name,
  Size size = shotPhone,
  double pixelRatio = 2.0,
  Duration settle = const Duration(milliseconds: 900),
}) async {
  await pumpShot(tester, app, size: size, pixelRatio: pixelRatio);
  if (settle > Duration.zero) {
    await tester.pump(settle);
    await settleImages(tester, rounds: 2);
  }
  return saveShot(tester, name, pixelRatio: pixelRatio);
}

/// Menangkap [frames] bingkai berjarak [step] lalu menyusunnya menjadi satu
/// lembar kontak `build/shots/<name>.png` untuk menilai animasi.
///
/// Panggil setelah [pumpShot] dan setelah memicu animasi (mis. `tester.tap`).
Future<File> shotStrip(
  WidgetTester tester,
  String name, {
  int frames = 8,
  Duration step = const Duration(milliseconds: 150),
  int columns = 4,
  double pixelRatio = 1.0,
}) async {
  final images = <ui.Image>[];
  for (var i = 0; i < frames; i++) {
    if (i > 0) await tester.pump(step);
    images.add(await _capture(tester, pixelRatio));
  }
  final cellW = images.first.width;
  final cellH = images.first.height;
  final cols = columns.clamp(1, frames);
  final rows = (frames / cols).ceil();
  const gap = 6.0;
  final width = (cols * cellW + (cols + 1) * gap).round();
  final height = (rows * cellH + (rows + 1) * gap).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF7A7A80),
  );
  for (var i = 0; i < images.length; i++) {
    final dx = gap + (i % cols) * (cellW + gap);
    final dy = gap + (i ~/ cols) * (cellH + gap);
    canvas.drawImage(images[i], Offset(dx, dy), Paint());
  }
  final picture = recorder.endRecording();
  final sheet = (await tester.runAsync<ui.Image>(() => picture.toImage(width, height)))!;
  final file = await _writePng(tester, sheet, name);
  for (final image in images) {
    image.dispose();
  }
  sheet.dispose();
  picture.dispose();
  return file;
}
