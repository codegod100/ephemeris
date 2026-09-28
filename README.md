# Helios Sky ☀️

A Flutter app, in the spirit of Stellarium, that works out where things are in the sky. Hold your phone up and it shows the part of the sky you're pointing at: the **Sun**, Moon, planets, bright stars and constellations, all drawn over a live horizon. When the Sun isn't on screen, an arrow at the edge shows which way to turn.

Every position comes from a **built-in ephemeris written in pure Dart**. The app needs no network and no API keys.

## Features

- **Orientation-driven sky view.** The accelerometer and magnetometer are combined into a full 3-D camera orientation (the same math as Android's `getRotationMatrix`), then smoothed.
- **Stereographic projection**, the same default Stellarium uses. The horizon is filled exactly, because a great circle projects to a circle.
- **AR camera overlay.** Tap 🎥 to show the live camera behind the sky. In AR mode the overlay switches to a rectilinear (gnomonic) projection, which is what a real lens produces, and its scale follows the camera's field of view and how the preview is cropped to the screen. Pinch to fine-tune the lens FOV until stars and the Sun sit on top of the real ones. The value is also in Settings.
- **Sun finder.** Shows the Sun's current azimuth and altitude, draws **today's sun path** with hourly markers, and puts an edge arrow on screen with the angular distance to the Sun.
- **Compass alignment on the Sun.** Point the phone at the real Sun and tap ⌖. The app then corrects for magnetic declination and compass bias.
- **Moon** with correct phase and bright-limb orientation, plus a topocentric parallax correction.
- **Planets** from Mercury to Neptune.
- **Ecliptic and celestial equator**, with the March/September equinox and June/December solstice points marked where the Sun crosses the equator and where it is farthest from it.
- **Jyotisha layer.** The 12 **rashis** and 27 **nakshatras** of the sidereal zodiac (Lahiri ayanamsa) are drawn along the ecliptic, with **Rahu and Ketu** (the mean lunar nodes) marked. Tap any of the nine grahas to see its rashi, degree, nakshatra, pada and nakshatra lord (℞ when retrograde). The *Sun & Moon* screen lists all nine, plus the current ayanamsa.
- **~95 bright stars** with constellation stick figures (Orion, Big Dipper, Cassiopeia, Cygnus, Scorpius, Crux, Leo and more).
- **Atmosphere.** The sky colour follows the Sun's altitude through day, civil, nautical and astronomical twilight, and stars fade out in daylight.
- **Time travel.** Step ±10 min / 1 h / 1 day, pause the clock, or pick any date and time.
- **Sun & Moon times.** Dawn and dusk (astronomical, nautical and civil), sunrise, sunset, solar noon, golden hour, day length, moonrise, moonset and phase.
- **Manual mode.** Drag to look around and pinch to zoom. This works on emulators and tablets without a compass.
- GPS location, or enter latitude and longitude by hand. Settings are saved.
- **Web version.** Browsers don't expose the magnetometer, so on the web the orientation comes from the browser's own compass-referenced orientation events instead: `deviceorientationabsolute` on Android Chrome, and `deviceorientation` plus `webkitCompassHeading` on iOS Safari (which asks for motion permission after you tap *Enable motion sensors*). Sensors, camera and GPS all need the page to be served over HTTPS. Desktop browsers have no orientation sensors and fall back to drag mode.

## Accuracy

| Body | Method | Typical error |
|---|---|---|
| Sun | Meeus ch. 25 (low-precision) with nutation/aberration | ~0.01° |
| Moon | Meeus ch. 47, main periodic terms + parallax | ~0.05° |
| Planets | JPL/Standish Keplerian elements (1800–2050) | a few arcmin |
| Stars | J2000 catalog, precessed to date | < 1′ |
| Rahu/Ketu | Mean lunar node, Meeus 47.7 | < 0.01° |
| Ayanamsa | Lahiri, 1956 ICRC anchor + IAU 2006 precession | reproduces the published Makar Sankranti 2024 moment to < 0.05° |

Unit tests in `test/` check the engine against the worked examples in Meeus's *Astronomical Algorithms* (examples 12.a, 25.a, 33.a, 47.a) and against physical checks such as midnight sun, noon altitude and Polaris's altitude.

In practice, **your phone's compass is the main source of error** (often 5–15°). That's why the "align on the Sun" calibration exists.

## Project layout

```
lib/
  astro/            # pure-Dart ephemeris, no Flutter dependency
    astro_math.dart   time scales, sidereal time, coordinate transforms, precession, refraction
    sun.dart          solar position
    moon.dart         lunar position, phase
    planets.dart      Keplerian planets
    stars.dart        bright-star catalog + constellation lines
    events.dart       rise/set/twilight solver (scan + bisection, handles polar day/night)
    vedic.dart        Lahiri ayanamsa, rashis, nakshatras, lunar nodes, the nine grahas
  sensors/
    orientation_service.dart   accelerometer + magnetometer → camera basis (ENU)
    web_orientation*.dart      browser DeviceOrientation events (web only)
  state/
    app_state.dart    settings, location, time control
    sky_model.dart    per-second snapshot of every object's alt/az
  ui/
    sky_view_screen.dart  main view, gestures, overlays
    sky_painter.dart      stereographic renderer (gnomonic in AR mode)
    ar_camera.dart        camera preview + lens-FOV maths for the AR overlay
    sun_info_screen.dart  times & tables
    settings_screen.dart
    time_bar.dart
deploy/
  modal_app.py      web deploy to Modal
test/
  astro_test.dart, orientation_test.dart, vedic_test.dart, widget_test.dart
```

## Getting started

```bash
# regenerate the standard android/ & ios/ boilerplate and launcher icons
# (only the customised AndroidManifest.xml and Info.plist are committed)
flutter create --org io.github.heliosky --project-name helios_sky --platforms android,ios .
flutter pub get
flutter test          # run the ephemeris tests (TZ=UTC flutter test to include the equinox test)
flutter run           # on a real device, for the sensors
```

For the web version, add `web` to the `--platforms` list above, then `flutter build web` and serve `build/web/` over HTTPS.

### Deploying the web version to Modal

`deploy/modal_app.py` builds the web app inside a [Modal](https://modal.com) image (it installs Flutter there, so you don't need Flutter locally) and serves it over HTTPS:

```bash
pip install modal && modal setup     # once, to log in
modal deploy deploy/modal_app.py     # prints the https://…modal.run URL
modal serve deploy/modal_app.py      # temporary dev URL that redeploys on change
```

The first deploy takes several minutes while Flutter installs. Later deploys reuse that layer and only rebuild the app.

You need a physical phone with an accelerometer and magnetometer for sensor mode. On an emulator, tap the ✋/🧭 button to switch to manual drag mode.

**Permissions:** location (to compute the sky for where you are), camera (for AR mode) and, on iOS, motion. Both are already declared in `AndroidManifest.xml` and `Info.plist`.

## How the orientation works

1. Accelerometer vector **A** (points up when the phone is at rest) and magnetic field vector **E** are low-pass filtered.
2. **H = E × A** gives East and **M = A × H** gives North, both in device coordinates. Together with **A** (Up) they form the rows of the rotation matrix *R*.
3. The camera looks along device −Z, so `forward = R·(0,0,−1)`. The screen's right and top edges are `R·x̂` and `R·ŷ`.
4. The heading offset (declination) rotates the basis about Up.
5. Each sky object's East-North-Up unit vector *v* is projected with `k = 2/(1+v·f)`, giving `screen = centre + focal·k·(v·r, −v·u)`.

## Roadmap ideas

- Gyroscope fusion (rotation-vector sensor) for smoother motion
- World Magnetic Model for automatic declination
- Larger star catalog (Hipparcos to mag 6), deep-sky objects
- Sun path for any chosen date (solstices/equinoxes) for photographers and solar-panel planning

## License

MIT, see [LICENSE](LICENSE).
