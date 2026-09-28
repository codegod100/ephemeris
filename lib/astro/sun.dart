import 'astro_math.dart';

/// Apparent geocentric position of the Sun (Meeus ch. 25, low precision,
/// accurate to ~0.01°).
Equatorial sunEquatorial(DateTime t) {
  final tc = centuriesTT(t);
  final omega = 125.04 - 1934.136 * tc;
  final eps = meanObliquity(tc) + 0.00256 * cosD(omega);
  final (:lon, :r) = sunApparentEcliptic(t);
  return eclipticToEquatorial(lon, 0, eps, r);
}

/// Apparent ecliptic longitude of the Sun (true equinox of date, with
/// aberration) in degrees, and distance in AU.
({double lon, double r}) sunApparentEcliptic(DateTime t) {
  final tc = centuriesTT(t);
  final l0 = normDeg(280.46646 + 36000.76983 * tc + 0.0003032 * tc * tc);
  final m = normDeg(357.52911 + 35999.05029 * tc - 0.0001537 * tc * tc);
  final e = 0.016708634 - 0.000042037 * tc - 0.0000001267 * tc * tc;
  final c = (1.914602 - 0.004817 * tc - 0.000014 * tc * tc) * sinD(m) +
      (0.019993 - 0.000101 * tc) * sinD(2 * m) +
      0.000289 * sinD(3 * m);
  final trueLon = l0 + c;
  final v = m + c;
  final r = 1.000001018 * (1 - e * e) / (1 + e * cosD(v));
  final omega = 125.04 - 1934.136 * tc;
  final appLon = trueLon - 0.00569 - 0.00478 * sinD(omega);
  return (lon: normDeg(appLon), r: r);
}

/// Geocentric ecliptic longitude of the Sun (degrees) and distance (AU),
/// referred to the mean equinox of date. Used by the planet module.
({double lon, double r}) sunEcliptic(DateTime t) {
  final tc = centuriesTT(t);
  final l0 = normDeg(280.46646 + 36000.76983 * tc);
  final m = normDeg(357.52911 + 35999.05029 * tc);
  final e = 0.016708634 - 0.000042037 * tc;
  final c = (1.914602 - 0.004817 * tc) * sinD(m) + 0.019993 * sinD(2 * m) + 0.000289 * sinD(3 * m);
  final v = m + c;
  return (lon: normDeg(l0 + c), r: 1.000001018 * (1 - e * e) / (1 + e * cosD(v)));
}

Horizontal sunHorizontal(DateTime t, double lat, double lon, {bool refraction = true}) =>
    equatorialToHorizontal(sunEquatorial(t), t, lat, lon, refraction: refraction);
