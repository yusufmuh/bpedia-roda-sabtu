import 'dart:math' as math;
import 'package:flutter/material.dart';

bool saturdayOpen(int day, {required int first, required int endExclusive}) =>
    day >= first && day < endExclusive &&
    DateTime.fromMillisecondsSinceEpoch(day * Duration.millisecondsPerDay, isUtc: true).weekday == DateTime.saturday;

/// Only for the example campaign. Production draws are committed by the rewards service.
bool demoProduct({required int remaining, required int roll}) {
  if (roll < 0 || roll >= 100) throw RangeError.range(roll, 0, 99, 'roll');
  return remaining > 0 && roll < 10;
}

class SaturdayWheel extends StatelessWidget {
  const SaturdayWheel({super.key, required this.available, required this.remaining,
    required this.spun, required this.lastResult, required this.onSpin, required this.previewDate});
  final bool available, spun;
  final int remaining;
  final String lastResult, previewDate;
  final VoidCallback? onSpin;

  @override
  Widget build(BuildContext context) {
    final chance = remaining > 0 ? 10 : 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.arrow_drop_down, size: 30, color: Color(0xff4b1c2e)),
        TweenAnimationBuilder<double>(tween: Tween(end: spun ? (lastResult.contains('produk') ? 3.05 : 3.55) : 0),
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 1050),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Transform.rotate(angle: t*2*math.pi, child: child),
          child: CustomPaint(size: const Size.square(134), painter: _WheelDial(chance))),
      ])),
      const SizedBox(height: 16),
      Text('Peluang dan ongkir', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('Produk gratis  ·  $chance%  ·  $remaining unit tersisa\n3 Kelopak  ·  ${100-chance}%'),
      const SizedBox(height: 8),
      Text('Ongkir simulasi Rp0. Satu putaran gratis per Sabtu WIB selama promo. Tanggal simulasi $previewDate.'),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: available && !spun ? onSpin : null,
        icon: const Icon(Icons.rotate_right),
        label: Text(spun ? 'Putaran sudah digunakan' : available ? 'Putar gratis' : 'Kembali pada Sabtu')),
      if (lastResult.isNotEmpty) Padding(padding: const EdgeInsets.only(top:12),
        child: Semantics(liveRegion:true, child: Text('Hasil terakhir · $lastResult'))),
    ]);
  }
}

class _WheelDial extends CustomPainter {
  const _WheelDial(this.chance);
  final int chance;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center:center, radius:radius);
    final p = Paint()..color = const Color(0xfff7a6bd);
    canvas.drawCircle(center,radius,p);
    if (chance > 0) {
      p.color=const Color(0xffa9194f);
      canvas.drawArc(rect, -math.pi/2 - 2*math.pi*chance/100, 2*math.pi*chance/100,true,p);
    }
    p..color=const Color(0xff4b1c2e)..style=PaintingStyle.stroke..strokeWidth=2;
    canvas.drawCircle(center,radius,p);
    p..style=PaintingStyle.fill..color=const Color(0xfffff7f8);
    canvas.drawCircle(center,14,p);
    for (var i=0;i<16;i++) {
      final a=i*math.pi/8;
      canvas.drawCircle(center+Offset(math.cos(a),math.sin(a))*(radius-7),2,p);
    }
  }
  @override
  bool shouldRepaint(_WheelDial oldDelegate) => oldDelegate.chance != chance;
}
