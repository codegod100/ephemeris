import 'package:flutter/material.dart';

import '../sensors/orientation_service.dart';
import '../state/app_state.dart';
import '../state/sky_model.dart';
import 'ar_camera.dart';
import 'format.dart';
import 'settings_screen.dart';
import 'sky_painter.dart';
import 'sun_info_screen.dart';
import 'time_bar.dart';

class SkyViewScreen extends StatefulWidget {
  final AppState app;
  final OrientationService orientation;
  const SkyViewScreen({super.key, required this.app, required this.orientation});

  @override
  State<SkyViewScreen> createState() => _SkyViewScreenState();
}

class _SkyViewScreenState extends State<SkyViewScreen> with WidgetsBindingObserver {
  String? _selected;
  double _fovAtScaleStart = 70;
  Size _size = Size.zero;
  final _ar = ArCamera();

  AppState get app => widget.app;
  OrientationService get ori => widget.orientation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (app.useSensors) ori.start();
    if (app.arMode) _ar.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ar.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera in the background so other apps can use it.
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _ar.stop();
    } else if (state == AppLifecycleState.resumed && app.arMode) {
      _ar.start();
    }
  }

  /// Horizontal field of view actually drawn. In AR mode it follows the
  /// camera lens instead of the zoom setting.
  double get _fov {
    if (!app.arMode || _size.isEmpty) return app.fov;
    return arScreenFov(_size, _ar.portraitPreviewSize ?? const Size(3, 4), app.cameraFov);
  }

  SkyProjection get _projection => SkyProjection(_camera, _size, _fov, rectilinear: app.arMode);

  void _toggleAr() {
    final v = !app.arMode;
    app.setArMode(v);
    if (v) {
      _ar.start();
      // AR only makes sense when the view follows the phone.
      if (!app.useSensors) _toggleSensors();
    } else {
      _ar.stop();
    }
  }

  bool get _sensorMode => app.useSensors && ori.available && ori.basis != null;

  CameraBasis get _camera {
    if (_sensorMode) return ori.basis!.rotatedAboutUp(app.headingOffset);
    return CameraBasis.fromAzAlt(app.manualAz, app.manualAlt);
  }

  void _toggleSensors() {
    final v = !app.useSensors;
    if (v) {
      ori.start();
    } else {
      // Continue manual mode from wherever the phone was pointing.
      final cam = _camera;
      app.setManualView(cam.azimuth, cam.altitude);
      ori.stop();
      if (app.arMode) {
        app.setArMode(false);
        _ar.stop();
      }
    }
    app.setUseSensors(v);
  }

  void _onScaleStart(ScaleStartDetails d) => _fovAtScaleStart = app.arMode ? app.cameraFov : app.fov;

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      // In AR mode the zoom is fixed by the lens; pinching calibrates the
      // lens's field of view so the overlay matches the camera image.
      if (app.arMode) {
        app.setCameraFov(_fovAtScaleStart / d.scale);
      } else {
        app.setFov(_fovAtScaleStart / d.scale);
      }
    } else if (!_sensorMode) {
      final degPerPx = _fov / _size.width;
      app.setManualView(
        app.manualAz - d.focalPointDelta.dx * degPerPx,
        app.manualAlt + d.focalPointDelta.dy * degPerPx,
      );
    }
  }

  void _onTap(TapUpDetails d) {
    final proj = _projection;
    SkyObject? best;
    var bestDist = 40.0;
    for (final o in app.sky.allObjects) {
      if (o.kind == SkyObjectKind.star && !app.showStars) continue;
      if (o.kind == SkyObjectKind.planet && !app.showPlanets) continue;
      if (o.kind == SkyObjectKind.node && !app.showVedic) continue;
      final p = proj.project(o.enu);
      if (p == null) continue;
      final dist = (p - d.localPosition).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = o;
      }
    }
    setState(() => _selected = best?.name);
  }

  void _lookAtSun() {
    if (_sensorMode) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Follow the ☀ arrow at the edge of the screen to find the Sun.'),
      ));
      return;
    }
    app.setManualView(app.sky.sun.pos.az, app.sky.sun.pos.alt);
    setState(() => _selected = 'Sun');
  }

  Future<void> _calibrateOnSun() async {
    final cam = _camera;
    final sun = app.sky.sun.pos;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Align compass to the Sun'),
        content: Text(
          'Point the top-back of your phone straight at the real Sun (don\'t look '
          'directly at it — use your phone\'s shadow or the camera), then tap Align.\n\n'
          'This corrects magnetic declination and compass bias.\n\n'
          'Current pointing: ${fmtAz(cam.azimuth)}\nComputed Sun: ${fmtAz(sun.az)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Align')),
        ],
      ),
    );
    if (ok != true) return;
    // Re-read the pointing direction at the moment the user confirmed.
    final raw = ori.basis;
    if (raw == null) return;
    app.setHeadingOffset(sun.az - raw.azimuth);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Heading offset set to ${app.headingOffset.toStringAsFixed(1)}°'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([app, ori, _ar]),
        builder: (context, _) {
          final cam = _camera;
          return Stack(
            children: [
              if (app.arMode) Positioned.fill(child: ArCameraView(camera: _ar)),
              Positioned.fill(
                child: LayoutBuilder(builder: (context, c) {
                  _size = c.biggest;
                  return GestureDetector(
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onTapUp: _onTap,
                    child: CustomPaint(
                      painter: SkyPainter(
                        sky: app.sky,
                        cam: cam,
                        fov: _fov,
                        showStars: app.showStars,
                        showConstellations: app.showConstellations,
                        showPlanets: app.showPlanets,
                        showGrid: app.showGrid,
                        showEcliptic: app.showEcliptic,
                        showVedic: app.showVedic,
                        showSunPath: app.showSunPath,
                        showLabels: app.showLabels,
                        showAtmosphere: app.showAtmosphere,
                        selected: _selected,
                        ar: app.arMode,
                      ),
                      size: Size.infinite,
                    ),
                  );
                }),
              ),
              _crosshair(),
              SafeArea(child: _topBar(cam)),
              if (_selected != null) _selectionCard(),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(child: TimeBar(app: app)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _crosshair() => IgnorePointer(
        child: Center(
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 1.2),
            ),
          ),
        ),
      );

  Widget _topBar(CameraBasis cam) {
    final sun = app.sky.sun.pos;
    final warn = _sensorMode && ori.magneticInterference;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _glass(
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pointing  ${fmtAz(cam.azimuth)}  ${fmtAlt(cam.altitude)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('☀ Sun  ${fmtAz(sun.az)}  ${fmtAlt(sun.alt)}',
                      style: const TextStyle(color: Color(0xFFFFE082))),
                  if (ori.needsPermission && app.useSensors)
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Colors.orangeAccent),
                      icon: const Icon(Icons.screen_rotation, size: 16),
                      label: const Text('Tap to enable motion sensors'),
                      onPressed: ori.requestPermission,
                    ),
                  if (!ori.available && app.useSensors)
                    const Text('No motion sensors — drag to look around',
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  if (warn)
                    const Text('Magnetic interference — wave phone in a figure-8',
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  if (app.arMode && _ar.error != null)
                    Text(_ar.error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  if (app.arMode && _ar.error == null)
                    Text('AR lens ${app.cameraFov.toStringAsFixed(0)}° — pinch to line up with the sky',
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  if (app.locationError != null)
                    Text(app.locationError!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _glass(Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: app.useSensors ? 'Sensor mode (tap for manual)' : 'Manual mode (tap for sensors)',
                icon: Icon(app.useSensors ? Icons.explore : Icons.pan_tool_alt, color: Colors.white),
                onPressed: _toggleSensors,
              ),
              IconButton(
                tooltip: app.arMode ? 'AR camera on (tap to turn off)' : 'AR camera off (tap to turn on)',
                icon: Icon(app.arMode ? Icons.videocam : Icons.videocam_off_outlined, color: Colors.white),
                onPressed: _toggleAr,
              ),
              IconButton(
                tooltip: 'Find the Sun',
                icon: const Icon(Icons.wb_sunny, color: Color(0xFFFFC04D)),
                onPressed: _lookAtSun,
              ),
              if (_sensorMode && sun.alt > 0)
                IconButton(
                  tooltip: 'Align compass on the Sun',
                  icon: const Icon(Icons.gps_fixed, color: Colors.white),
                  onPressed: _calibrateOnSun,
                ),
              IconButton(
                tooltip: 'Sun & Moon times',
                icon: const Icon(Icons.info_outline, color: Colors.white),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => SunInfoScreen(app: app))),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.tune, color: Colors.white),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => SettingsScreen(app: app))),
              ),
            ],
          ), pad: 0),
        ],
      ),
    );
  }

  Widget _selectionCard() {
    final o = app.sky.allObjects.where((x) => x.name == _selected).firstOrNull;
    if (o == null) return const SizedBox.shrink();
    final extra = switch (o.kind) {
      SkyObjectKind.moon =>
        '${(app.sky.moonFraction * 100).toStringAsFixed(0)}% illuminated',
      SkyObjectKind.star => 'Magnitude ${o.mag.toStringAsFixed(2)}',
      SkyObjectKind.planet => 'Planet',
      SkyObjectKind.sun => o.pos.alt > 0 ? 'Above the horizon' : 'Below the horizon',
      SkyObjectKind.node => o.name == 'Rahu' ? 'Ascending lunar node' : 'Descending lunar node',
    };
    final graha = app.showVedic ? app.sky.grahaFor(o) : null;
    final vedic = graha == null ? null : fmtGraha(graha, moonAge: app.sky.moonAge);
    return Positioned(
      left: 12,
      right: 12,
      bottom: 150,
      child: _glass(Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Az ${fmtAz(o.pos.az)}   Alt ${fmtAlt(o.pos.alt)}',
                    style: const TextStyle(color: Colors.white70)),
                Text(extra, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                if (vedic != null) Text(vedic, style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => setState(() => _selected = null),
          ),
        ],
      )),
    );
  }

  Widget _glass(Widget child, {double pad = 10}) => Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: const Color(0xAA0B1020),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: child,
      );
}
