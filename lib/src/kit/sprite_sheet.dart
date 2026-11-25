import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'motion.dart';

/// Cara lembar sprite diputar.
enum SpriteLoopMode {
  /// Sekali, lalu menahan frame akhir.
  once,

  /// Berulang dari frame pertama.
  loop,

  /// Maju lalu mundur tanpa mengulang frame ujung.
  pingPong,
}

/// Deskripsi satu lembar sprite: grid [columns] × [rows], frame berukuran
/// sama, urut baris.
@immutable
class SpriteSheetSpec {
  const SpriteSheetSpec({
    required this.asset,
    this.package,
    required this.columns,
    required this.rows,
    required this.frameCount,
    required this.frameSize,
    this.fps = 12,
    this.loopMode = SpriteLoopMode.loop,
  })  : imageProvider = null,
        assert(columns > 0 && rows > 0),
        assert(frameCount > 0 && frameCount <= columns * rows),
        assert(fps > 0);

  /// Lembar dari [ImageProvider] apa pun (gambar memori, jaringan, tes).
  const SpriteSheetSpec.image({
    required ImageProvider image,
    required this.columns,
    required this.rows,
    required this.frameCount,
    required this.frameSize,
    this.fps = 12,
    this.loopMode = SpriteLoopMode.loop,
  })  : imageProvider = image,
        asset = '',
        package = null,
        assert(columns > 0 && rows > 0),
        assert(frameCount > 0 && frameCount <= columns * rows),
        assert(fps > 0);

  final String asset;
  final String? package;
  final ImageProvider? imageProvider;
  final int columns;
  final int rows;
  final int frameCount;

  /// Ukuran satu frame dalam piksel sumber.
  final Size frameSize;
  final double fps;
  final SpriteLoopMode loopMode;

  ImageProvider get provider => imageProvider ?? AssetImage(asset, package: package);

  double get aspectRatio => frameSize.width / frameSize.height;

  /// Lama satu lintasan: `frameCount / fps` (pingPong: maju + mundur).
  Duration get passDuration {
    final frames = loopMode == SpriteLoopMode.pingPong && frameCount > 1 ? 2 * frameCount - 2 : frameCount;
    return Duration(microseconds: (frames / fps * Duration.microsecondsPerSecond).round());
  }

  /// Indeks frame pada [seconds] sejak animasi mulai.
  int frameAt(double seconds) {
    final step = math.max(0, (seconds * fps).floor());
    if (frameCount == 1) return 0;
    switch (loopMode) {
      case SpriteLoopMode.once:
        return math.min(step, frameCount - 1);
      case SpriteLoopMode.loop:
        return step % frameCount;
      case SpriteLoopMode.pingPong:
        final period = 2 * frameCount - 2;
        final index = step % period;
        return index < frameCount ? index : period - index;
    }
  }

  /// `true` bila animasi mode `once` sudah menampilkan frame terakhirnya penuh.
  bool isCompleteAt(double seconds) => loopMode == SpriteLoopMode.once && seconds * fps >= frameCount;

  /// Kotak sumber [frame] pada gambar berukuran [imageSize].
  Rect sourceRect(int frame, Size imageSize) {
    final width = imageSize.width / columns;
    final height = imageSize.height / rows;
    return Rect.fromLTWH((frame % columns) * width, (frame ~/ columns) * height, width, height);
  }

  /// Mendekode lembar lebih awal supaya animasi pertama tidak berkedip.
  Future<void> precache(BuildContext context) => precacheImage(provider, context);

  @override
  bool operator ==(Object other) =>
      other is SpriteSheetSpec &&
      other.asset == asset &&
      other.package == package &&
      other.imageProvider == imageProvider &&
      other.columns == columns &&
      other.rows == rows &&
      other.frameCount == frameCount &&
      other.frameSize == frameSize &&
      other.fps == fps &&
      other.loopMode == loopMode;

  @override
  int get hashCode => Object.hash(asset, package, imageProvider, columns, rows, frameCount, frameSize, fps, loopMode);

  @override
  String toString() => 'SpriteSheetSpec(${asset.isEmpty ? imageProvider : asset}, $frameCount frame, $loopMode)';
}

/// Pengendali [SpriteAnimation]: mengganti animasi dan membaca frame aktif.
class SpriteController extends ChangeNotifier {
  SpriteSheetSpec? _current;
  int _frame = 0;
  _SpriteRequest? _request;

  /// Animasi yang sedang tampil (`null` sebelum widget terpasang).
  SpriteSheetSpec? get current => _current;

  /// Indeks frame yang sedang tampil.
  int get frame => _frame;

  /// Memutar [spec] dengan silang-pudar dari animasi yang sedang tampil.
  ///
  /// Untuk mode `once`: [onCompleted] dipanggil saat selesai, lalu kembali ke
  /// animasi dasar bila [returnToBase]; selain itu frame akhir ditahan.
  void play(SpriteSheetSpec spec, {bool returnToBase = true, VoidCallback? onCompleted}) {
    _request = _SpriteRequest(spec, returnToBase: returnToBase, onCompleted: onCompleted);
    notifyListeners();
  }

  /// Kembali ke animasi dasar widget.
  void playBase() {
    _request = const _SpriteRequest(null, returnToBase: false);
    notifyListeners();
  }

  _SpriteRequest? _takeRequest() {
    final request = _request;
    _request = null;
    return request;
  }

  void _report(SpriteSheetSpec spec, int frame) {
    _current = spec;
    _frame = frame;
  }
}

class _SpriteRequest {
  const _SpriteRequest(this.spec, {required this.returnToBase, this.onCompleted});

  final SpriteSheetSpec? spec;
  final bool returnToBase;
  final VoidCallback? onCompleted;
}

class _SheetImage {
  _SheetImage(this.stream, this.listener);

  final ImageStream stream;
  final ImageStreamListener listener;
  ImageInfo? info;

  void dispose() {
    stream.removeListener(listener);
    info?.dispose();
    info = null;
  }
}

/// Memutar lembar sprite dengan satu `drawImageRect` per frame.
///
/// - Lembar didekode sekali (cache gambar Flutter) dan dilepas saat widget
///   dibuang.
/// - Skala piksel dikunci ke [spec] (animasi dasar). Animasi lain yang diputar
///   lewat [controller] dijangkar di [alignment], sehingga frame yang lebih
///   tinggi (lompatan) boleh keluar dari kotak tanpa mengubah tata letak.
/// - Kurangi gerak: frame pertama animasi dasar; `play` langsung selesai.
/// - Ticker diam saat `TickerMode` mati atau [playing] `false`.
class SpriteAnimation extends StatefulWidget {
  const SpriteAnimation({
    super.key,
    required this.spec,
    this.controller,
    this.height,
    this.width,
    this.alignment = Alignment.bottomCenter,
    this.playing = true,
    this.crossFade = const Duration(milliseconds: 120),
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
    this.onCompleted,
  });

  /// Animasi dasar.
  final SpriteSheetSpec spec;
  final SpriteController? controller;

  /// Tinggi kotak (dp). Bila [height] dan [width] kosong, kotak memenuhi
  /// batas induk dengan rasio frame dasar.
  final double? height;
  final double? width;
  final Alignment alignment;
  final bool playing;
  final Duration crossFade;
  final FilterQuality filterQuality;
  final String? semanticLabel;

  /// Dipanggil tiap animasi mode `once` selesai.
  final VoidCallback? onCompleted;

  @override
  State<SpriteAnimation> createState() => _SpriteAnimationState();
}

class _SpriteAnimationState extends State<SpriteAnimation> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  final Map<SpriteSheetSpec, _SheetImage> _sheets = <SpriteSheetSpec, _SheetImage>{};

  late SpriteSheetSpec _active = widget.spec;
  _SpriteRequest? _activeRequest;
  SpriteSheetSpec? _pending;
  _SpriteRequest? _pendingRequest;

  double _time = 0;
  int _frame = 0;
  bool _completed = false;
  Duration _lastTick = Duration.zero;

  SpriteSheetSpec? _fadeFrom;
  int _fadeFromFrame = 0;
  double _fade = 1;

  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller?.addListener(_onRequest);
    widget.controller?._report(_active, 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = reduceMotionOf(context);
    if (reduce && !_reduce) _enterReducedMotion();
    if (!reduce && _reduce) {
      _completed = false;
      _time = 0;
    }
    _reduce = reduce;
    _resolve(widget.spec);
    _syncTicker();
  }

  @override
  void didUpdateWidget(SpriteAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onRequest);
      widget.controller?.addListener(_onRequest);
      widget.controller?._report(_active, _frame);
    }
    if (oldWidget.spec != widget.spec) {
      _resolve(widget.spec);
      if (_active == oldWidget.spec && _pending == null) _switchTo(widget.spec, null);
    }
    _syncTicker();
  }

  void _enterReducedMotion() {
    _pending = null;
    _pendingRequest = null;
    _fadeFrom = null;
    _fade = 1;
    if (_active != widget.spec && _activeRequest?.returnToBase != false) {
      _active = widget.spec;
      _activeRequest = null;
    }
    _frame = _restingFrame(_active, _activeRequest);
    _time = 0;
    _completed = true;
    widget.controller?._report(_active, _frame);
    _repaint.value++;
  }

  int _restingFrame(SpriteSheetSpec spec, _SpriteRequest? request) {
    final holdsEnd = spec.loopMode == SpriteLoopMode.once && request != null && !request.returnToBase;
    return holdsEnd ? spec.frameCount - 1 : 0;
  }

  void _resolve(SpriteSheetSpec spec) {
    final stream = spec.provider.resolve(createLocalImageConfiguration(context));
    final existing = _sheets[spec];
    if (existing != null && existing.stream.key == stream.key) return;
    existing?.dispose();
    late final _SheetImage sheet;
    final listener = ImageStreamListener(
      (info, _) => _onImage(spec, sheet, info),
      onError: (error, stackTrace) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'kit pesta',
          context: ErrorDescription('saat memuat lembar sprite $spec'),
        ));
      },
    );
    sheet = _SheetImage(stream, listener);
    _sheets[spec] = sheet;
    stream.addListener(listener);
  }

  void _onImage(SpriteSheetSpec spec, _SheetImage sheet, ImageInfo info) {
    if (!mounted || _sheets[spec] != sheet) {
      info.dispose();
      return;
    }
    sheet.info?.dispose();
    sheet.info = info;
    if (_pending == spec) {
      final request = _pendingRequest;
      _pending = null;
      _pendingRequest = null;
      _switchTo(spec, request);
    }
    _repaint.value++;
    _syncTicker();
  }

  void _onRequest() {
    final request = widget.controller?._takeRequest();
    if (request == null) return;
    final spec = request.spec ?? widget.spec;
    final effective = request.spec == null ? null : request;
    if (_reduce) {
      _playReduced(spec, effective);
      return;
    }
    _resolve(spec);
    if (_sheets[spec]?.info == null) {
      _pending = spec;
      _pendingRequest = effective;
      return;
    }
    _pending = null;
    _pendingRequest = null;
    _switchTo(spec, effective);
    _syncTicker();
  }

  void _playReduced(SpriteSheetSpec spec, _SpriteRequest? request) {
    final isOnce = spec.loopMode == SpriteLoopMode.once;
    if (!isOnce || request == null || !request.returnToBase) {
      _resolve(spec);
      _active = spec;
      _activeRequest = request;
      _frame = _restingFrame(spec, request);
      widget.controller?._report(_active, _frame);
      _repaint.value++;
    }
    if (isOnce) {
      scheduleMicrotask(() {
        if (!mounted) return;
        request?.onCompleted?.call();
        widget.onCompleted?.call();
      });
    }
  }

  void _switchTo(SpriteSheetSpec spec, _SpriteRequest? request) {
    final fading = widget.crossFade > Duration.zero && _sheets[_active]?.info != null && !_reduce;
    if (fading) {
      _fadeFrom = _active;
      _fadeFromFrame = _frame;
      _fade = 0;
    } else {
      _fadeFrom = null;
      _fade = 1;
    }
    _active = spec;
    _activeRequest = request;
    _time = 0;
    _frame = 0;
    _completed = false;
    widget.controller?._report(_active, _frame);
    _repaint.value++;
  }

  bool get _shouldTick {
    if (_reduce || !widget.playing) return false;
    if (_sheets[_active]?.info == null) return false;
    return !_completed || _fade < 1;
  }

  void _syncTicker() {
    if (_shouldTick) {
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final delta = math.min((elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond, 0.25);
    _lastTick = elapsed;
    var changed = false;

    if (_fade < 1) {
      final span = widget.crossFade.inMicroseconds / Duration.microsecondsPerSecond;
      _fade = span <= 0 ? 1 : math.min(1, _fade + delta / span);
      if (_fade >= 1) _fadeFrom = null;
      changed = true;
    }

    if (!_completed) {
      _time += delta;
      final frame = _active.frameAt(_time);
      if (frame != _frame) {
        _frame = frame;
        changed = true;
      }
      if (_active.isCompleteAt(_time)) {
        _completed = true;
        final request = _activeRequest;
        final finished = _active;
        if (finished != widget.spec && (request?.returnToBase ?? true)) {
          _switchTo(widget.spec, null);
          changed = true;
        }
        request?.onCompleted?.call();
        widget.onCompleted?.call();
      }
    }

    widget.controller?._report(_active, _frame);
    if (changed) _repaint.value++;
    if (!_shouldTick) _ticker.stop();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onRequest);
    _ticker.dispose();
    for (final sheet in _sheets.values) {
      sheet.dispose();
    }
    _sheets.clear();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.spec;
    final height = widget.height;
    final width = widget.width;
    final painter = _SpritePainter(state: this, repaint: _repaint);
    Widget child;
    if (height != null || width != null) {
      final scale = height != null ? height / base.frameSize.height : width! / base.frameSize.width;
      child = SizedBox(
        width: base.frameSize.width * scale,
        height: base.frameSize.height * scale,
        child: CustomPaint(painter: painter),
      );
    } else {
      child = AspectRatio(aspectRatio: base.aspectRatio, child: CustomPaint(painter: painter));
    }
    child = RepaintBoundary(child: child);
    final label = widget.semanticLabel;
    if (label == null) return ExcludeSemantics(child: child);
    return Semantics(image: true, label: label, child: child);
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter({required this.state, required Listenable repaint}) : super(repaint: repaint);

  final _SpriteAnimationState state;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = size.height / state.widget.spec.frameSize.height;
    final fadeFrom = state._fadeFrom;
    if (fadeFrom != null && state._fade < 1) {
      _drawFrame(canvas, size, scale, fadeFrom, state._fadeFromFrame, 1 - state._fade);
      _drawFrame(canvas, size, scale, state._active, state._frame, state._fade);
    } else {
      _drawFrame(canvas, size, scale, state._active, state._frame, 1);
    }
  }

  void _drawFrame(Canvas canvas, Size size, double scale, SpriteSheetSpec spec, int frame, double opacity) {
    final image = state._sheets[spec]?.info?.image;
    if (image == null || opacity <= 0) return;
    final source = spec.sourceRect(frame, Size(image.width.toDouble(), image.height.toDouble()));
    final frameSize = spec.frameSize * scale;
    final target = state.widget.alignment.alongOffset((size - frameSize) as Offset) & frameSize;
    canvas.drawImageRect(
      image,
      source,
      target,
      Paint()
        ..filterQuality = state.widget.filterQuality
        ..color = Color.fromRGBO(255, 255, 255, opacity),
    );
  }

  @override
  bool shouldRepaint(_SpritePainter oldDelegate) => true;
}
