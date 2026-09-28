import 'moon.dart';
import 'sun.dart';

/// Daily solar events for an observer, as local [DateTime]s. Any field may be
/// null (e.g. polar day/night).
class SunEvents {
  final DateTime? astronomicalDawn;
  final DateTime? nauticalDawn;
  final DateTime? civilDawn;
  final DateTime? sunrise;
  final DateTime? goldenHourMorningEnd;
  final DateTime solarNoon;
  final double noonAltitude;
  final DateTime? goldenHourEveningStart;
  final DateTime? sunset;
  final DateTime? civilDusk;
  final DateTime? nauticalDusk;
  final DateTime? astronomicalDusk;

  const SunEvents({
    this.astronomicalDawn,
    this.nauticalDawn,
    this.civilDawn,
    this.sunrise,
    this.goldenHourMorningEnd,
    required this.solarNoon,
    required this.noonAltitude,
    this.goldenHourEveningStart,
    this.sunset,
    this.civilDusk,
    this.nauticalDusk,
    this.astronomicalDusk,
  });

  Duration? get dayLength =>
      (sunrise != null && sunset != null) ? sunset!.difference(sunrise!) : null;
}

typedef AltitudeFn = double Function(DateTime t);

/// Finds times in [start, end) where [f] crosses [threshold].
/// Returns (rising, setting) crossings in chronological order.
({List<DateTime> rising, List<DateTime> setting}) findCrossings(
  AltitudeFn f,
  DateTime start,
  DateTime end,
  double threshold, {
  Duration step = const Duration(minutes: 10),
}) {
  final rising = <DateTime>[];
  final setting = <DateTime>[];
  var t0 = start;
  var v0 = f(t0) - threshold;
  while (t0.isBefore(end)) {
    final t1 = t0.add(step);
    final v1 = f(t1) - threshold;
    if ((v0 < 0) != (v1 < 0)) {
      // Bisect to ~1 second.
      var a = t0, b = t1, fa = v0;
      while (b.difference(a).inMilliseconds > 1000) {
        final mid = a.add(Duration(milliseconds: b.difference(a).inMilliseconds ~/ 2));
        final fm = f(mid) - threshold;
        if ((fa < 0) == (fm < 0)) {
          a = mid;
          fa = fm;
        } else {
          b = mid;
        }
      }
      (v0 < 0 ? rising : setting).add(a);
    }
    t0 = t1;
    v0 = v1;
  }
  return (rising: rising, setting: setting);
}

DateTime _localMidnight(DateTime day) => DateTime(day.year, day.month, day.day);

SunEvents computeSunEvents(DateTime day, double lat, double lon) {
  final start = _localMidnight(day);
  final end = start.add(const Duration(days: 1));
  double alt(DateTime t) => sunHorizontal(t, lat, lon, refraction: false).alt;

  DateTime? first(List<DateTime> l) => l.isEmpty ? null : l.first;
  DateTime? last(List<DateTime> l) => l.isEmpty ? null : l.last;

  final rs = findCrossings(alt, start, end, -0.833);
  final civ = findCrossings(alt, start, end, -6);
  final nau = findCrossings(alt, start, end, -12);
  final ast = findCrossings(alt, start, end, -18);
  final gold = findCrossings(alt, start, end, 6);

  // Solar noon: maximum altitude, golden-section search over the day.
  var bestT = start;
  var bestAlt = -999.0;
  for (var m = 0; m < 24 * 60; m += 10) {
    final t = start.add(Duration(minutes: m));
    final a = alt(t);
    if (a > bestAlt) {
      bestAlt = a;
      bestT = t;
    }
  }
  var lo = bestT.subtract(const Duration(minutes: 10));
  var hi = bestT.add(const Duration(minutes: 10));
  for (var i = 0; i < 30; i++) {
    final span = hi.difference(lo).inMilliseconds;
    final m1 = lo.add(Duration(milliseconds: span ~/ 3));
    final m2 = lo.add(Duration(milliseconds: 2 * span ~/ 3));
    if (alt(m1) < alt(m2)) {
      lo = m1;
    } else {
      hi = m2;
    }
  }
  final noon = lo.add(Duration(milliseconds: hi.difference(lo).inMilliseconds ~/ 2));

  return SunEvents(
    astronomicalDawn: first(ast.rising),
    nauticalDawn: first(nau.rising),
    civilDawn: first(civ.rising),
    sunrise: first(rs.rising),
    goldenHourMorningEnd: first(gold.rising),
    solarNoon: noon,
    noonAltitude: sunHorizontal(noon, lat, lon).alt,
    goldenHourEveningStart: last(gold.setting),
    sunset: last(rs.setting),
    civilDusk: last(civ.setting),
    nauticalDusk: last(nau.setting),
    astronomicalDusk: last(ast.setting),
  );
}

({DateTime? rise, DateTime? set}) computeMoonRiseSet(DateTime day, double lat, double lon) {
  final start = _localMidnight(day);
  final end = start.add(const Duration(days: 1));
  // Topocentric altitude already includes parallax; −0.833° covers
  // refraction (34′) plus the Moon's mean semi-diameter (~15.5′).
  final c = findCrossings(
    (t) => moonHorizontal(t, lat, lon, refraction: false).alt,
    start,
    end,
    -0.833,
  );
  return (
    rise: c.rising.isEmpty ? null : c.rising.first,
    set: c.setting.isEmpty ? null : c.setting.first,
  );
}
