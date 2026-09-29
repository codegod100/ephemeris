import 'astro_math.dart';
import 'moon.dart';
import 'planets.dart';
import 'sun.dart';

/// The nine grahas (Navagraha) of Jyotisha.
enum Graha { surya, chandra, mangala, budha, guru, shukra, shani, rahu, ketu }

extension GrahaInfo on Graha {
  String get sanskrit => switch (this) {
        Graha.surya => 'Surya',
        Graha.chandra => 'Chandra',
        Graha.mangala => 'Mangala',
        Graha.budha => 'Budha',
        Graha.guru => 'Guru',
        Graha.shukra => 'Shukra',
        Graha.shani => 'Shani',
        Graha.rahu => 'Rahu',
        Graha.ketu => 'Ketu',
      };

  String get english => switch (this) {
        Graha.surya => 'Sun',
        Graha.chandra => 'Moon',
        Graha.mangala => 'Mars',
        Graha.budha => 'Mercury',
        Graha.guru => 'Jupiter',
        Graha.shukra => 'Venus',
        Graha.shani => 'Saturn',
        Graha.rahu => 'North node',
        Graha.ketu => 'South node',
      };
}

class Rashi {
  final String name, english;
  final Graha lord;
  const Rashi(this.name, this.english, this.lord);
}

const rashis = [
  Rashi('Mesha', 'Aries', Graha.mangala),
  Rashi('Vrishabha', 'Taurus', Graha.shukra),
  Rashi('Mithuna', 'Gemini', Graha.budha),
  Rashi('Karka', 'Cancer', Graha.chandra),
  Rashi('Simha', 'Leo', Graha.surya),
  Rashi('Kanya', 'Virgo', Graha.budha),
  Rashi('Tula', 'Libra', Graha.shukra),
  Rashi('Vrishchika', 'Scorpio', Graha.mangala),
  Rashi('Dhanu', 'Sagittarius', Graha.guru),
  Rashi('Makara', 'Capricorn', Graha.shani),
  Rashi('Kumbha', 'Aquarius', Graha.shani),
  Rashi('Meena', 'Pisces', Graha.guru),
];

const nakshatras = [
  'Ashwini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra', 'Punarvasu', 'Pushya', 'Ashlesha', //
  'Magha', 'Purva Phalguni', 'Uttara Phalguni', 'Hasta', 'Chitra', 'Swati', 'Vishakha', 'Anuradha', 'Jyeshtha',
  'Mula', 'Purva Ashadha', 'Uttara Ashadha', 'Shravana', 'Dhanishta', 'Shatabhisha', 'Purva Bhadrapada',
  'Uttara Bhadrapada', 'Revati',
];

/// Vimshottari lord of each nakshatra: the cycle Ketu, Venus, Sun, Moon,
/// Mars, Rahu, Jupiter, Saturn, Mercury, repeated three times.
Graha lordOfNakshatra(int index) => const [
      Graha.ketu, Graha.shukra, Graha.surya, Graha.chandra, Graha.mangala, //
      Graha.rahu, Graha.guru, Graha.shani, Graha.budha,
    ][index % 9];

const double nakshatraSpan = 360 / 27; // 13°20′

/// Lahiri (Chitrapaksha) ayanamsa in degrees, mean equinox of date.
///
/// Anchored to the Indian Calendar Reform Committee value at 1956-03-21 0h TT
/// (as reduced by the Swiss Ephemeris) and carried by the IAU 2006 general
/// precession in longitude.
double lahiriAyanamsa(double tc) {
  double pA(double t) => (5028.796195 * t + 1.1054348 * t * t + 0.00007964 * t * t * t) / 3600;
  const t0 = (2435553.5 - 2451545.0) / 36525;
  return 23.245524743 + pA(tc) - pA(t0);
}

/// Longitude of the Moon's mean ascending node (Rahu), mean equinox of date
/// (Meeus 47.7).
double meanLunarNode(double tc) => normDeg(
    125.0445479 - 1934.1362891 * tc + 0.0020754 * tc * tc + tc * tc * tc / 467441 - tc * tc * tc * tc / 60616000);

/// A sidereal longitude broken down into rashi and nakshatra.
class SiderealPosition {
  final double lon; // 0..360
  const SiderealPosition(this.lon);

  int get rashiIndex => (lon ~/ 30) % 12;
  Rashi get rashi => rashis[rashiIndex];
  double get degInRashi => lon - rashiIndex * 30;
  int get nakshatraIndex => (lon ~/ nakshatraSpan) % 27;
  String get nakshatra => nakshatras[nakshatraIndex];
  Graha get nakshatraLord => lordOfNakshatra(nakshatraIndex);

  /// Quarter of the nakshatra, 1..4 (3°20′ each).
  int get pada => ((lon - nakshatraIndex * nakshatraSpan) ~/ (nakshatraSpan / 4)) + 1;
}

class GrahaPosition {
  final Graha graha;
  final SiderealPosition sidereal;
  final bool retrograde;
  const GrahaPosition(this.graha, this.sidereal, this.retrograde);
}

/// Tropical ecliptic longitudes of the nine grahas, mean equinox of date.
Map<Graha, double> _tropicalLongitudes(DateTime t) {
  final tc = centuriesTT(t);
  final dPsi = nutation(tc).dPsi;
  final eps = meanObliquity(tc);
  double planet(Planet p) => equatorialToEcliptic(planetEquatorial(p, t), eps).lon;
  final rahu = meanLunarNode(tc);
  return {
    // Sun and Moon come as apparent longitudes (true equinox); drop nutation.
    Graha.surya: normDeg(sunApparentEcliptic(t).lon - dPsi),
    Graha.chandra: normDeg(moonPosition(t).lon - dPsi),
    Graha.mangala: planet(Planet.mars),
    Graha.budha: planet(Planet.mercury),
    Graha.guru: planet(Planet.jupiter),
    Graha.shukra: planet(Planet.venus),
    Graha.shani: planet(Planet.saturn),
    Graha.rahu: rahu,
    Graha.ketu: normDeg(rahu + 180),
  };
}

/// Sidereal (Lahiri) positions of the nine grahas, with retrograde flags.
List<GrahaPosition> grahaPositions(DateTime t) {
  final ayan = lahiriAyanamsa(centuriesTT(t));
  final now = _tropicalLongitudes(t);
  final later = _tropicalLongitudes(t.add(const Duration(hours: 6)));
  return [
    for (final g in Graha.values)
      GrahaPosition(
        g,
        SiderealPosition(normDeg(now[g]! - ayan)),
        // Longitude decreasing over the next 6 h (wrapped to ±180°).
        ((later[g]! - now[g]! + 540) % 360) - 180 < 0,
      ),
  ];
}

/// Tropical ecliptic longitude (mean equinox of date) of a sidereal longitude.
double siderealToTropical(double siderealLon, double tc) => normDeg(siderealLon + lahiriAyanamsa(tc));

/// Sidereal (Lahiri) longitude of the Moon at [t], degrees 0..360.
double _moonSiderealLon(DateTime t) {
  final tc = centuriesTT(t);
  return normDeg(moonPosition(t).lon - nutation(tc).dPsi - lahiriAyanamsa(tc));
}

/// Index (0..26) of the sidereal nakshatra the Moon occupies at [t].
int moonNakshatraIndexAt(DateTime t) => SiderealPosition(_moonSiderealLon(t)).nakshatraIndex;

/// The next instant at or after [t] when the Moon enters sidereal nakshatra
/// [index] (within about 27.3 days).
DateTime moonEntersNakshatra(DateTime t, int index) {
  const degPerDay = 13.176; // mean lunar motion
  final target = index * nakshatraSpan;
  var cur = t;
  var diff = normDeg(target - _moonSiderealLon(cur));
  for (var i = 0; i < 8; i++) {
    cur = cur.add(Duration(milliseconds: (diff / degPerDay * 86400000).round()));
    // Signed residual in -180..180; negative means we overshot.
    diff = normDeg(target - _moonSiderealLon(cur) + 180) - 180;
    if (diff.abs() < 0.005) break;
  }
  return cur;
}

/// The instant nearest [t] (within half a year) when the Sun enters sidereal
/// nakshatra [index], i.e. reaches sidereal longitude index × 13°20′.
DateTime sunEntersNakshatra(DateTime t, int index) {
  double sunSidereal(DateTime x) {
    final tc = centuriesTT(x);
    return normDeg(sunApparentEcliptic(x).lon - nutation(tc).dPsi - lahiriAyanamsa(tc));
  }

  const degPerDay = 0.9856; // mean solar motion
  final target = index * nakshatraSpan;
  var cur = t;
  for (var i = 0; i < 5; i++) {
    final diff = normDeg(target - sunSidereal(cur) + 180) - 180;
    if (diff.abs() < 0.001) break;
    cur = cur.add(Duration(milliseconds: (diff / degPerDay * 86400000).round()));
  }
  return cur;
}
