import 'package:flutter/material.dart';

import '../astro/events.dart';
import '../astro/moon.dart';
import '../astro/vedic.dart';
import '../state/app_state.dart';
import 'format.dart';

class SunInfoScreen extends StatelessWidget {
  final AppState app;
  const SunInfoScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sun, Moon & Planets')),
      body: AnimatedBuilder(
        animation: app,
        builder: (context, _) {
          final t = app.now;
          final sky = app.sky;
          final ev = computeSunEvents(t, app.lat, app.lon);
          final moonRs = computeMoonRiseSet(t, app.lat, app.lon);
          Widget row(String k, String v, {Color? color}) => ListTile(
                dense: true,
                title: Text(k),
                trailing: Text(v,
                    style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()], color: color, fontSize: 15)),
              );
          Widget header(String s) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text(s, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFFFFC04D))),
              );

          return ListView(
            children: [
              ListTile(
                title: Text('${fmtDate(t)} · ${fmtTime(t)}'),
                subtitle: Text(fmtLatLon(app.lat, app.lon)),
              ),
              header('Sun now'),
              row('Azimuth', fmtAz(sky.sun.pos.az)),
              row('Altitude', fmtAlt(sky.sun.pos.alt)),
              header('Sun today'),
              row('Astronomical dawn', fmtTime(ev.astronomicalDawn)),
              row('Nautical dawn', fmtTime(ev.nauticalDawn)),
              row('Civil dawn', fmtTime(ev.civilDawn)),
              row('Sunrise', fmtTime(ev.sunrise), color: const Color(0xFFFFC04D)),
              row('Golden hour ends', fmtTime(ev.goldenHourMorningEnd)),
              row('Solar noon', '${fmtTime(ev.solarNoon)}  (${fmtAlt(ev.noonAltitude)})'),
              row('Golden hour begins', fmtTime(ev.goldenHourEveningStart)),
              row('Sunset', fmtTime(ev.sunset), color: const Color(0xFFFF8A50)),
              row('Civil dusk', fmtTime(ev.civilDusk)),
              row('Nautical dusk', fmtTime(ev.nauticalDusk)),
              row('Astronomical dusk', fmtTime(ev.astronomicalDusk)),
              row('Day length', ev.dayLength != null
                  ? fmtDuration(ev.dayLength)
                  : (ev.noonAltitude > 0 ? 'Sun never sets' : 'Sun never rises')),
              header('Moon'),
              row('Phase', moonPhaseName(sky.moonAge)),
              row('Illuminated', '${(sky.moonFraction * 100).toStringAsFixed(1)}%'),
              row('Azimuth', fmtAz(sky.moon.pos.az)),
              row('Altitude', fmtAlt(sky.moon.pos.alt)),
              row('Moonrise', fmtTime(moonRs.rise)),
              row('Moonset', fmtTime(moonRs.set)),
              header('Planets'),
              for (final p in sky.planets)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 6, backgroundColor: p.color),
                  title: Text(p.name),
                  subtitle: Text(p.pos.alt > 0 ? 'Above horizon' : 'Below horizon'),
                  trailing: Text('${fmtAz(p.pos.az)}\n${fmtAlt(p.pos.alt)}', textAlign: TextAlign.right),
                ),
              header('Navagraha (sidereal, Lahiri)'),
              row('Ayanamsa', fmtDegMin(sky.ayanamsa)),
              for (final g in sky.grahas)
                ListTile(
                  dense: true,
                  title: Text('${g.graha.sanskrit} · ${g.graha.english}'),
                  subtitle: Text('${g.sidereal.nakshatra}'
                      '${g.graha == Graha.chandra && moonPhaseSymbol(sky.moonAge).isNotEmpty ? ' ${moonPhaseSymbol(sky.moonAge)}' : ''} pada ${g.sidereal.pada} · '
                      'lord ${g.sidereal.nakshatraLord.sanskrit}'),
                  trailing: Text(
                    '${g.sidereal.rashi.name} ${fmtDegMin(g.sidereal.degInRashi)}${g.retrograde ? ' ℞' : ''}\n'
                    '${g.sidereal.rashi.english}',
                    textAlign: TextAlign.right,
                  ),
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
