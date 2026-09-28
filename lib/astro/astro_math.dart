import 'dart:math' as math;

/// Shared math helpers and time conversions for the ephemeris.
const double deg2rad = math.pi / 180.0;
const double rad2deg = 180.0 / math.pi;

double normDeg(double d) {
  final r = d % 360.0;
  return r < 0 ? r + 360.0 : r;
}

double sinD(double d) => math.sin(d * deg2rad);
double cosD(double d) => math.cos(d * deg2rad);
double tanD(double d) => math.tan(d * deg2rad);
double asinD(double x) => math.asin(x.clamp(-1.0, 1.0)) * rad2deg;
double acosD(double x) => math.acos(x.clamp(-1.0, 1.0)) * rad2deg;
double atan2D(double y, double x) => math.atan2(y, x) * rad2deg;

/// Julian Day (UT) for a [DateTime]. Local times are converted to UTC.
double julianDay(DateTime t) {
  final u = t.toUtc();
  return u.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
}

/// Approximate ΔT = TT − UT in seconds (Espenak & Meeus polynomials,
/// good enough for 1900–2100).
double deltaTSeconds(double year) {
  if (year >= 2005 && year < 2050) {
    final t = year - 2000;
    return 62.92 + 0.32217 * t + 0.005589 * t * t;
  }
  if (year >= 2050 && year < 2150) {
    return -20 + 32 * math.pow((year - 1820) / 100, 2) - 0.5628 * (2150 - year);
  }
  if (year >= 1986 && year < 2005) {
    final t = year - 2000;
    return 63.86 +
        0.3345 * t -
        0.060374 * t * t +
        0.0017275 * t * t * t +
        0.000651814 * t * t * t * t +
        0.00002373599 * t * t * t * t * t;
  }
  if (year >= 1961 && year < 1986) {
    final t = year - 1975;
    return 45.45 + 1.067 * t - t * t / 260 - t * t * t / 718;
  }
  final u = (year - 1820) / 100;
  return -20 + 32 * u * u;
}

/// Julian Day in Terrestrial Time.
double julianDayTT(DateTime t) {
  final jd = julianDay(t);
  final year = 2000 + (jd - 2451545.0) / 365.25;
  return jd + deltaTSeconds(year) / 86400.0;
}

/// Julian centuries since J2000.0 (TT).
double centuriesTT(DateTime t) => (julianDayTT(t) - 2451545.0) / 36525.0;

/// Greenwich Mean Sidereal Time in degrees (Meeus 12.4).
double gmstDeg(DateTime t) {
  final jd = julianDay(t);
  final tc = (jd - 2451545.0) / 36525.0;
  return normDeg(280.46061837 +
      360.98564736629 * (jd - 2451545.0) +
      0.000387933 * tc * tc -
      tc * tc * tc / 38710000.0);
}

/// Mean obliquity of the ecliptic in degrees.
double meanObliquity(double tc) =>
    23.439291111 - 0.0130041667 * tc - 1.64e-7 * tc * tc + 5.036e-7 * tc * tc * tc;

/// Nutation in longitude and obliquity (degrees), low-precision (Meeus ch. 22).
({double dPsi, double dEps}) nutation(double tc) {
  final omega = normDeg(125.04452 - 1934.136261 * tc);
  final l = normDeg(280.4665 + 36000.7698 * tc);
  final lp = normDeg(218.3165 + 481267.8813 * tc);
  final dPsi = (-17.20 * sinD(omega) -
          1.32 * sinD(2 * l) -
          0.23 * sinD(2 * lp) +
          0.21 * sinD(2 * omega)) /
      3600.0;
  final dEps = (9.20 * cosD(omega) +
          0.57 * cosD(2 * l) +
          0.10 * cosD(2 * lp) -
          0.09 * cosD(2 * omega)) /
      3600.0;
  return (dPsi: dPsi, dEps: dEps);
}

/// Equatorial coordinates, degrees.
class Equatorial {
  final double ra; // right ascension, degrees 0..360
  final double dec; // declination, degrees
  final double? distanceAu;
  const Equatorial(this.ra, this.dec, [this.distanceAu]);
}

/// Horizontal coordinates, degrees. Azimuth measured from North through East.
class Horizontal {
  final double az;
  final double alt;
  const Horizontal(this.az, this.alt);

  /// Unit vector in the local East-North-Up frame.
  List<double> toEnu() {
    final ca = cosD(alt);
    return [ca * sinD(az), ca * cosD(az), sinD(alt)];
  }

  @override
  String toString() => 'Az ${az.toStringAsFixed(2)}°, Alt ${alt.toStringAsFixed(2)}°';
}

/// Ecliptic (lon, lat) → equatorial, all degrees.
Equatorial eclipticToEquatorial(double lon, double lat, double eps, [double? dist]) {
  final ra = atan2D(sinD(lon) * cosD(eps) - tanD(lat) * sinD(eps), cosD(lon));
  final dec = asinD(sinD(lat) * cosD(eps) + cosD(lat) * sinD(eps) * sinD(lon));
  return Equatorial(normDeg(ra), dec, dist);
}

/// Equatorial → horizontal for an observer.
Horizontal equatorialToHorizontal(
  Equatorial eq,
  DateTime t,
  double latDeg,
  double lonDeg, {
  bool refraction = true,
}) {
  final lst = normDeg(gmstDeg(t) + lonDeg);
  final h = normDeg(lst - eq.ra);
  final alt = asinD(sinD(latDeg) * sinD(eq.dec) + cosD(latDeg) * cosD(eq.dec) * cosD(h));
  final az = normDeg(atan2D(
        sinD(h),
        cosD(h) * sinD(latDeg) - tanD(eq.dec) * cosD(latDeg),
      ) +
      180.0);
  return Horizontal(az, refraction ? alt + refractionDeg(alt) : alt);
}

/// Atmospheric refraction (Sæmundsson), degrees, for a true altitude.
double refractionDeg(double altDeg) {
  if (altDeg < -1.9) return 0;
  final r = 1.02 / tanD(altDeg + 10.3 / (altDeg + 5.11)); // arcminutes
  return r / 60.0;
}

/// Precess J2000 equatorial coordinates to the epoch of date (Meeus 21.2/21.4).
Equatorial precessFromJ2000(Equatorial eq, double tc) {
  final zeta = (2306.2181 * tc + 0.30188 * tc * tc + 0.017998 * tc * tc * tc) / 3600.0;
  final z = (2306.2181 * tc + 1.09468 * tc * tc + 0.018203 * tc * tc * tc) / 3600.0;
  final theta = (2004.3109 * tc - 0.42665 * tc * tc - 0.041833 * tc * tc * tc) / 3600.0;
  final a = cosD(eq.dec) * sinD(eq.ra + zeta);
  final b = cosD(theta) * cosD(eq.dec) * cosD(eq.ra + zeta) - sinD(theta) * sinD(eq.dec);
  final c = sinD(theta) * cosD(eq.dec) * cosD(eq.ra + zeta) + cosD(theta) * sinD(eq.dec);
  return Equatorial(normDeg(atan2D(a, b) + z), asinD(c), eq.distanceAu);
}

/// Parse "HH MM SS.s" into degrees.
double hmsToDeg(num h, num m, num s) => (h + m / 60 + s / 3600) * 15.0;

/// Parse signed "DD MM SS" into degrees. Pass sign separately so −00° works.
double dmsToDeg(int sign, num d, num m, num s) => sign * (d + m / 60 + s / 3600);
