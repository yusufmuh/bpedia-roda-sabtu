import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

import '../format.dart';
import '../kit/kit.dart';
import '../odds_table.dart';
import '../prize_wheel.dart';
import '../schedule.dart';
import '../spin_engine.dart';
import '../wheel_assets.dart';
import '../wheel_opening.dart';
import '../wheel_view.dart';
import '../widgets/lively_pose.dart';
import '../widgets/wheel_countdown.dart';
import '../widgets/wheel_history.dart';
import '../widgets/wheel_how_it_works.dart';
import '../widgets/wheel_prize_card.dart';

/// Halaman Roda Sabtu siap pakai (SPEC-V3 §6.2): panggung pesta dengan roda
/// 3D, strip peluang, aksi sesuai keadaan (putar, hitung mundur, hasil
/// minggu ini, masuk), lalu panel putih berisi hadiah minggu ini, tabel
/// peluang, cara kerja, dan riwayat.
///
/// Halaman hanya membaca [WheelController.state] dan memanggil aksinya;
/// sumber data (lokal atau server) ditentukan host.
class WheelPage extends StatefulWidget {
  /// Membuat halaman di atas [controller].
  const WheelPage({
    super.key,
    required this.controller,
    this.onBack,
    this.ambientMotion = true,
  });

  /// Sumber keadaan dan aksi.
  final WheelController controller;

  /// Tombol kembali. Bawaan: `Navigator.maybePop`.
  final VoidCallback? onBack;

  /// Lampu roda berkejaran saat diam dan perayaan setelah menang. Matikan
  /// untuk tes yang menunggu semua animasi berhenti.
  final bool ambientMotion;

  /// Jeda dari roda berhenti sampai lembar hasil naik.
  static const Duration resultDelay = Duration(milliseconds: 900);

  @override
  State<WheelPage> createState() => _WheelPageState();
}

class _WheelPageState extends State<WheelPage> {
  static const Duration _tickGap = Duration(milliseconds: 50);

  final ConfettiController _confetti = ConfettiController();
  final CoinFountainController _fountain = CoinFountainController();
  final GlobalKey _wheelKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  Timer? _sheetTimer;
  int _spinToken = 0;
  String? _resultPrizeId;
  int _landingSeed = 0;
  bool _starting = false;
  bool _spinning = false;
  bool _celebrating = false;
  List<SpinOdds>? _frozenOdds;
  WheelSpinResult? _pending;
  Duration? _lastTick;

  WheelController get _controller => widget.controller;

  bool get _busy => _starting || _spinning;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _restFromState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final ImageProvider image in const <ImageProvider>[
      WheelArt.poseFocus,
      WheelArt.poseCelebrate,
      WheelArt.poseCheer,
      WheelArt.faceWink,
      WheelArt.podium,
      WheelArt.coin,
      WheelArt.coinStack10,
    ]) {
      unawaited(precacheImage(image, context));
    }
  }

  @override
  void didUpdateWidget(WheelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
      _restFromState();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _sheetTimer?.cancel();
    _confetti.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _restFromState() {
    final WheelSpinRecord? record = _controller.state.thisWeekSpin;
    _resultPrizeId = record?.prizeId;
    _landingSeed = record?.day ?? 0;
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {
      if (!_busy && _pending == null) _restFromState();
    });
  }

  Future<void> _spin() async {
    final WheelViewState state = _controller.state;
    if (!state.signedIn) {
      _controller.openLogin();
      return;
    }
    if (!state.canSpin || _busy) return;
    final List<SpinOdds> odds = state.odds;
    setState(() => _starting = true);
    emitCue(_controller.playCue, GameCue.spinStart);
    if (_scroll.hasClients && _scroll.offset > 0) {
      unawaited(
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        ),
      );
    }
    WheelSpinResult? result;
    try {
      result = await _controller.spin();
    } on Object {
      if (!mounted) return;
      setState(() => _starting = false);
      emitCue(_controller.playCue, GameCue.softError);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Putaran belum terkirim. Cek koneksi lalu coba lagi.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    final WheelSpinResult? won = result;
    setState(() {
      _starting = false;
      if (won == null) return;
      _spinning = true;
      _celebrating = false;
      _frozenOdds = odds;
      _pending = won;
      _resultPrizeId = won.prize.id;
      _landingSeed = won.landingSeed;
      _spinToken++;
    });
  }

  void _onPeg() {
    final Duration now = SchedulerBinding.instance.currentFrameTimeStamp;
    final Duration? last = _lastTick;
    if (last != null && now - last < _tickGap) return;
    _lastTick = now;
    emitCue(_controller.playCue, GameCue.tick);
  }

  void _onSettled() {
    final WheelSpinResult? result = _pending;
    setState(() {
      _spinning = false;
      _frozenOdds = null;
      _celebrating = result != null;
    });
    if (result == null) return;
    final bool product = result.prize.kind == PrizeKind.product;
    final bool reduce = reduceMotionOf(context);
    final String message = product
        ? 'Selamat, kamu menang produk gratis'
              '${result.product == null ? '' : ': ${result.product!.name}'}.'
        : 'Selamat, kamu dapat ${result.prize.kelopak} Kelopak.';
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
    emitCue(
      _controller.playCue,
      product ? GameCue.winProduct : GameCue.winKelopak,
    );
    if (!reduce) {
      _confetti.fire(style: ConfettiStyle.cannons, power: product ? 1.2 : 1);
      if (!product) {
        unawaited(
          _fountain.spray(
            originKey: _wheelKey,
            count: math.min(result.prize.kelopak * 3, 24),
          ),
        );
      }
    }
    _sheetTimer?.cancel();
    _sheetTimer = Timer(
      reduce ? const Duration(milliseconds: 300) : WheelPage.resultDelay,
      () {
        if (mounted) unawaited(_showResult(result));
      },
    );
  }

  Future<void> _showResult(WheelSpinResult result) async {
    await showResultSheet<void>(
      context,
      builder: (BuildContext sheet) => _resultSheet(sheet, result),
    );
    if (!mounted) return;
    setState(() {
      _pending = null;
      _celebrating = false;
      _restFromState();
    });
  }

  Widget _resultSheet(BuildContext sheet, WheelSpinResult result) {
    final SpinPrize prize = result.prize;
    if (prize.kind == PrizeKind.product) {
      final WheelPrizeProduct? item = result.product;
      return ResultSheet(
        ribbon: 'Selamat!',
        title: 'Selamat, kamu menang!',
        pill: '1 produk gratis',
        podium: WheelArt.podium,
        art: item == null
            ? const Image(image: WheelArt.gift)
            : SizedBox.square(
                dimension: 124,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  child: Image(image: item.image, fit: BoxFit.cover),
                ),
              ),
        companion: const SpriteAnimation(
          spec: WheelSprites.dance,
          height: 118,
          semanticLabel: 'Bipy menari',
        ),
        caption: item?.name ?? prize.label,
        message:
            'Hadiah masuk ke keranjang dan dikirim bersama pesanan '
            'berikutnya.',
        primaryLabel: 'Lihat keranjang',
        onPrimary: () {
          Navigator.of(sheet).pop();
          _controller.openCart();
        },
        secondaryLabel: 'Belanja sekarang',
        onSecondary: () {
          Navigator.of(sheet).pop();
          _controller.openShop();
        },
      );
    }
    final bool big = prize.kelopak >= 5;
    return ResultSheet(
      ribbon: 'Selamat!',
      title: big ? 'Hoki besar, Babes!' : 'Kelopak masuk, Babes!',
      podium: WheelArt.podium,
      art: SizedBox(
        width: 168,
        child: Image(image: WheelArt.forPrize(prize), fit: BoxFit.contain),
      ),
      companion: LivelyPose(
        image: big ? WheelArt.poseCelebrate : WheelArt.poseCheer,
        height: 112,
        energy: 1.6,
      ),
      amount: prize.kelopak,
      amountSuffix: ' Kelopak',
      caption: 'Senilai ${formatRupiah(prize.kelopak * rupiahPerKelopak)}',
      message: 'Masuk ke saldo. Otomatis memotong belanja saat checkout.',
      note: '1 Kelopak = Rp100',
      primaryLabel: 'Mantap',
      primaryVariant: CandyVariant.gold,
      onPrimary: () => Navigator.of(sheet).pop(),
    );
  }

  Future<bool> _confirmLeave() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('Roda masih berputar'),
        content: const Text(
          'Hasilmu sudah tersimpan dan tetap masuk walau kamu keluar '
          'sekarang.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Keluar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Tetap di sini'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _handleBack() async {
    if (_busy) {
      if (!await _confirmLeave() || !mounted) return;
      final VoidCallback? back = widget.onBack;
      if (back != null) {
        back();
      } else {
        Navigator.of(context).pop();
      }
      return;
    }
    final VoidCallback? back = widget.onBack;
    if (back != null) {
      back();
    } else {
      await Navigator.of(context).maybePop();
    }
  }

  void _openOdds() {
    final WheelViewState state = _controller.state;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (BuildContext sheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  OddsTable(
                    odds: state.odds,
                    productStock: state.productQuotaLeft,
                    shippingNote: state.config.shippingNote,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(sheet).pop();
                      _controller.openTerms();
                    },
                    child: const Text('Syarat & ketentuan lengkap'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _idleSemantics(WheelViewState state, WheelOpening opening) {
    if (!state.promoActive) return 'Promo sedang tidak aktif';
    if (!state.signedIn) return 'Masuk untuk memutar';
    return switch (state.eligibility) {
      SpinEligibility.available => 'Siap diputar',
      SpinEligibility.promoInactive => 'Promo sedang tidak aktif',
      SpinEligibility.alreadySpun ||
      SpinEligibility.notSaturday => 'Dibuka ${opening.dayLabel}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final WheelViewState state = _controller.state;
    final WheelOpening opening = state.openingAt(_controller.now());
    final bool? soundOn = state.soundOn;
    final List<WheelSpinRecord> history = _pending != null
        ? state.history.skip(1).toList()
        : state.history;
    final int balance = _pending != null
        ? state.balance - _pending!.prize.kelopak
        : state.balance;
    return PopScope<Object?>(
      canPop: !_busy,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) unawaited(_handleBack());
      },
      child: ConfettiBurst(
        controller: _confetti,
        child: CoinFountain(
          controller: _fountain,
          image: WheelArt.coin,
          child: GameScaffold(
            title: 'Roda Sabtu',
            onBack: () => unawaited(_handleBack()),
            scrollController: _scroll,
            backdrop: const _StageBackdrop(),
            actions: <Widget>[
              if (soundOn != null)
                GameBarAction(
                  icon: soundOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  tooltip: soundOn ? 'Matikan suara' : 'Nyalakan suara',
                  onPressed: () => _controller.setSoundOn(!soundOn),
                ),
              GameBarAction.text(label: 'Aturan', onPressed: _openOdds),
            ],
            hero: _hero(state, opening, balance),
            slivers: <Widget>[
              SliverToBoxAdapter(child: _panel(state, history)),
            ],
            bottomBar: _bottomBar(state, opening),
          ),
        ),
      ),
    );
  }

  Widget _hero(WheelViewState state, WheelOpening opening, int balance) {
    final TextStyle base =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final List<SpinOdds> odds = _frozenOdds ?? state.odds;
    final int quota = _busy
        ? state.productQuotaLeft +
              (_pending?.prize.kind == PrizeKind.product ? 1 : 0)
        : state.productQuotaLeft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            const GlassChip(
              label: 'Gratis 1 putaran tiap Sabtu',
              leading: Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: FestivePalette.goldLight,
              ),
            ),
            if (state.signedIn)
              BalanceChip(
                value: balance,
                suffix: ' Kelopak',
                semanticLabel: 'Saldo $balance Kelopak',
              ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            'Roda Sabtu',
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.6),
            style: base.copyWith(
              color: Colors.white,
              fontSize: 26,
              height: 32 / 26,
              fontWeight: FontWeight.w800,
              shadows: const <Shadow>[
                Shadow(
                  color: FestivePalette.festDeep,
                  offset: Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Menangkan produk gratis atau Kelopak',
          style: base.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 14,
            height: 20 / 14,
          ),
        ),
        const SizedBox(height: 8),
        _WheelStage(
          wheelKey: _wheelKey,
          celebrating: _celebrating,
          spinning: _busy,
          token: _spinToken,
          wheel: PrizeWheel(
            odds: odds,
            layout: state.config.wheelLayout,
            resultPrizeId: _resultPrizeId,
            spinToken: _spinToken,
            landingSeed: _landingSeed,
            onSettled: _onSettled,
            onPegPassed: _onPeg,
            idleSemanticsValue: _idleSemantics(state, opening),
            ambientMotion: widget.ambientMotion,
          ),
        ),
        const SizedBox(height: 10),
        OddsStrip(
          odds: odds,
          productStock: quota,
          onOpenDetails: _openOdds,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 10),
        _status(state, opening),
      ],
    );
  }

  Widget _status(WheelViewState state, WheelOpening opening) {
    final WheelSpinRecord? record = state.thisWeekSpin;
    if (_busy || _pending != null) {
      return const _HeroNote(
        icon: Icons.local_shipping_rounded,
        text:
            'Hadiah produk dikirim bersama pesanan belanja berikutnya, '
            'tanpa ongkir tambahan.',
      );
    }
    if (!state.promoActive) {
      return const _HeroNote(
        icon: Icons.event_busy_rounded,
        text:
            'Promo Roda Sabtu sedang tidak aktif. Pantau Event Promo untuk '
            'jadwal berikutnya.',
        boxed: true,
      );
    }
    if (state.signedIn && record != null) {
      return _WeekResultCard(record: record, opening: opening);
    }
    if (state.eligibility == SpinEligibility.notSaturday) {
      return WheelCountdown(
        saturday: state.nextSaturday,
        now: _controller.now,
        showReminder: state.signedIn && state.reminderSupported,
        reminderOn: state.reminderOn,
        onReminderChanged: (bool on) => unawaited(_controller.setReminder(on)),
      );
    }
    return const _HeroNote(
      icon: Icons.local_shipping_rounded,
      text:
          'Hadiah produk dikirim bersama pesanan belanja berikutnya, '
          'tanpa ongkir tambahan.',
    );
  }

  Widget _panel(WheelViewState state, List<WheelSpinRecord> history) {
    final ThemeData theme = Theme.of(context);
    final WheelPrizeProduct? product = state.product;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _SectionTitle('Hadiah minggu ini'),
          const SizedBox(height: 12),
          WheelPrizeCard(
            product: product,
            quotaLeft: state.productQuotaLeft,
            shippingNote: state.config.shippingNote,
            onOpenProduct: product == null
                ? null
                : () => _controller.openProduct(product.code),
          ),
          const SizedBox(height: 28),
          OddsTable(
            odds: state.odds,
            productStock: state.productQuotaLeft,
            shippingNote: state.config.shippingNote,
          ),
          const SizedBox(height: 28),
          const _SectionTitle('Cara kerja'),
          const SizedBox(height: 12),
          const WheelHowItWorks(),
          const SizedBox(height: 28),
          const _SectionTitle('Riwayat putaranmu'),
          const SizedBox(height: 4),
          if (state.signedIn)
            WheelHistoryList(records: history)
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Masuk untuk melihat riwayat putaranmu.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _controller.openLogin,
                  child: const Text('Masuk'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _controller.openTerms,
              child: const Text('Syarat & ketentuan lengkap'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(WheelViewState state, WheelOpening opening) {
    if (_busy) {
      return CandyButton(
        label: 'Sedang berputar',
        sublabel: 'Semoga hoki, Babes!',
        busy: true,
        onPressed: _spin,
      );
    }
    if (!state.signedIn) {
      return CandyButton(
        label: 'Masuk untuk memutar',
        sublabel: 'Putaran gratis tiap Sabtu',
        onPressed: _controller.openLogin,
      );
    }
    switch (state.eligibility) {
      case SpinEligibility.available:
        return CandyButton(
          label: 'Putar gratis',
          sublabel: '1 putaran gratis hari ini',
          pulse: true,
          onPressed: () => unawaited(_spin()),
        );
      case SpinEligibility.alreadySpun:
        final bool product = state.thisWeekSpin?.kind == PrizeKind.product;
        return CandyButton(
          label: product
              ? 'Lihat hadiah di keranjang'
              : 'Belanja pakai Kelopak',
          sublabel: 'Roda dibuka lagi ${opening.dayLabel}',
          variant: CandyVariant.tonal,
          onPressed: product ? _controller.openCart : _controller.openShop,
        );
      case SpinEligibility.notSaturday:
        return CandyButton(
          label: 'Belanja sambil menunggu',
          sublabel: 'Roda dibuka ${opening.dayLabel}',
          variant: CandyVariant.tonal,
          onPressed: _controller.openShop,
        );
      case SpinEligibility.promoInactive:
        return CandyButton(
          label: 'Belanja sekarang',
          variant: CandyVariant.tonal,
          onPressed: _controller.openShop,
        );
    }
  }
}

/// Latar panggung: gradasi radial pink ke plum, sinar berputar, kilau.
class _StageBackdrop extends StatelessWidget {
  const _StageBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.15),
          radius: 1.05,
          colors: <Color>[
            FestivePalette.festTop,
            FestivePalette.candyBottom,
            FestivePalette.festDeep,
          ],
          stops: <double>[0, 0.55, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          SunburstRays(center: Alignment(0, -0.2)),
          Sparkles(count: 16, maxSize: 14),
        ],
      ),
    );
  }
}

/// Roda di atas lantai melengkung, dikelilingi stiker melayang, Bipy di
/// samping, dan kilatan sinar saat menang.
class _WheelStage extends StatelessWidget {
  const _WheelStage({
    required this.wheelKey,
    required this.wheel,
    required this.celebrating,
    required this.spinning,
    required this.token,
  });

  final GlobalKey wheelKey;
  final Widget wheel;
  final bool celebrating;
  final bool spinning;
  final int token;

  @override
  Widget build(BuildContext context) {
    final bool reduce = reduceMotionOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double side = math.min(
          math.min(MediaQuery.sizeOf(context).width * 0.86, width),
          360,
        );
        final double height = PrizeWheel.heightFor(side);
        final ImageProvider pose = spinning
            ? WheelArt.poseFocus
            : celebrating
            ? WheelArt.poseCelebrate
            : WheelArt.poseCheer;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: <Widget>[
              Positioned(
                left: -16,
                right: -16,
                bottom: -side * 0.02,
                height: side * 0.16,
                child: const _Floor(),
              ),
              if (celebrating && !reduce)
                Positioned(
                  left: width / 2 - side * 0.75,
                  top: side * 0.52 - side * 0.75,
                  width: side * 1.5,
                  height: side * 1.5,
                  child: _WinFlash(key: ValueKey<int>(token)),
                ),
              Positioned(
                left: 0,
                top: side * 0.02,
                child: const _Sticker(
                  image: WheelArt.stickerStar,
                  size: 38,
                  phase: 0,
                ),
              ),
              Positioned(
                right: 0,
                top: side * 0.05,
                child: const _Sticker(
                  image: WheelArt.stickerHeart,
                  size: 36,
                  phase: 0.4,
                ),
              ),
              Positioned(
                right: 2,
                top: side * 0.62,
                child: const _Sticker(
                  image: WheelArt.stickerButterfly,
                  size: 34,
                  phase: 0.7,
                ),
              ),
              Positioned(
                left: 4,
                top: side * 0.5,
                child: const _Sticker(
                  image: WheelArt.stickerSparkle,
                  size: 26,
                  phase: 0.2,
                ),
              ),
              SizedBox(
                key: wheelKey,
                width: side,
                height: height,
                child: wheel,
              ),
              Positioned(
                left: -6,
                bottom: 0,
                child: ExcludeSemantics(
                  child: LivelyPose(
                    image: pose,
                    height: side * 0.3,
                    energy: celebrating ? 1.8 : 1,
                  ),
                ),
              ),
              Positioned(
                right: 6,
                bottom: side * 0.04,
                child: const _Sticker(
                  image: WheelArt.stickerLips,
                  size: 34,
                  phase: 0.55,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sticker extends StatelessWidget {
  const _Sticker({
    required this.image,
    required this.size,
    required this.phase,
  });

  final ImageProvider image;
  final double size;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Bobbing(
        amplitude: 5,
        phase: phase,
        tilt: 0.08,
        child: Image(image: image, width: size, height: size),
      ),
    );
  }
}

class _Floor extends StatelessWidget {
  const _Floor();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.elliptical(400, 60),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            FestivePalette.festDeep.withValues(alpha: 0.85),
            FestivePalette.festDeep.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

/// Ledakan sinar emas sekali di belakang roda saat menang.
class _WinFlash extends StatelessWidget {
  const _WinFlash({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1600),
        builder: (BuildContext context, double t, Widget? child) => Opacity(
          opacity: math.sin(math.pi * t).clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.7 + 0.4 * t, child: child),
        ),
        child: const SunburstRays(
          rayCount: 16,
          color: FestivePalette.goldLight,
          opacity: 0.45,
          period: Duration(seconds: 6),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroNote extends StatelessWidget {
  const _HeroNote({required this.icon, required this.text, this.boxed = false});

  final IconData icon;
  final String text;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle());
    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: FestivePalette.goldLight, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: base.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12,
              height: 16 / 12,
            ),
          ),
        ),
      ],
    );
    if (!boxed) return row;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FestivePalette.festDeep.withValues(alpha: 0.42),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: row),
    );
  }
}

/// Kartu hasil minggu ini setelah memutar.
class _WeekResultCard extends StatelessWidget {
  const _WeekResultCard({required this.record, required this.opening});

  final WheelSpinRecord record;
  final WheelOpening opening;

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle());
    final bool product = record.kind == PrizeKind.product;
    final String title = product
        ? 'Kamu menang ${record.title}'
        : 'Kamu dapat ${record.kelopak} Kelopak';
    final String body = product
        ? 'Sudah di keranjang, ikut pesanan berikutnya.'
        : 'Sudah masuk saldo. Sampai Sabtu depan, Babes!';
    return Semantics(
      container: true,
      label:
          'Hasil Sabtu ini. $title. $body Roda dibuka lagi '
          '${opening.opensAtLabel}.',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FestivePalette.festCream,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          boxShadow: FestivePalette.panelShadow,
          border: Border.all(color: FestivePalette.goldLight, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
          child: Row(
            children: <Widget>[
              const LivelyPose(image: WheelArt.poseCheer, height: 76),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Hasil Sabtu ini',
                      style: base.copyWith(
                        color: FestivePalette.candyBottom,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: base.copyWith(
                        color: FestivePalette.festDeep,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$body Dibuka lagi ${opening.dayLabel}.',
                      style: base.copyWith(
                        color: FestivePalette.festDeep.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Image(
                image: WheelArt.forReward(record.kind, record.kelopak),
                width: 52,
                height: 52,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
