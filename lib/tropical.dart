import 'dart:math' as math;
import 'package:flutter/material.dart';

class BananaIcon extends StatelessWidget {
  const BananaIcon({super.key, this.size = 120});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: BananaPainter()),
      );
}

class BananaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 120);
    final banana = Path()
      ..moveTo(19, 29)
      ..cubicTo(18, 66, 51, 91, 89, 55)
      ..quadraticBezierTo(103, 40, 103, 24)
      ..lineTo(110, 27)
      ..cubicTo(116, 72, 82, 107, 48, 98)
      ..cubicTo(22, 92, 9, 66, 13, 32)
      ..close();
    canvas.drawShadow(banana, const Color(0xFF795419), 5, false);
    canvas.drawPath(
      banana,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF391), Color(0xFFFFD83D), Color(0xFFF2A91D)],
        ).createShader(const Rect.fromLTWH(10, 20, 105, 85)),
    );
    canvas.drawPath(
      banana,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFFB77C1E),
    );
    canvas.drawPath(
      Path()
        ..moveTo(24, 51)
        ..cubicTo(31, 96, 83, 101, 104, 47),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = const Color(0xFFFFF6B5),
    );
    canvas.drawPath(
      Path()
        ..moveTo(103, 27)
        ..lineTo(103, 15)
        ..lineTo(110, 13)
        ..lineTo(112, 27)
        ..close(),
      Paint()..color = const Color(0xFF63853C),
    );
    canvas.drawLine(
      const Offset(12, 31), const Offset(19, 28),
      Paint()
        ..color = const Color(0xFF73512D)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BananaPainter oldDelegate) => false;
}

class TropicalBackground extends CustomPainter {
  TropicalBackground(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFBDEEEA), Color(0xFFEAF9DA), Color(0xFFFFF2CB)],
          stops: [0, .65, 1],
        ).createShader(Offset.zero & size),
    );
    final sun = Offset(w * .83, h * .16);
    canvas.drawCircle(sun, 90, Paint()..color = const Color(0x22FFFFFF));
    canvas.drawCircle(sun, 65, Paint()..color = const Color(0x33FFFFFF));
    canvas.drawCircle(sun, 44, Paint()..color = const Color(0xFFFFDF79));
    for (var layer = 0; layer < 3; layer++) {
      final top = h * .69 + layer * 28;
      final wave = Path()..moveTo(0, top);
      for (double x = 0; x <= w + 12; x += 12) {
        final y = top + math.sin(x / 90 + phase * math.pi * 2 + layer) * 12;
        wave.lineTo(x, y);
      }
      wave..lineTo(w, h)..lineTo(0, h)..close();
      canvas.drawPath(wave, Paint()..color = [
        const Color(0xFF8DDDD1),
        const Color(0xFF61C8BF),
        const Color(0xFF39ADA9),
      ][layer]);
    }
    final beach = Path()
      ..moveTo(0, h * .93)
      ..quadraticBezierTo(w * .3, h * .84, w * .62, h * .94)
      ..quadraticBezierTo(w * .85, h, w, h * .90)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(beach, Paint()..color = const Color(0xFFFFE5A6));
    palm(canvas, Offset(w < 600 ? -8 : 28, h * .92), w < 600 ? 105 : 170, false);
    palm(canvas, Offset(w - 5, h * .90), w < 600 ? 120 : 200, true);
  }

  void palm(Canvas canvas, Offset base, double height, bool mirror) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(mirror ? -1 : 1, 1);
    final sway = math.sin(phase * math.pi * 2) * 4;
    final crown = Offset(height * .24 + sway, -height);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(height * .05, -height * .6, crown.dx, crown.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = height * .065
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFA27B43),
    );
    for (var i = 0; i < 7; i++) {
      final angle = -math.pi + i * math.pi / 6;
      final end = crown + Offset(math.cos(angle) * height * .54,
          math.sin(angle) * height * .25 + height * .18);
      final leaf = Path()
        ..moveTo(crown.dx, crown.dy)
        ..quadraticBezierTo(
            (crown.dx + end.dx) / 2, crown.dy - height * .28, end.dx, end.dy)
        ..quadraticBezierTo(
            (crown.dx + end.dx) / 2, crown.dy + height * .05, crown.dx, crown.dy)
        ..close();
      canvas.drawPath(leaf, Paint()..color = i.isEven
          ? const Color(0xFF328668) : const Color(0xFF4A9E65));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(TropicalBackground oldDelegate) => oldDelegate.phase != phase;
}

class TropicalAura extends CustomPainter {
  TropicalAura(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * .43;
    canvas.drawCircle(center, radius, Paint()
      ..color = const Color(0x44FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    for (var i = 0; i < 9; i++) {
      final angle = i * math.pi * 2 / 9 + phase * math.pi * 2;
      final point = center + Offset(math.cos(angle), math.sin(angle)) *
          (radius + math.sin(angle * 3) * 7);
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle);
      if (i % 3 == 0) {
        canvas.drawOval(const Rect.fromLTWH(-5, -10, 10, 20),
            Paint()..color = const Color(0xFF67A567));
      } else {
        final star = Path()
          ..moveTo(0, -7)..lineTo(2, -2)..lineTo(7, 0)
          ..lineTo(2, 2)..lineTo(0, 7)..lineTo(-2, 2)
          ..lineTo(-7, 0)..lineTo(-2, -2)..close();
        canvas.drawPath(star, Paint()..color = const Color(0xFFE0A429));
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(TropicalAura oldDelegate) => oldDelegate.phase != phase;
}
