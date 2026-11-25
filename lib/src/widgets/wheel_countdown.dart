import 'dart:async';

import 'package:flutter/material.dart';

import '../kit/festive_palette.dart';
import '../wheel_opening.dart';

/// Kotak hitung mundur ke pembukaan roda (Sabtu 00.00 WIB) untuk hero
/// pesta: ubin hari, jam, menit, detik yang diperbarui tiap detik, dan
/// sakelar "Ingatkan saya" bila host mendukung pengingat.
///
/// Waktu hanya dibaca dari [now], jadi geseran jam Mode Demo ikut terpakai.
class WheelCountdown extends StatefulWidget {
  /// Membuat hitung mundur ke hari WIB [saturday].
  const WheelCountdown({
    super.key,
    required this.saturday,
    required this.now,
    this.showReminder = false,
    this.reminderOn = false,
    this.onReminderChanged,
  });

  /// Hari WIB pembukaan (Sabtu).
  final int saturday;

  /// Jam host.
  final DateTime Function() now;

  /// Menampilkan sakelar pengingat (hanya Android/iOS).
  final bool showReminder;

  /// Pengingat menyala.
  final bool reminderOn;

  /// Dipanggil saat sakelar pengingat diubah.
  final ValueChanged<bool>? onReminderChanged;

  @override
  State<WheelCountdown> createState() => _WheelCountdownState();
}

class _WheelCountdownState extends State<WheelCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WheelOpening opening = wheelOpening(
      saturday: widget.saturday,
      now: widget.now(),
    );
    final Duration left = opening.timeLeft;
    final TextStyle base =
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle());
    final List<(int, String)> units = <(int, String)>[
      (left.inDays, 'Hari'),
      (left.inHours % 24, 'Jam'),
      (left.inMinutes % 60, 'Menit'),
      (left.inSeconds % 60, 'Detik'),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FestivePalette.festDeep.withValues(alpha: 0.42),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              container: true,
              label:
                  'Dibuka ${opening.opensAtLabel}, ${opening.remainingLabel}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Dibuka ${opening.opensAtLabel}',
                    textAlign: TextAlign.center,
                    style: base.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < units.length; i++) ...<Widget>[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              ':',
                              style: base.copyWith(
                                color: FestivePalette.goldLight,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        Expanded(
                          child: _Tile(
                            value: units[i].$1,
                            label: units[i].$2,
                            base: base,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (widget.showReminder) ...<Widget>[
              const SizedBox(height: 8),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.2)),
              MergeSemantics(
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: FestivePalette.goldLight,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Ingatkan saya',
                            style: base.copyWith(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Notifikasi tiap Sabtu 09.00 WIB',
                            style: base.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: widget.reminderOn,
                      onChanged: widget.onReminderChanged,
                      activeThumbColor: Colors.white,
                      activeTrackColor: FestivePalette.gold,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                      trackOutlineColor: WidgetStateProperty.all(
                        Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label, required this.base});

  final int value;
  final String label;
  final TextStyle base;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Colors.white, FestivePalette.festBlush],
            ),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: FestivePalette.festDeep.withValues(alpha: 0.5),
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value.toString().padLeft(2, '0'),
                  style: base.copyWith(
                    color: FestivePalette.festDeep,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: base.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
