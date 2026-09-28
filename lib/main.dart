import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sensors/orientation_service.dart';
import 'state/app_state.dart';
import 'ui/sky_view_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The orientation math assumes portrait; lock it so the sky doesn't flip.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final app = AppState();
  await app.init();
  runApp(HeliosSkyApp(app: app, orientation: OrientationService()));
}

class HeliosSkyApp extends StatelessWidget {
  final AppState app;
  final OrientationService orientation;
  const HeliosSkyApp({super.key, required this.app, required this.orientation});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helios Sky',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB300),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF070A14),
        useMaterial3: true,
      ),
      home: SkyViewScreen(app: app, orientation: orientation),
    );
  }
}
