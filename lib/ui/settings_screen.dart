import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'format.dart';

class SettingsScreen extends StatefulWidget {
  final AppState app;
  const SettingsScreen({super.key, required this.app});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _latCtl = TextEditingController(text: widget.app.lat.toStringAsFixed(5));
  late final _lonCtl = TextEditingController(text: widget.app.lon.toStringAsFixed(5));

  AppState get app => widget.app;

  void _applyManual() {
    final lat = double.tryParse(_latCtl.text.trim());
    final lon = double.tryParse(_lonCtl.text.trim());
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter latitude −90…90 and longitude −180…180')));
      return;
    }
    app.setLocation(lat, lon, LocationSource.manual);
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _latCtl.dispose();
    _lonCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AnimatedBuilder(
        animation: app,
        builder: (context, _) {
          Widget toggle(String key, String label, bool value, [String? sub]) => SwitchListTile(
                title: Text(label),
                subtitle: sub == null ? null : Text(sub),
                value: value,
                onChanged: (v) => app.setToggle(key, v),
              );
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _Header('Location'),
              ListTile(
                title: Text(fmtLatLon(app.lat, app.lon)),
                subtitle: Text(switch (app.locationSource) {
                  LocationSource.gps => 'From GPS',
                  LocationSource.manual => 'Set manually',
                  LocationSource.fallback => 'Default (Greenwich) — no location yet',
                }),
                trailing: FilledButton.tonalIcon(
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use GPS'),
                  onPressed: () async {
                    await app.refreshGpsLocation();
                    _latCtl.text = app.lat.toStringAsFixed(5);
                    _lonCtl.text = app.lon.toStringAsFixed(5);
                  },
                ),
              ),
              if (app.locationError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(app.locationError!, style: const TextStyle(color: Colors.orangeAccent)),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latCtl,
                        decoration: const InputDecoration(labelText: 'Latitude'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lonCtl,
                        decoration: const InputDecoration(labelText: 'Longitude'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(onPressed: _applyManual, child: const Text('Set')),
                  ],
                ),
              ),
              const _Header('Orientation'),
              SwitchListTile(
                title: const Text('Use motion sensors'),
                subtitle: const Text('Off = drag to look around'),
                value: app.useSensors,
                onChanged: app.setUseSensors,
              ),
              ListTile(
                title: const Text('Heading offset'),
                subtitle: Text(
                    '${app.headingOffset.toStringAsFixed(1)}° — corrects magnetic declination. '
                    'Tip: use the ⌖ button in the sky view to align on the Sun.'),
              ),
              Slider(
                min: -180,
                max: 180,
                divisions: 720,
                value: app.headingOffset,
                label: '${app.headingOffset.toStringAsFixed(1)}°',
                onChanged: app.setHeadingOffset,
              ),
              ListTile(
                title: const Text('Field of view'),
                subtitle: Text('${app.fov.toStringAsFixed(0)}° (pinch in the sky view to zoom)'),
              ),
              Slider(min: 10, max: 150, value: app.fov, onChanged: app.setFov),
              const _Header('Display'),
              toggle('showAtmosphere', 'Atmosphere', app.showAtmosphere, 'Daylight sky hides stars, like Stellarium'),
              toggle('showStars', 'Stars', app.showStars),
              toggle('showConstellations', 'Constellation lines', app.showConstellations),
              toggle('showPlanets', 'Planets', app.showPlanets),
              toggle('showSunPath', "Today's Sun path", app.showSunPath, 'Arc with hourly markers'),
              toggle('showGrid', 'Alt/Az grid', app.showGrid),
              toggle('showLabels', 'Labels', app.showLabels),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: const Color(0xFFFFC04D))),
      );
}
