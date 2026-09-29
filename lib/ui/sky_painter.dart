import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../astro/astro_math.dart';
import '../astro/moon.dart';
import '../astro/stars.dart';
import '../astro/vedic.dart';
import '../sensors/orientation_service.dart';
import '../state/sky_model.dart';

/// Projection centred on the camera's forward direction.
///
/// By default it is stereographic, which maps circles on the sky to circles on
/// screen (like Stellarium's default). With [rectilinear] it is gnomonic, the
/// projection of a real camera lens, so the overlay lines up with a camera
/// image in AR mode.
class SkyProjection {
  final CameraBasis cam;
  final Size size;
  final double fovDeg;
  final bool rectilinear;
  late final double focal;
  late final Offset center;

  SkyProjection(this.cam, this.size, this.fovDeg, {this.rectilinear = false}) {
    center = Offset(size.width / 2, size.height / 2);
    focal = rectilinear ? (size.width / 2) / tanD(fovDeg / 2) : (size.width / 2) / (2 * tanD(fovDeg / 4));
  }

  /// Camera-space components of an ENU unit vector.
  (double x, double y, double z) camSpace(List<double> v) =>
      (dot(v, cam.right), dot(v, cam.up), dot(v, cam.forward));

  /// Projects an ENU unit vector. Returns null when too far behind the camera.
  Offset? project(List<double> v, {double minZ = -0.6}) {
    final (x, y, z) = camSpace(v);
    if (z < (rectilinear ? math.max(minZ, 0.05) : minZ)) return null;
    final k = rectilinear ? 1 / z : 2 / (1 + z);
    return Offset(center.dx + focal * k * x, center.dy - focal * k * y);
  }

  bool onScreen(Offset p, [double margin = 0]) =>
      p.dx >= -margin && p.dy >= -margin && p.dx <= size.width + margin && p.dy <= size.height + margin;

  /// Pixels per degree at the centre of the view.
  double get pxPerDeg => (rectilinear ? focal : 2 * focal) * deg2rad;
}

class SkyPainter extends CustomPainter {
  final SkySnapshot sky;
  final CameraBasis cam;
  final double fov;
  final bool showStars, showConstellations, showPlanets, showGrid, showSunPath, showLabels, showAtmosphere;
  final bool showEcliptic, showVedic;
  final String? selected;

  /// Draw over a live camera image: rectilinear projection, no painted sky or
  /// ground, just the horizon line.
  final bool ar;

  SkyPainter({
    required this.sky,
    required this.cam,
    required this.fov,
    required this.showStars,
    required this.showConstellations,
    required this.showPlanets,
    required this.showGrid,
    this.showEcliptic = false,
    this.showVedic = false,
    required this.showSunPath,
    required this.showLabels,
    required this.showAtmosphere,
    this.selected,
    this.ar = false,
  });

  late SkyProjection _proj;

  @override
  void paint(Canvas canvas, Size size) {
    _proj = SkyProjection(cam, size, fov, rectilinear: ar);
    final sunAlt = sky.sun.pos.alt;

    if (!ar) _paintSkyBackground(canvas, size, sunAlt);
    if (showGrid) _paintGrid(canvas);
    if (showEcliptic) _paintEclipticAndEquator(canvas);
    if (showVedic) _paintZodiac(canvas);

    // Stars fade out as the sky brightens (only when atmosphere is on).
    final starAlpha = showAtmosphere ? ((-sunAlt - 2) / 10).clamp(0.0, 1.0) : 1.0;
    if (showConstellations && starAlpha > 0) _paintConstellations(canvas, starAlpha);
    if (showStars && starAlpha > 0) _paintStars(canvas, starAlpha);
    if (showSunPath) _paintSunPath(canvas);
    if (showPlanets) _paintPlanets(canvas, showAtmosphere ? ((-sunAlt + 4) / 8).clamp(0.25, 1.0) : 1.0);
    if (showVedic) _paintNodes(canvas);
    _paintMoon(canvas);
    _paintSun(canvas);
    if (ar) {
      _paintHorizonLine(canvas);
    } else {
      _paintGround(canvas, size, sunAlt);
    }
    _paintCardinals(canvas);
    _paintSelection(canvas);
    _paintOffscreenArrow(canvas, size, sky.sun.enu, '☀', const Color(0xFFFFC04D), const Color(0xFFFFE082));
    _paintOffscreenArrow(canvas, size, sky.moon.enu, '☾', const Color(0xFFB0BEC5), const Color(0xFFE0E0E0));
  }

  // ---- background ----------------------------------------------------------
  Color _skyColor(double sunAlt) {
    if (!showAtmosphere) return const Color(0xFF02030A);
    const night = Color(0xFF02030A);
    const astro = Color(0xFF0A1030);
    const civil = Color(0xFF2B3F7A);
    const day = Color(0xFF3F7FD0);
    if (sunAlt <= -18) return night;
    if (sunAlt <= -6) return Color.lerp(astro, civil, (sunAlt + 18) / 12)!;
    if (sunAlt <= 4) return Color.lerp(civil, day, (sunAlt + 6) / 10)!;
    return day;
  }

  void _paintSkyBackground(Canvas canvas, Size size, double sunAlt) {
    final top = _skyColor(sunAlt);
    final horizonGlow = Color.lerp(top, const Color(0xFFFFB074), sunAlt > -12 && sunAlt < 8 ? 0.35 : 0.08)!;
    // Vertical gradient from zenith colour to a warmer horizon colour, oriented
    // along the projected up-direction.
    final zen = _proj.project([0, 0, 1], minZ: -0.95);
    final hor = _proj.project(Horizontal(cam.azimuth, 0).toEnu(), minZ: -0.95);
    final paint = Paint();
    if (zen != null && hor != null && (zen - hor).distance > 1) {
      paint.shader = ui.Gradient.linear(hor, zen, [horizonGlow, top]);
    } else {
      paint.color = top;
    }
    canvas.drawRect(Offset.zero & size, paint);
  }

  // ---- ground ---------------------------------------------------------------
  /// The horizon is a great circle, so under a stereographic projection it
  /// is an exact circle (or a straight line when it passes through the
  /// projection's antipode). We fit it from three points and fill the side
  /// containing the nadir.
  void _paintGround(Canvas canvas, Size size, double sunAlt) {
    final az = cam.azimuth;
    final pts = [
      _proj.project(Horizontal(az, 0).toEnu(), minZ: -0.99),
      _proj.project(Horizontal(az + 90, 0).toEnu(), minZ: -0.99),
      _proj.project(Horizontal(az - 90, 0).toEnu(), minZ: -0.99),
    ];
    if (pts.any((p) => p == null)) return;
    final a = pts[0]!, b = pts[1]!, c = pts[2]!;

    final light = showAtmosphere ? ((sunAlt + 10) / 20).clamp(0.0, 1.0) : 0.0;
    final groundColor = Color.lerp(const Color(0xFF0B0F0A), const Color(0xFF2E3B24), light)!.withValues(alpha: 0.93);
    final fill = Paint()..color = groundColor;
    final edge = Paint()
      ..color = const Color(0xFF7FA36B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final nadirZ = -cam.forward[2]; // z of the nadir in camera space
    final nadir = nadirZ > -0.999 ? _proj.project([0, 0, -1], minZ: -0.999) : null;

    final circle = _circleThrough(a, b, c);
    if (circle != null && circle.$2 < 200000) {
      final (center, r) = circle;
      final nadirInside = nadir != null && (nadir - center).distance < r;
      final circlePath = Path()..addOval(Rect.fromCircle(center: center, radius: r));
      if (nadirInside) {
        canvas.drawPath(circlePath, fill);
      } else {
        final outside = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect((Offset.zero & size).inflate(10))
          ..addPath(circlePath, Offset.zero);
        canvas.drawPath(outside, fill);
      }
      canvas.drawPath(circlePath, edge);
    } else {
      // Straight-line horizon through b and c; fill the half-plane with the nadir.
      final dir = c - b;
      final len = dir.distance;
      if (len < 1e-6) return;
      final d = dir / len;
      final n = Offset(-d.dy, d.dx);
      final ref = nadir ?? (_proj.center + const Offset(0, 1e4));
      final side = ((ref - b).dx * n.dx + (ref - b).dy * n.dy).sign;
      const big = 1e5;
      final path = Path()
        ..moveTo(b.dx - d.dx * big, b.dy - d.dy * big)
        ..lineTo(b.dx + d.dx * big, b.dy + d.dy * big)
        ..lineTo(b.dx + d.dx * big + n.dx * side * big, b.dy + d.dy * big + n.dy * side * big)
        ..lineTo(b.dx - d.dx * big + n.dx * side * big, b.dy - d.dy * big + n.dy * side * big)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawLine(b - d * big, b + d * big, edge);
    }
  }

  void _paintHorizonLine(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF9FD38A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    _polyline(canvas, [for (var az = 0; az <= 360; az += 2) Horizontal(az.toDouble(), 0).toEnu()], paint);
  }

  (Offset, double)? _circleThrough(Offset a, Offset b, Offset c) {
    final d = 2 * (a.dx * (b.dy - c.dy) + b.dx * (c.dy - a.dy) + c.dx * (a.dy - b.dy));
    if (d.abs() < 1e-6) return null;
    final a2 = a.dx * a.dx + a.dy * a.dy;
    final b2 = b.dx * b.dx + b.dy * b.dy;
    final c2 = c.dx * c.dx + c.dy * c.dy;
    final ux = (a2 * (b.dy - c.dy) + b2 * (c.dy - a.dy) + c2 * (a.dy - b.dy)) / d;
    final uy = (a2 * (c.dx - b.dx) + b2 * (a.dx - c.dx) + c2 * (b.dx - a.dx)) / d;
    final center = Offset(ux, uy);
    return (center, (a - center).distance);
  }

  // ---- grid -----------------------------------------------------------------
  void _polyline(Canvas canvas, Iterable<List<double>> pts, Paint paint) {
    final path = Path();
    Offset? prev;
    for (final v in pts) {
      final p = _proj.project(v, minZ: -0.3);
      if (p == null) {
        prev = null;
        continue;
      }
      if (prev == null || (p - prev).distance > _proj.size.longestSide) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      prev = p;
    }
    canvas.drawPath(path, paint);
  }

  void _paintGrid(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0x3380B0FF)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (var alt = 15; alt < 90; alt += 15) {
      _polyline(canvas, [for (var az = 0; az <= 360; az += 3) Horizontal(az.toDouble(), alt.toDouble()).toEnu()], paint);
    }
    for (var az = 0; az < 360; az += 15) {
      _polyline(canvas, [for (var alt = 0; alt <= 90; alt += 3) Horizontal(az.toDouble(), alt.toDouble()).toEnu()], paint);
    }
    if (showLabels) {
      for (var alt = 15; alt < 90; alt += 15) {
        final p = _proj.project(Horizontal(cam.azimuth, alt.toDouble()).toEnu());
        if (p != null && _proj.onScreen(p)) _label(canvas, p + const Offset(4, -14), '$alt°', const Color(0x9980B0FF), 10);
      }
    }
  }

  // ---- ecliptic, equator & sidereal zodiac ---------------------------------
  void _paintEclipticAndEquator(Canvas canvas) {
    final z = sky.zodiac;
    _polyline(canvas, z.equator, Paint()
      ..color = const Color(0x8866D9EF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke);
    _polyline(canvas, z.ecliptic, Paint()
      ..color = const Color(0xAAFFB74D)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke);
    if (showLabels) {
      final eq = _pickOnScreen(z.equator);
      if (eq != null) _label(canvas, eq + const Offset(4, 2), 'celestial equator', const Color(0xAA66D9EF), 10);
      final ec = _pickOnScreen(z.ecliptic);
      if (ec != null) _label(canvas, ec + const Offset(4, -14), 'ecliptic', const Color(0xCCFFB74D), 10);
    }
    final dot = Paint()..color = const Color(0xFF66D9EF);
    for (final (name, v) in z.seasonPoints) {
      final p = _proj.project(v);
      if (p == null || !_proj.onScreen(p, 10)) continue;
      canvas.drawCircle(p, 4, dot);
      if (showLabels) _label(canvas, p + const Offset(6, 4), name, const Color(0xFF9EE7F7), 11, bold: true);
    }
  }

  /// A point of a polyline near the middle of the screen, for its label.
  Offset? _pickOnScreen(List<List<double>> pts) {
    Offset? best;
    var bestD = double.infinity;
    for (final v in pts) {
      final p = _proj.project(v);
      if (p == null || !_proj.onScreen(p, -30)) continue;
      final d = (p - _proj.center).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return best;
  }

  void _paintZodiac(Canvas canvas) {
    final z = sky.zodiac;
    void ticks(List<(List<double>, List<double>)> segs, Paint paint) {
      for (final (a, b) in segs) {
        final p1 = _proj.project(a), p2 = _proj.project(b);
        if (p1 == null || p2 == null) continue;
        if (!_proj.onScreen(p1, 50) && !_proj.onScreen(p2, 50)) continue;
        canvas.drawLine(p1, p2, paint);
      }
    }

    ticks(z.nakshatraTicks, Paint()
      ..color = const Color(0x8880CBC4)
      ..strokeWidth = 1);
    ticks(z.rashiTicks, Paint()
      ..color = const Color(0xCCFFB74D)
      ..strokeWidth = 1.6);
    if (!showLabels) return;
    void labels(List<(String, List<double>)> ls, Color color, double size, {bool bold = false}) {
      for (final (name, v) in ls) {
        final p = _proj.project(v);
        if (p == null || !_proj.onScreen(p, 20)) continue;
        _label(canvas, p - Offset(name.length * size * 0.28, size * 0.6), name, color, size, bold: bold);
      }
    }

    labels(z.rashiLabels, const Color(0xFFFFCC80), 13, bold: true);
    // Mark the Moon's nakshatra with ○ / ● at new / full Moon.
    final sym = moonPhaseSymbol(sky.moonAge);
    final moonNak = sym.isEmpty
        ? null
        : sky.grahas.where((g) => g.graha == Graha.chandra).firstOrNull?.sidereal.nakshatra;
    labels([for (final (n, v) in z.nakshatraLabels) (n == moonNak ? '$n $sym' : n, v)], const Color(0xCC80CBC4), 10);
  }

  void _paintNodes(Canvas canvas) {
    for (final n in sky.nodes) {
      final p = _proj.project(n.enu);
      if (p == null || !_proj.onScreen(p, 10)) continue;
      final paint = Paint()
        ..color = n.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawCircle(p, 6, paint);
      canvas.drawLine(p + const Offset(-4, 0), p + const Offset(4, 0), paint);
      if (showLabels) _label(canvas, p + const Offset(9, -7), n.name, n.color, 12, bold: true);
    }
  }

  // ---- stars & constellations ----------------------------------------------
  double _starRadius(double mag) => math.max(0.8, (4.6 - mag) * 0.85) * (fov < 40 ? 1.3 : 1.0);

  void _paintStars(Canvas canvas, double alpha) {
    final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final core = Paint();
    for (final s in sky.stars) {
      final p = _proj.project(s.enu);
      if (p == null || !_proj.onScreen(p, 10)) continue;
      final r = _starRadius(s.mag);
      final a = alpha * (s.pos.alt < 0 ? 0.35 : 1.0);
      glow.color = Colors.white.withValues(alpha: 0.35 * a);
      canvas.drawCircle(p, r * 1.8, glow);
      core.color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(p, r, core);
      if (showLabels && (s.mag < 1.6 || fov < 45)) {
        _label(canvas, p + Offset(r + 3, -6), s.name, Colors.white.withValues(alpha: 0.7 * a), 11);
      }
    }
  }

  void _paintConstellations(Canvas canvas, double alpha) {
    final paint = Paint()
      ..color = const Color(0xFF5C8DFF).withValues(alpha: 0.45 * alpha)
      ..strokeWidth = 1;
    for (final pair in constellationLines) {
      final s1 = sky.starsByName[pair[0]], s2 = sky.starsByName[pair[1]];
      if (s1 == null || s2 == null) continue;
      final p1 = _proj.project(s1.enu, minZ: -0.2), p2 = _proj.project(s2.enu, minZ: -0.2);
      if (p1 == null || p2 == null) continue;
      if (!_proj.onScreen(p1, 400) && !_proj.onScreen(p2, 400)) continue;
      final gap = (p2 - p1);
      final len = gap.distance;
      if (len < 12) continue;
      final u = gap / len;
      canvas.drawLine(p1 + u * 5, p2 - u * 5, paint);
    }
  }

  // ---- solar system -----------------------------------------------------------
  void _paintSunPath(Canvas canvas) {
    final above = Paint()
      ..color = const Color(0xCCFFC04D)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final below = Paint()
      ..color = const Color(0x55FFC04D)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final path = sky.sunPath;
    for (var i = 0; i + 1 < path.length; i++) {
      final p1 = _proj.project(path[i].enu, minZ: -0.3);
      final p2 = _proj.project(path[i + 1].enu, minZ: -0.3);
      if (p1 == null || p2 == null) continue;
      if ((p2 - p1).distance > _proj.size.longestSide) continue;
      final up = path[i].pos.alt >= 0 || path[i + 1].pos.alt >= 0;
      if (!up && i.isOdd) continue; // dashed below the horizon
      canvas.drawLine(p1, p2, up ? above : below);
    }
    final dot = Paint()..color = const Color(0xFFFFC04D);
    for (final pt in path) {
      if (pt.time.minute != 0 || pt.pos.alt < -5) continue;
      final p = _proj.project(pt.enu);
      if (p == null || !_proj.onScreen(p)) continue;
      canvas.drawCircle(p, 3, dot);
      if (showLabels) _label(canvas, p + const Offset(5, 2), '${pt.time.hour}h', const Color(0xDDFFC04D), 10);
    }
  }

  void _paintPlanets(Canvas canvas, double alpha) {
    for (final pl in sky.planets) {
      final p = _proj.project(pl.enu);
      if (p == null || !_proj.onScreen(p, 10)) continue;
      final r = math.max(2.0, (3.5 - pl.mag) * 0.9);
      canvas.drawCircle(p, r * 2.2, Paint()
        ..color = pl.color.withValues(alpha: 0.25 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(p, r, Paint()..color = pl.color.withValues(alpha: alpha));
      if (showLabels) _label(canvas, p + Offset(r + 4, -6), pl.name, pl.color.withValues(alpha: alpha), 12);
    }
  }

  void _paintSun(Canvas canvas) {
    final p = _proj.project(sky.sun.enu);
    if (p == null || !_proj.onScreen(p, 60)) return;
    final r = math.max(9.0, 0.267 * _proj.pxPerDeg);
    canvas.drawCircle(p, r * 3.5, Paint()
      ..shader = ui.Gradient.radial(p, r * 3.5, [const Color(0x88FFE082), const Color(0x00FFE082)]));
    canvas.drawCircle(p, r, Paint()..color = const Color(0xFFFFF3C4));
    if (showLabels) _label(canvas, p + Offset(r + 4, -8), 'Sun', const Color(0xFFFFE082), 13, bold: true);
  }

  void _paintMoon(Canvas canvas) {
    final p = _proj.project(sky.moon.enu);
    if (p == null || !_proj.onScreen(p, 40)) return;
    final r = math.max(8.0, 0.259 * _proj.pxPerDeg);
    // Bright limb faces the Sun: find the sun's direction on screen.
    final (sx, sy, _) = _proj.camSpace(sky.sun.enu);
    final (mx, my, _) = _proj.camSpace(sky.moon.enu);
    final angle = math.atan2(-(sy - my), sx - mx);

    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF2A2D33));
    final f = sky.moonFraction;
    final w = r * (2 * f - 1).abs();
    final s = f > 0.5 ? -1.0 : 1.0;
    final lit = Path()..moveTo(0, -r);
    lit.arcTo(Rect.fromCircle(center: Offset.zero, radius: r), -math.pi / 2, math.pi, false);
    for (var i = 0; i <= 32; i++) {
      final t = math.pi / 2 - math.pi * i / 32;
      lit.lineTo(s * w * math.cos(t), r * math.sin(t));
    }
    lit.close();
    canvas.drawPath(lit, Paint()..color = const Color(0xFFF1F3E8));
    canvas.restore();
    if (showLabels) _label(canvas, p + Offset(r + 4, -8), 'Moon', const Color(0xFFE0E0E0), 12);
  }

  // ---- overlays ---------------------------------------------------------------
  void _paintCardinals(Canvas canvas) {
    const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    for (var i = 0; i < 8; i++) {
      final p = _proj.project(Horizontal(i * 45.0, 0).toEnu());
      if (p == null || !_proj.onScreen(p, 20)) continue;
      final major = i.isEven;
      _label(canvas, p + const Offset(-6, 4), names[i],
          i == 0 ? const Color(0xFFFF6B6B) : const Color(0xFFB8E0A0), major ? 18 : 13,
          bold: major);
    }
  }

  void _paintSelection(Canvas canvas) {
    if (selected == null) return;
    final obj = sky.allObjects.where((o) => o.name == selected).firstOrNull;
    if (obj == null) return;
    final p = _proj.project(obj.enu);
    if (p == null || !_proj.onScreen(p)) return;
    final paint = Paint()
      ..color = const Color(0xFF7CFFB2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const r = 16.0, g = 6.0;
    for (var k = 0; k < 4; k++) {
      final a = k * math.pi / 2 + math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(p + d * r, p + d * (r + g), paint);
    }
    canvas.drawCircle(p, r, paint..color = const Color(0x667CFFB2));
  }

  /// When a body is out of view, draw an edge arrow pointing the way to it.
  void _paintOffscreenArrow(Canvas canvas, Size size, List<double> enu, String glyph, Color arrowColor, Color textColor) {
    final p = _proj.project(enu, minZ: -0.99);
    if (p != null && _proj.onScreen(p, -20)) return;
    final (x, y, z) = _proj.camSpace(enu);
    final dir = Offset(x, -y);
    if (dir.distance < 1e-9) return;
    final d = dir / dir.distance;
    final c = _proj.center;
    final pad = 42.0;
    final tx = d.dx.abs() < 1e-9 ? double.infinity : (size.width / 2 - pad) / d.dx.abs();
    final ty = d.dy.abs() < 1e-9 ? double.infinity : (size.height / 2 - pad - 90) / d.dy.abs();
    final tip = c + d * math.min(tx, ty);
    final angle = math.atan2(d.dy, d.dx);
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(angle);
    final arrow = Path()
      ..moveTo(18, 0)
      ..lineTo(-8, -12)
      ..lineTo(-3, 0)
      ..lineTo(-8, 12)
      ..close();
    canvas.drawPath(arrow, Paint()..color = arrowColor);
    canvas.restore();
    final sep = acosD(z);
    _label(canvas, tip - d * 34 + const Offset(-22, -8), '$glyph ${sep.toStringAsFixed(0)}°', textColor, 13,
        bold: true);
  }

  void _label(Canvas canvas, Offset at, String text, Color color, double size, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant SkyPainter old) => true;
}
