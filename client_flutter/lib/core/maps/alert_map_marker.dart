import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';

/// Shared visual language for alert markers on the live map and details preview.
class AlertMapMarkerStyle {
  static const int bitmapSize = 96;

  static Color tierColor(int? tier) {
    switch (tier) {
      case 4:
        return AppColors.danger;
      case 3:
        return const Color(0xFFE07A3D);
      case 2:
        return AppColors.primary;
      case 1:
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  static Color tierColorDark(int? tier) {
    switch (tier) {
      case 4:
        return const Color(0xFF8F1520);
      case 3:
        return const Color(0xFFB85A22);
      case 2:
        return AppColors.primaryDark;
      case 1:
        return const Color(0xFF5FA39C);
      default:
        return AppColors.primaryDark;
    }
  }

  static IconData categoryIcon(String category) {
    switch (category) {
      case 'emergency':
        return Icons.local_fire_department_rounded;
      case 'crime':
        return Icons.gpp_bad_rounded;
      case 'infrastructure':
        return Icons.construction_rounded;
      case 'weather':
        return Icons.cloud_rounded;
      case 'civic':
        return Icons.account_balance_rounded;
      case 'community':
        return Icons.groups_rounded;
      default:
        return Icons.more_horiz_rounded;
    }
  }

  static String styleImageId({required int? tier, required String category}) {
    final safeCategory = category.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return 'alert-pin-t${tier ?? 0}-$safeCategory';
  }
}

class AlertMapMarkerPainter extends CustomPainter {
  const AlertMapMarkerPainter({
    required this.fill,
    required this.fillDark,
    required this.icon,
    this.pulseProgress = 0.55,
  });

  final Color fill;
  final Color fillDark;
  final IconData icon;

  /// 0..1 — expands outer rings; used for live pulse on the details sheet.
  final double pulseProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final coreRadius = size.shortestSide * 0.22;

    _paintPulseRings(canvas, center, coreRadius);
    _paintCore(canvas, center, coreRadius);
    _paintGlyph(canvas, center, coreRadius);
  }

  void _paintPulseRings(Canvas canvas, Offset center, double coreRadius) {
    final rings = <({double scale, double opacity})>[
      (scale: 1.55 + pulseProgress * 0.55, opacity: 0.22 * (1 - pulseProgress)),
      (scale: 1.28 + pulseProgress * 0.28, opacity: 0.34 * (1 - pulseProgress * 0.65)),
      (scale: 1.12, opacity: 0.42),
    ];

    for (final ring in rings) {
      final paint =
          Paint()
            ..color = fill.withValues(
              alpha: ring.opacity.clamp(0.08, 0.45),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2;
      canvas.drawCircle(center, coreRadius * ring.scale, paint);
    }

    final softFill =
        Paint()
          ..color = fill.withValues(
            alpha: 0.14 * (1 - pulseProgress * 0.35),
          )
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, coreRadius * (1.35 + pulseProgress * 0.25), softFill);
  }

  void _paintCore(Canvas canvas, Offset center, double coreRadius) {
    final shadow =
        Paint()
          ..color = AppColors.ink.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center.translate(0, 2.5), coreRadius, shadow);

    final fillPaint =
        Paint()
          ..shader = ui.Gradient.radial(
            center.translate(-coreRadius * 0.25, -coreRadius * 0.3),
            coreRadius * 1.35,
            [fill, fillDark],
          );
    canvas.drawCircle(center, coreRadius, fillPaint);

    final border =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    canvas.drawCircle(center, coreRadius, border);
  }

  void _paintGlyph(Canvas canvas, Offset center, double coreRadius) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final fontSize = coreRadius * 1.15;
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: fontSize,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
        height: 1,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant AlertMapMarkerPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.fillDark != fillDark ||
        oldDelegate.icon != icon ||
        oldDelegate.pulseProgress != pulseProgress;
  }
}

Future<Uint8List> drawAlertMapMarkerPng({
  required int? tier,
  required String category,
  double pulseProgress = 0.45,
}) async {
  const size = AlertMapMarkerStyle.bitmapSize;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));

  AlertMapMarkerPainter(
    fill: AlertMapMarkerStyle.tierColor(tier),
    fillDark: AlertMapMarkerStyle.tierColorDark(tier),
    icon: AlertMapMarkerStyle.categoryIcon(category),
    pulseProgress: pulseProgress,
  ).paint(canvas, Size(size.toDouble(), size.toDouble()));

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Mapbox Static Images URL centered on an alert. No marker overlay — Flutter
/// draws the pulsing pin on top so it matches the live map marker.
String? buildAlertStaticMapUrl({
  required double latitude,
  required double longitude,
  required int width,
  required int height,
  double zoom = 14.2,
  double pixelRatio = 2,
}) {
  if (!AppConfig.hasMapboxAccessToken) return null;
  if (width <= 0 || height <= 0) return null;

  final retina = pixelRatio >= 1.5 ? '@2x' : '';
  final w = width.clamp(1, 1280);
  final h = height.clamp(1, 1280);
  final token = Uri.encodeQueryComponent(AppConfig.mapboxAccessToken);

  return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/'
      '${longitude.toStringAsFixed(6)},${latitude.toStringAsFixed(6)},'
      '${zoom.toStringAsFixed(2)},0/${w}x$h$retina'
      '?access_token=$token';
}

/// Live pulsing marker for the details-sheet map preview.
class PulsingAlertMapMarker extends StatefulWidget {
  const PulsingAlertMapMarker({
    super.key,
    required this.tier,
    required this.category,
    this.size = 72,
  });

  final int? tier;
  final String category;
  final double size;

  @override
  State<PulsingAlertMapMarker> createState() => _PulsingAlertMapMarkerState();
}

class _PulsingAlertMapMarkerState extends State<PulsingAlertMapMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: AlertMapMarkerPainter(
            fill: AlertMapMarkerStyle.tierColor(widget.tier),
            fillDark: AlertMapMarkerStyle.tierColorDark(widget.tier),
            icon: AlertMapMarkerStyle.categoryIcon(widget.category),
            pulseProgress: Curves.easeOut.transform(_controller.value),
          ),
        );
      },
    );
  }
}
