import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sky_model.dart';

enum LocationSource { gps, manual, fallback }

/// App-wide settings and the current sky snapshot.
class AppState extends ChangeNotifier {
  // Royal Observatory Greenwich as a neutral fallback.
  double lat = 51.4779;
  double lon = -0.0015;
  LocationSource locationSource = LocationSource.fallback;
  String? locationError;

  /// Offset from real time when "time travelling". Zero = live.
  Duration timeOffset = Duration.zero;
  bool paused = false;
  DateTime? _pausedAt;

  bool useSensors = true;
  double fov = 70; // horizontal field of view, degrees
  double manualAz = 180, manualAlt = 20;

  /// AR mode: live camera behind the sky, drawn to match the camera's lens.
  bool arMode = false;

  /// Field of view of the camera along the long side of its image, degrees.
  /// Typical phone main cameras (~26 mm equivalent) are about 66°; pinching
  /// in AR mode fine-tunes it so the overlay lines up with the real sky.
  double cameraFov = 66;

  /// Added to the compass azimuth; corrects magnetic declination and bias.
  double headingOffset = 0;

  bool showStars = true;
  bool showConstellations = true;
  bool showPlanets = true;
  bool showGrid = true;
  bool showSunPath = true;
  bool showLabels = true;
  bool showAtmosphere = true;
  bool showEcliptic = true;
  bool showVedic = true;

  late SkySnapshot sky = SkySnapshot.compute(now, lat, lon);
  Timer? _ticker;
  SharedPreferences? _prefs;

  DateTime get now {
    if (paused && _pausedAt != null) return _pausedAt!;
    return DateTime.now().add(timeOffset);
  }

  bool get isLive => timeOffset == Duration.zero && !paused;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    if (p.containsKey('lat')) {
      lat = p.getDouble('lat')!;
      lon = p.getDouble('lon')!;
      locationSource = LocationSource.values[p.getInt('locSrc') ?? 1];
    }
    useSensors = p.getBool('useSensors') ?? useSensors;
    fov = p.getDouble('fov') ?? fov;
    arMode = p.getBool('arMode') ?? arMode;
    cameraFov = p.getDouble('cameraFov') ?? cameraFov;
    headingOffset = p.getDouble('headingOffset') ?? headingOffset;
    showStars = p.getBool('showStars') ?? showStars;
    showConstellations = p.getBool('showConstellations') ?? showConstellations;
    showPlanets = p.getBool('showPlanets') ?? showPlanets;
    showGrid = p.getBool('showGrid') ?? showGrid;
    showSunPath = p.getBool('showSunPath') ?? showSunPath;
    showLabels = p.getBool('showLabels') ?? showLabels;
    showAtmosphere = p.getBool('showAtmosphere') ?? showAtmosphere;
    showEcliptic = p.getBool('showEcliptic') ?? showEcliptic;
    showVedic = p.getBool('showVedic') ?? showVedic;
    recompute();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!paused) recompute();
    });
    if (locationSource != LocationSource.manual) {
      unawaited(refreshGpsLocation());
    }
  }

  void recompute() {
    sky = SkySnapshot.compute(now, lat, lon);
    notifyListeners();
  }

  Future<void> refreshGpsLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        locationError = 'Location services are disabled.';
        notifyListeners();
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        locationError = 'Location permission denied — set it manually in Settings.';
        notifyListeners();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      locationError = null;
      setLocation(pos.latitude, pos.longitude, LocationSource.gps);
    } catch (e) {
      locationError = 'Could not get location: $e';
      notifyListeners();
    }
  }

  void setLocation(double newLat, double newLon, LocationSource src) {
    lat = newLat.clamp(-90.0, 90.0);
    lon = ((newLon + 180) % 360 + 360) % 360 - 180;
    locationSource = src;
    _prefs?.setDouble('lat', lat);
    _prefs?.setDouble('lon', lon);
    _prefs?.setInt('locSrc', src.index);
    recompute();
  }

  // ---- time controls -------------------------------------------------------
  void shiftTime(Duration d) {
    if (paused) {
      _pausedAt = _pausedAt!.add(d);
    } else {
      timeOffset += d;
    }
    recompute();
  }

  void resetTime() {
    timeOffset = Duration.zero;
    paused = false;
    _pausedAt = null;
    recompute();
  }

  void togglePause() {
    if (paused) {
      timeOffset = _pausedAt!.difference(DateTime.now());
      paused = false;
      _pausedAt = null;
    } else {
      _pausedAt = now;
      paused = true;
    }
    recompute();
  }

  void setTime(DateTime t) {
    if (paused) {
      _pausedAt = t;
    } else {
      timeOffset = t.difference(DateTime.now());
    }
    recompute();
  }

  // ---- view settings -------------------------------------------------------
  void setUseSensors(bool v) {
    useSensors = v;
    _prefs?.setBool('useSensors', v);
    notifyListeners();
  }

  void setFov(double v) {
    fov = v.clamp(10.0, 150.0);
    _prefs?.setDouble('fov', fov);
    notifyListeners();
  }

  void setArMode(bool v) {
    arMode = v;
    _prefs?.setBool('arMode', v);
    notifyListeners();
  }

  void setCameraFov(double v) {
    cameraFov = v.clamp(30.0, 110.0);
    _prefs?.setDouble('cameraFov', cameraFov);
    notifyListeners();
  }

  void setManualView(double az, double alt) {
    manualAz = ((az % 360) + 360) % 360;
    manualAlt = alt.clamp(-89.9, 89.9);
    notifyListeners();
  }

  void setHeadingOffset(double v) {
    headingOffset = ((v + 180) % 360 + 360) % 360 - 180;
    _prefs?.setDouble('headingOffset', headingOffset);
    notifyListeners();
  }

  void setToggle(String key, bool value) {
    switch (key) {
      case 'showStars':
        showStars = value;
      case 'showConstellations':
        showConstellations = value;
      case 'showPlanets':
        showPlanets = value;
      case 'showGrid':
        showGrid = value;
      case 'showSunPath':
        showSunPath = value;
      case 'showLabels':
        showLabels = value;
      case 'showAtmosphere':
        showAtmosphere = value;
      case 'showEcliptic':
        showEcliptic = value;
      case 'showVedic':
        showVedic = value;
    }
    _prefs?.setBool(key, value);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
