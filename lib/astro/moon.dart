import 'dart:math' as math;

import 'astro_math.dart';
import 'sun.dart';

// Principal periodic terms from Meeus, Astronomical Algorithms, tables 47.A/B.
// [D, M, M', F, Σl coeff (1e-6°), Σr coeff (1e-3 km)]
const List<List<int>> _lrTerms = [
  [0, 0, 1, 0, 6288774, -20905355],
  [2, 0, -1, 0, 1274027, -3699111],
  [2, 0, 0, 0, 658314, -2955968],
  [0, 0, 2, 0, 213618, -569925],
  [0, 1, 0, 0, -185116, 48888],
  [0, 0, 0, 2, -114332, -3149],
  [2, 0, -2, 0, 58793, 246158],
  [2, -1, -1, 0, 57066, -152138],
  [2, 0, 1, 0, 53322, -170733],
  [2, -1, 0, 0, 45758, -204586],
  [0, 1, -1, 0, -40923, -129620],
  [1, 0, 0, 0, -34720, 108743],
  [0, 1, 1, 0, -30383, 104755],
  [2, 0, 0, -2, 15327, 10321],
  [0, 0, 1, 2, -12528, 0],
  [0, 0, 1, -2, 10980, 79661],
  [4, 0, -1, 0, 10675, -34782],
  [0, 0, 3, 0, 10034, -23210],
  [4, 0, -2, 0, 8548, -21636],
  [2, 1, -1, 0, -7888, 24208],
  [2, 1, 0, 0, -6766, 30824],
  [1, 0, -1, 0, -5163, -8379],
  [1, 1, 0, 0, 4987, -16675],
  [2, -1, 1, 0, 4036, -12831],
  [2, 0, 2, 0, 3994, -10445],
  [4, 0, 0, 0, 3861, -11650],
  [2, 0, -3, 0, 3665, 14403],
  [0, 1, -2, 0, -2689, -7003],
  [2, 0, -1, 2, -2602, 0],
  [2, -1, -2, 0, 2390, 10056],
  [1, 0, 1, 0, -2348, 6322],
  [2, -2, 0, 0, 2236, -9884],
];

// [D, M, M', F, Σb coeff (1e-6°)]
const List<List<int>> _bTerms = [
  [0, 0, 0, 1, 5128122],
  [0, 0, 1, 1, 280602],
  [0, 0, 1, -1, 277693],
  [2, 0, 0, -1, 173237],
  [2, 0, -1, 1, 55413],
  [2, 0, -1, -1, 46271],
  [2, 0, 0, 1, 32573],
  [0, 0, 2, 1, 17198],
  [2, 0, 1, -1, 9266],
  [0, 0, 2, -1, 8822],
  [2, -1, 0, -1, 8216],
  [2, 0, -2, -1, 4324],
  [2, 0, 1, 1, 4200],
  [2, 1, 0, -1, -3359],
  [2, -1, -1, 1, 2463],
  [2, -1, 0, 1, 2211],
  [2, -1, -1, -1, 2065],
  [0, 1, -1, -1, -1870],
  [4, 0, -1, -1, 1828],
  [0, 1, 0, 1, -1794],
];

class MoonPosition {
  final double lon; // apparent ecliptic longitude, deg
  final double lat; // ecliptic latitude, deg
  final double distanceKm;
  final Equatorial equatorial;
  const MoonPosition(this.lon, this.lat, this.distanceKm, this.equatorial);
}

/// Apparent geocentric Moon position (Meeus ch. 47, truncated series,
/// ~10″ in longitude, ~4″ in latitude for the main terms kept here).
MoonPosition moonPosition(DateTime t) {
  final tc = centuriesTT(t);
  final t2 = tc * tc, t3 = t2 * tc, t4 = t3 * tc;
  final lp = normDeg(218.3164477 + 481267.88123421 * tc - 0.0015786 * t2 + t3 / 538841 - t4 / 65194000);
  final d = normDeg(297.8501921 + 445267.1114034 * tc - 0.0018819 * t2 + t3 / 545868 - t4 / 113065000);
  final m = normDeg(357.5291092 + 35999.0502909 * tc - 0.0001536 * t2 + t3 / 24490000);
  final mp = normDeg(134.9633964 + 477198.8675055 * tc + 0.0087414 * t2 + t3 / 69699 - t4 / 14712000);
  final f = normDeg(93.2720950 + 483202.0175233 * tc - 0.0036539 * t2 - t3 / 3526000 + t4 / 863310000);
  final a1 = normDeg(119.75 + 131.849 * tc);
  final a2 = normDeg(53.09 + 479264.290 * tc);
  final a3 = normDeg(313.45 + 481266.484 * tc);
  final e = 1 - 0.002516 * tc - 0.0000074 * t2;

  double sl = 0, sr = 0, sb = 0;
  for (final term in _lrTerms) {
    final arg = term[0] * d + term[1] * m + term[2] * mp + term[3] * f;
    final ef = math.pow(e, term[1].abs()).toDouble();
    sl += term[4] * ef * sinD(arg);
    sr += term[5] * ef * cosD(arg);
  }
  for (final term in _bTerms) {
    final arg = term[0] * d + term[1] * m + term[2] * mp + term[3] * f;
    final ef = math.pow(e, term[1].abs()).toDouble();
    sb += term[4] * ef * sinD(arg);
  }
  sl += 3958 * sinD(a1) + 1962 * sinD(lp - f) + 318 * sinD(a2);
  sb += -2235 * sinD(lp) +
      382 * sinD(a3) +
      175 * sinD(a1 - f) +
      175 * sinD(a1 + f) +
      127 * sinD(lp - mp) -
      115 * sinD(lp + mp);

  final nut = nutation(tc);
  final lon = normDeg(lp + sl / 1e6 + nut.dPsi);
  final lat = sb / 1e6;
  final dist = 385000.56 + sr / 1000.0;
  final eps = meanObliquity(tc) + nut.dEps;
  return MoonPosition(lon, lat, dist, eclipticToEquatorial(lon, lat, eps, dist / 149597870.7));
}

/// Topocentric horizontal position of the Moon (includes parallax, which is
/// up to ~1° for the Moon).
Horizontal moonHorizontal(DateTime t, double lat, double lon, {bool refraction = true}) {
  final mp = moonPosition(t);
  final geo = equatorialToHorizontal(mp.equatorial, t, lat, lon, refraction: false);
  final parallax = asinD(6378.14 / mp.distanceKm);
  final topoAlt = geo.alt - parallax * cosD(geo.alt);
  return Horizontal(geo.az, refraction ? topoAlt + refractionDeg(topoAlt) : topoAlt);
}

/// Illuminated fraction of the Moon's disk (0..1) and whether it is waxing.
({double fraction, bool waxing, double ageDegrees}) moonPhase(DateTime t) {
  final moon = moonPosition(t).equatorial;
  final sun = sunEquatorial(t);
  final cosPsi = sinD(sun.dec) * sinD(moon.dec) + cosD(sun.dec) * cosD(moon.dec) * cosD(sun.ra - moon.ra);
  final psi = acosD(cosPsi); // elongation
  final fraction = (1 - cosD(psi)) / 2; // phase angle ≈ 180° − elongation
  final age = normDeg(moonPosition(t).lon - sunEcliptic(t).lon);
  return (fraction: fraction, waxing: age < 180, ageDegrees: age);
}

String moonPhaseName(double ageDeg) {
  if (ageDeg < 11.25 || ageDeg >= 348.75) return 'New Moon';
  if (ageDeg < 78.75) return 'Waxing Crescent';
  if (ageDeg < 101.25) return 'First Quarter';
  if (ageDeg < 168.75) return 'Waxing Gibbous';
  if (ageDeg < 191.25) return 'Full Moon';
  if (ageDeg < 258.75) return 'Waning Gibbous';
  if (ageDeg < 281.25) return 'Last Quarter';
  return 'Waning Crescent';
}

/// '○' at the new Moon, '●' at the full Moon, otherwise empty.
String moonPhaseSymbol(double ageDeg) {
  final name = moonPhaseName(ageDeg);
  if (name == 'New Moon') return '○';
  if (name == 'Full Moon') return '●';
  return '';
}
