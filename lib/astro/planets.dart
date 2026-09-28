import 'dart:math' as math;

import 'astro_math.dart';

/// Keplerian elements for approximate planet positions, valid 1800–2050
/// (E. M. Standish, JPL, "Keplerian Elements for Approximate Positions of the
/// Major Planets", table 1). Referred to the J2000 ecliptic and equinox.
///
/// Each row: a (AU), e, I (deg), L (deg), long. perihelion ϖ (deg), Ω (deg),
/// followed by their rates per Julian century.
class _Elements {
  final List<double> v;
  final List<double> rate;
  const _Elements(this.v, this.rate);
}

enum Planet { mercury, venus, mars, jupiter, saturn, uranus, neptune }

extension PlanetInfo on Planet {
  String get label => switch (this) {
        Planet.mercury => 'Mercury',
        Planet.venus => 'Venus',
        Planet.mars => 'Mars',
        Planet.jupiter => 'Jupiter',
        Planet.saturn => 'Saturn',
        Planet.uranus => 'Uranus',
        Planet.neptune => 'Neptune',
      };

  /// Rough typical visual magnitude, for drawing size only.
  double get typicalMag => switch (this) {
        Planet.mercury => 0.0,
        Planet.venus => -4.2,
        Planet.mars => 0.5,
        Planet.jupiter => -2.3,
        Planet.saturn => 0.6,
        Planet.uranus => 5.7,
        Planet.neptune => 7.8,
      };

  int get argb => switch (this) {
        Planet.mercury => 0xFFB8B0A8,
        Planet.venus => 0xFFFFF4D6,
        Planet.mars => 0xFFFF7A4D,
        Planet.jupiter => 0xFFF2D7A6,
        Planet.saturn => 0xFFE8D08C,
        Planet.uranus => 0xFF9FE3E8,
        Planet.neptune => 0xFF6F8CFF,
      };
}

const _earth = _Elements(
  [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0],
  [0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0],
);

const Map<Planet, _Elements> _table = {
  Planet.mercury: _Elements(
    [0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593],
    [0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081],
  ),
  Planet.venus: _Elements(
    [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255],
    [0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418],
  ),
  Planet.mars: _Elements(
    [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891],
    [0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343],
  ),
  Planet.jupiter: _Elements(
    [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909],
    [-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106],
  ),
  Planet.saturn: _Elements(
    [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448],
    [-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794],
  ),
  Planet.uranus: _Elements(
    [19.18916464, 0.04725744, 0.77263783, 313.23810451, 170.95427630, 74.01692503],
    [-0.00196176, -0.00004397, -0.00242939, 428.48202785, 0.40805281, 0.04240589],
  ),
  Planet.neptune: _Elements(
    [30.06992276, 0.00859048, 1.77004347, -55.12002969, 44.96476227, 131.78422574],
    [0.00026291, 0.00005105, 0.00035372, 218.45945325, -0.32241464, -0.00508664],
  ),
};

/// Heliocentric ecliptic rectangular coordinates (J2000), AU.
List<double> _helio(_Elements el, double tc) {
  final a = el.v[0] + el.rate[0] * tc;
  final e = el.v[1] + el.rate[1] * tc;
  final inc = el.v[2] + el.rate[2] * tc;
  final l = el.v[3] + el.rate[3] * tc;
  final peri = el.v[4] + el.rate[4] * tc;
  final node = el.v[5] + el.rate[5] * tc;
  final w = peri - node;
  var mAnom = normDeg(l - peri);
  if (mAnom > 180) mAnom -= 360;

  // Solve Kepler's equation (degrees form).
  final eStar = e * rad2deg;
  var ecc = mAnom + eStar * sinD(mAnom);
  for (var i = 0; i < 12; i++) {
    final dM = mAnom - (ecc - eStar * sinD(ecc));
    final dE = dM / (1 - e * cosD(ecc));
    ecc += dE;
    if (dE.abs() < 1e-8) break;
  }
  final xp = a * (cosD(ecc) - e);
  final yp = a * math.sqrt(1 - e * e) * sinD(ecc);

  final cw = cosD(w), sw = sinD(w), cn = cosD(node), sn = sinD(node), ci = cosD(inc), si = sinD(inc);
  return [
    (cw * cn - sw * sn * ci) * xp + (-sw * cn - cw * sn * ci) * yp,
    (cw * sn + sw * cn * ci) * xp + (-sw * sn + cw * cn * ci) * yp,
    (sw * si) * xp + (cw * si) * yp,
  ];
}

/// Apparent-ish geocentric equatorial position (J2000 frame precessed to date).
/// Accuracy is a few arcminutes — ample for a sky map.
Equatorial planetEquatorial(Planet p, DateTime t) {
  final tc = centuriesTT(t);
  final ph = _helio(_table[p]!, tc);
  final eh = _helio(_earth, tc);
  final x = ph[0] - eh[0], y = ph[1] - eh[1], z = ph[2] - eh[2];
  const eps = 23.43928; // J2000 obliquity
  final xe = x;
  final ye = y * cosD(eps) - z * sinD(eps);
  final ze = y * sinD(eps) + z * cosD(eps);
  final dist = math.sqrt(xe * xe + ye * ye + ze * ze);
  final j2000 = Equatorial(normDeg(atan2D(ye, xe)), asinD(ze / dist), dist);
  return precessFromJ2000(j2000, tc);
}

Horizontal planetHorizontal(Planet p, DateTime t, double lat, double lon) =>
    equatorialToHorizontal(planetEquatorial(p, t), t, lat, lon);
