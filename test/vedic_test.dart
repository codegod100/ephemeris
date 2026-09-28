import 'package:flutter_test/flutter_test.dart';
import 'package:helios_sky/astro/astro_math.dart';
import 'package:helios_sky/astro/vedic.dart';

GrahaPosition _pos(DateTime t, Graha g) => grahaPositions(t).firstWhere((p) => p.graha == g);

void main() {
  test('Lahiri ayanamsa ≈ 23°51′ at J2000 and grows ~50″ a year', () {
    expect(lahiriAyanamsa(0), closeTo(23.857, 0.003));
    final perYear = lahiriAyanamsa(0.01) - lahiriAyanamsa(0);
    expect(perYear * 3600, closeTo(50.29, 0.05));
  });

  test('Makar Sankranti 2024: Sun enters sidereal Makara (270°)', () {
    // Published Sankranti moment: 15 Jan 2024 02:54 IST = 14 Jan 21:24 UTC.
    final sun = _pos(DateTime.utc(2024, 1, 14, 21, 24), Graha.surya);
    expect(sun.sidereal.lon, closeTo(270, 0.05));
    expect(sun.retrograde, isFalse);
  });

  test('Rahu moves from Meena into Kumbha in mid-May 2025', () {
    expect(_pos(DateTime.utc(2025, 5, 8), Graha.rahu).sidereal.rashi.name, 'Meena');
    expect(_pos(DateTime.utc(2025, 5, 28), Graha.rahu).sidereal.rashi.name, 'Kumbha');
  });

  test('Rahu and Ketu are opposite and always retrograde', () {
    final t = DateTime.utc(2026, 9, 28);
    final rahu = _pos(t, Graha.rahu), ketu = _pos(t, Graha.ketu);
    expect(normDeg(ketu.sidereal.lon - rahu.sidereal.lon), closeTo(180, 1e-9));
    expect(rahu.retrograde && ketu.retrograde, isTrue);
  });

  test('rashi, nakshatra and pada boundaries', () {
    const a = SiderealPosition(0.1);
    expect((a.rashi.name, a.nakshatra, a.pada, a.nakshatraLord), ('Mesha', 'Ashwini', 1, Graha.ketu));
    const b = SiderealPosition(13.34);
    expect((b.nakshatra, b.pada, b.nakshatraLord), ('Bharani', 1, Graha.shukra));
    const c = SiderealPosition(200.01); // Swati ends at 200°
    expect((c.rashi.name, c.nakshatra, c.pada, c.nakshatraLord), ('Tula', 'Vishakha', 1, Graha.guru));
    const d = SiderealPosition(359.9);
    expect((d.rashi.name, d.nakshatra, d.pada, d.nakshatraLord), ('Meena', 'Revati', 4, Graha.budha));
    expect(d.degInRashi, closeTo(29.9, 1e-9));
  });

  test('ecliptic ↔ equatorial round trip', () {
    for (final (lon, lat) in [(10.0, 0.0), (123.4, 4.5), (300.0, -6.0)]) {
      final eq = eclipticToEquatorial(lon, lat, 23.44);
      final back = equatorialToEcliptic(eq, 23.44);
      expect(back.lon, closeTo(lon, 1e-9));
      expect(back.lat, closeTo(lat, 1e-9));
    }
  });
}
