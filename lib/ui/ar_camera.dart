import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../astro/astro_math.dart';

/// Horizontal field of view of the *screen* when a camera preview is shown
/// with [BoxFit.cover].
///
/// [preview] is the preview size in portrait (width < height), and
/// [longSideFov] is the lens's field of view along the preview's long side.
/// The camera is a pinhole (rectilinear) camera, so the overlay must use a
/// gnomonic projection with this field of view to line up with the image.
double arScreenFov(Size screen, Size preview, double longSideFov) {
  final scale = math.max(screen.width / preview.width, screen.height / preview.height);
  final longPx = preview.longestSide * scale;
  final focal = (longPx / 2) / tanD(longSideFov / 2);
  return 2 * atan2D(screen.width / 2, focal);
}

/// Owns the back camera used as the AR background.
class ArCamera extends ChangeNotifier {
  CameraController? _controller;
  String? error;
  bool _starting = false;
  bool _disposed = false;

  CameraController? get controller {
    final c = _controller;
    return c != null && c.value.isInitialized ? c : null;
  }

  /// Preview size in portrait orientation, or null until the camera is ready.
  Size? get portraitPreviewSize {
    final s = controller?.value.previewSize;
    if (s == null) return null;
    return Size(s.shortestSide, s.longestSide);
  }

  Future<void> start() async {
    if (_controller != null || _starting) return;
    _starting = true;
    error = null;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw CameraException('noCamera', 'No camera found');
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await c.initialize();
      if (_disposed) {
        await c.dispose();
        return;
      }
      _controller = c;
    } on CameraException catch (e) {
      error = switch (e.code) {
        'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' || 'CameraAccessRestricted' =>
          'Camera permission denied',
        _ => 'Camera unavailable: ${e.description ?? e.code}',
      };
    } catch (e) {
      error = 'Camera unavailable: $e';
    } finally {
      _starting = false;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> stop() async {
    final c = _controller;
    _controller = null;
    if (!_disposed) notifyListeners();
    await c?.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}

/// Full-screen camera preview, cropped to fill like [BoxFit.cover].
class ArCameraView extends StatelessWidget {
  final ArCamera camera;
  const ArCameraView({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    final c = camera.controller;
    final size = camera.portraitPreviewSize;
    if (c == null || size == null) return const ColoredBox(color: Colors.black);
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: size.width, height: size.height, child: CameraPreview(c)),
      ),
    );
  }
}
