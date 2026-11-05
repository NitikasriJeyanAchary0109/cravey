import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How much of the landscape to draw.
enum SunsetStyle {
  /// Sky, sun, clouds, mountains, hills and pines: the entry screens.
  full,

  /// Only the rolling hills and pines along the bottom, quietly, behind content.
  hills,
}

/// An illustrated sunset landscape drawn in code (no image files): a warm orange sky with a low sun, rust-red clouds, snow-capped mountains and green hills
/// with pines. The look follows the Meatopia site's hero: flat, warm, a little retro.
class SunsetBackdrop extends StatelessWidget {
  final SunsetStyle style;

  /// Where the ground starts, as a fraction of the height from the top (full style only).
  final double horizon;

  /// Opacity of the hills in the [SunsetStyle.hills] style.
  final double opacity;

  const SunsetBackdrop({super.key, this.style = SunsetStyle.full, this.horizon = 0.62, this.opacity = 0.35});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: style == SunsetStyle.full ? _SunsetPainter(horizon) : _HillsPainter(opacity),
        child: const SizedBox.expand(),
      ),
    );
  }
}

const _skyTop = Color(0xFFD9532F);
const _skyMid = Color(0xFFEE7E3B);
const _skyLow = Color(0xFFF9B65A);
const _skyGlow = Color(0xFFFFE6A8);
const _cloud = Color(0xFFC84B2B);
const _mountainBack = Color(0xFF7D8C84);
const _mountainFront = Color(0xFF5C6B64);
const _snow = Color(0xFFF4EEE4);
const _hillBack = Color(0xFF8DB84A);
const _hillFront = Color(0xFF5F9442);
const _pine = Color(0xFF2F5D3A);

class _SunsetPainter extends CustomPainter {
  final double horizon;
  const _SunsetPainter(this.horizon);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final groundY = h * horizon;

    // sky: deep orange at the top, glowing towards the horizon
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_skyTop, _skyMid, _skyLow, _skyGlow],
          stops: [0.0, 0.4, 0.75, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, groundY)),
    );

    // sun with a soft halo, sitting just above the mountains
    final sun = Offset(w * 0.5, groundY - h * 0.1);
    canvas.drawCircle(
      sun,
      w * 0.34,
      Paint()
        ..shader = RadialGradient(colors: [_skyGlow.withValues(alpha: 0.85), _skyGlow.withValues(alpha: 0.0)]).createShader(Rect.fromCircle(center: sun, radius: w * 0.34)),
    );
    canvas.drawCircle(sun, w * 0.075, Paint()..color = const Color(0xFFFFF6D4));

    // flat rust-red clouds, built from overlapping circles
    final cloud = Paint()..color = _cloud.withValues(alpha: 0.92);
    _cloudAt(canvas, cloud, Offset(w * 0.14, groundY - h * 0.2), w * 0.065);
    _cloudAt(canvas, cloud, Offset(w * 0.86, groundY - h * 0.27), w * 0.08);
    _cloudAt(canvas, cloud, Offset(w * 0.7, groundY - h * 0.14), w * 0.04);
    _cloudAt(canvas, cloud, Offset(w * 0.3, groundY - h * 0.3), w * 0.035);

    // mountains: a pale back range with snow, a darker front range
    _range(canvas, w, groundY, [0.0, 0.18, 0.34, 0.5, 0.68, 0.84, 1.0], [0.12, 0.22, 0.1, 0.27, 0.12, 0.2, 0.1], _mountainBack, snow: true);
    _range(canvas, w, groundY + h * 0.02, [0.0, 0.25, 0.45, 0.62, 0.8, 1.0], [0.07, 0.13, 0.06, 0.12, 0.07, 0.1], _mountainFront);

    // ground: two rolling green hills with pines along them
    _hill(canvas, w, h, groundY + h * 0.03, 0.05, _hillBack, 0.0);
    _hill(canvas, w, h, groundY + h * 0.09, 0.06, _hillFront, 1.7);
    _drawPines(canvas, w, groundY + h * 0.035, h);
  }

  void _cloudAt(Canvas canvas, Paint paint, Offset c, double r) {
    canvas.drawCircle(c, r, paint);
    canvas.drawCircle(c + Offset(r * 1.1, r * 0.2), r * 0.8, paint);
    canvas.drawCircle(c + Offset(-r * 1.0, r * 0.3), r * 0.7, paint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(0, r * 0.55), width: r * 3.4, height: r * 0.9), Radius.circular(r * 0.45)), paint);
  }

  void _range(Canvas canvas, double w, double baseY, List<double> xs, List<double> rises, Color color, {bool snow = false}) {
    final h = baseY / horizon;
    final path = Path()..moveTo(0, baseY + h * 0.1);
    final peaks = <Offset>[];
    for (var i = 0; i < xs.length; i++) {
      final p = Offset(w * xs[i], baseY - h * rises[i]);
      peaks.add(p);
      path.lineTo(p.dx, p.dy);
    }
    path
      ..lineTo(w, baseY + h * 0.1)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    if (snow) {
      final cap = Paint()..color = _snow;
      for (var i = 1; i < peaks.length - 1; i++) {
        final p = peaks[i];
        if (rises[i] < 0.15) continue;
        final d = h * 0.035;
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy)
            ..lineTo(p.dx - d * 1.1, p.dy + d)
            ..lineTo(p.dx - d * 0.3, p.dy + d * 0.7)
            ..lineTo(p.dx + d * 0.1, p.dy + d * 1.2)
            ..lineTo(p.dx + d * 0.6, p.dy + d * 0.8)
            ..lineTo(p.dx + d * 1.2, p.dy + d)
            ..close(),
          cap,
        );
      }
    }
  }

  void _hill(Canvas canvas, double w, double h, double y, double amp, Color color, double phase) {
    final path = Path()..moveTo(0, h);
    path.lineTo(0, y);
    const steps = 24;
    for (var i = 0; i <= steps; i++) {
      final x = w * i / steps;
      final yy = y - h * amp * (0.5 + 0.5 * math.sin(i / steps * 2 * math.pi * 1.2 + phase));
      path.lineTo(x, yy);
    }
    path
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SunsetPainter old) => old.horizon != horizon;
}

void _drawPines(Canvas canvas, double w, double y, double h) {
  final paint = Paint()..color = _pine;
  final size = h * 0.028;
  var x = w * 0.03;
  var i = 0;
  while (x < w) {
    final jitter = (i * 37 % 11) / 11.0;
    final s = size * (0.7 + 0.6 * jitter);
    final base = y + h * 0.01 + ((i * 13) % 7) * h * 0.002;
    canvas.drawPath(
      Path()
        ..moveTo(x, base - s * 2.2)
        ..lineTo(x - s * 0.55, base - s * 0.9)
        ..lineTo(x - s * 0.3, base - s * 0.9)
        ..lineTo(x - s * 0.75, base)
        ..lineTo(x + s * 0.75, base)
        ..lineTo(x + s * 0.3, base - s * 0.9)
        ..lineTo(x + s * 0.55, base - s * 0.9)
        ..close(),
      paint,
    );
    x += w * (0.045 + 0.05 * jitter);
    i++;
  }
}

class _HillsPainter extends CustomPainter {
  final double opacity;
  const _HillsPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final layer in [
      (y: h * 0.86, amp: 0.045, color: _hillBack, phase: 0.0),
      (y: h * 0.92, amp: 0.05, color: _hillFront, phase: 1.7),
    ]) {
      final path = Path()..moveTo(0, h)..lineTo(0, layer.y);
      const steps = 24;
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        path.lineTo(w * t, layer.y - h * layer.amp * (0.5 + 0.5 * math.sin(t * 7.5 + layer.phase)));
      }
      path..lineTo(w, h)..close();
      canvas.drawPath(path, Paint()..color = layer.color.withValues(alpha: opacity));
    }
    _drawPines(canvas, w, h * 0.885, h);
  }

  @override
  bool shouldRepaint(covariant _HillsPainter old) => old.opacity != opacity;
}
