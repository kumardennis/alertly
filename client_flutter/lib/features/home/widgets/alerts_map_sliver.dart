import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/location/location_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/alert.dart';
import '../../alerts/alerts_provider.dart';
import 'alert_details_bottom_sheet.dart';

class AlertsMapView extends StatelessWidget {
  const AlertsMapView({super.key});

  bool get _supportsMapbox {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.40),
          width: 1.5,
        ),
      ),
      child:
          !_supportsMapbox
              ? _MapboxUnavailableNotice(text: text)
              : AppConfig.hasMapboxAccessToken
              ? const _MapboxViewport()
              : _MapboxSetupNotice(text: text),
    );
  }
}

class _MapboxViewport extends ConsumerStatefulWidget {
  const _MapboxViewport();

  @override
  ConsumerState<_MapboxViewport> createState() => _MapboxViewportState();
}

class _MapboxViewportState extends ConsumerState<_MapboxViewport> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _alertsAnnotationManager;
  Uint8List? _markerBitmap;
  UserLocation? _latestLocation;
  bool _requestedDeviceLocation = false;
  bool _centeredOnDevice = false;
  bool _resolvingDeviceLocation = false;
  bool _fetchingMapAlerts = false;
  bool _isStyleLoaded = false;
  bool _markerImageRegistered = false;
  String _lastRenderedAlertsKey = '';

  static const String _markerImageId = 'alert-pin';

  static final CameraOptions _initialCamera = CameraOptions(
    center: Point(coordinates: Position(-95.7129, 37.0902)),
    zoom: 2.6,
    bearing: 0,
    pitch: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveDeviceLocation();
    });
  }

  Future<void> _resolveDeviceLocation() async {
    if (_requestedDeviceLocation) {
      return;
    }
    _requestedDeviceLocation = true;

    final cached = ref.read(locationProvider).valueOrNull;
    if (cached != null) {
      _latestLocation = cached;
      _centerOnDeviceIfReady();
      return;
    }

    if (mounted) {
      setState(() => _resolvingDeviceLocation = true);
    }

    try {
      final fresh =
          await ref.read(locationProvider.notifier).refreshCurrentLocation();
      _latestLocation = fresh;
      _centerOnDeviceIfReady();
    } catch (_) {
      // Keep default camera if permission or location lookup fails.
    } finally {
      if (mounted) {
        setState(() => _resolvingDeviceLocation = false);
      }
    }
  }

  void _centerOnDeviceIfReady() {
    if (_centeredOnDevice || _mapboxMap == null || _latestLocation == null) {
      return;
    }

    _mapboxMap!.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        puckBearingEnabled: true,
      ),
    );

    _mapboxMap!.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(
            _latestLocation!.longitude,
            _latestLocation!.latitude,
          ),
        ),
        zoom: 13.5,
        bearing: 0,
        pitch: 0,
      ),
    );
    _centeredOnDevice = true;
  }

  Future<void> fetchAlertsInCurrentMapView() async {
    if (_mapboxMap == null || _fetchingMapAlerts) {
      return;
    }

    setState(() => _fetchingMapAlerts = true);

    try {
      final cameraState = await _mapboxMap!.getCameraState();
      final bounds = await _mapboxMap!.coordinateBoundsForCamera(
        cameraState.toCameraOptions(),
      );

      final southLat = bounds.southwest.coordinates[1] as double;
      final westLng = bounds.southwest.coordinates[0] as double;
      final northLat = bounds.northeast.coordinates[1] as double;
      final eastLng = bounds.northeast.coordinates[0] as double;

      debugPrint(
        '[MapView] fetching alerts in bounds '
        'southLat=$southLat westLng=$westLng northLat=$northLat eastLng=$eastLng',
      );

      await ref
          .read(alertsProvider.notifier)
          .reloadInMapBounds(
            southLat: southLat,
            westLng: westLng,
            northLat: northLat,
            eastLng: eastLng,
          );

      final fetchedAlerts = ref.read(alertsProvider).valueOrNull ?? const [];
      debugPrint('[MapView] fetched alerts count=${fetchedAlerts.length}');
      await _syncAlertMarkers(fetchedAlerts);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load alerts for this map area.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _fetchingMapAlerts = false);
      }
    }
  }

  Future<void> _ensureAlertsAnnotationManager() async {
    if (_mapboxMap == null ||
        !_isStyleLoaded ||
        _alertsAnnotationManager != null) {
      return;
    }

    _alertsAnnotationManager = await _mapboxMap!.annotations
        .createPointAnnotationManager(id: 'alerts-map-markers');

    _alertsAnnotationManager!.tapEvents(
      onTap: (annotation) {
        final rawId = annotation.customData?['alert_id'];
        final int? alertId;
        if (rawId is int) {
          alertId = rawId;
        } else if (rawId is num) {
          alertId = rawId.toInt();
        } else {
          alertId = null;
        }
        debugPrint('[MapView] marker tapped alertId=$alertId');
        if (alertId == null) return;

        final alerts = ref.read(alertsProvider).valueOrNull;
        if (alerts == null) return;

        try {
          final alert = alerts.firstWhere((a) => a.id == alertId);
          _openAlertDetails(alert);
        } catch (_) {
          // alert not found in current provider list
        }
      },
    );
  }

  void _openAlertDetails(Alert alert) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder:
          (_) => SizedBox(
            height: MediaQuery.of(context).size.height - 300,
            child: AlertDetailsBottomSheet(alert: alert),
          ),
    );
  }

  Future<Uint8List> _getMarkerBitmap() async {
    _markerBitmap ??= await _drawPinBitmap(AppColors.primary);
    return _markerBitmap!;
  }

  static Future<Uint8List> _drawPinBitmap(Color fill) async {
    const double w = 88.0;
    const double h = 112.0;
    const double r = 32.0;
    const double stroke = 5.0;
    const double cx = w / 2;
    const double cy = r + stroke + 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    final path =
        Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r))
          ..moveTo(cx - 18, cy + r - 10)
          ..lineTo(cx + 18, cy + r - 10)
          ..lineTo(cx, h - stroke)
          ..close();

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(cx, cy), 11.0, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _syncAlertMarkers(List<Alert> alerts) async {
    if (_mapboxMap == null || !_isStyleLoaded) {
      return;
    }

    await _ensureAlertsAnnotationManager();
    final manager = _alertsAnnotationManager;
    if (manager == null) {
      return;
    }

    final markers = alerts
        .map(_alertToMarker)
        .whereType<_AlertMarker>()
        .toList(growable: false);

    final renderedKey = markers
        .map(
          (marker) =>
              '${marker.alertId}:${marker.longitude.toStringAsFixed(6)}:${marker.latitude.toStringAsFixed(6)}',
        )
        .join('|');
    if (renderedKey == _lastRenderedAlertsKey) {
      return;
    }

    _lastRenderedAlertsKey = renderedKey;

    try {
      await manager.deleteAll();
      if (markers.isEmpty) {
        debugPrint('[MapView] rendered alerts on map count=0');
        return;
      }

      // Register the bitmap under a stable named ID so Mapbox never
      // garbage-collects the internal reference between renders.
      if (!_markerImageRegistered) {
        final bitmap = await _getMarkerBitmap();
        await _mapboxMap!.style.addStyleImage(
          _markerImageId,
          1.0,
          MbxImage(width: 88, height: 112, data: bitmap),
          false,
          [],
          [],
          null,
        );
        _markerImageRegistered = true;
      }

      await manager.createMulti(
        markers
            .map(
              (marker) => PointAnnotationOptions(
                geometry: Point(
                  coordinates: Position(marker.longitude, marker.latitude),
                ),
                iconImage: _markerImageId,
                iconAnchor: IconAnchor.BOTTOM,
                iconSize: 1.0,
                customData: {'alert_id': marker.alertId},
              ),
            )
            .toList(growable: false),
      );

      debugPrint('[MapView] rendered alerts on map count=${markers.length}');
    } catch (error) {
      debugPrint('[MapView] failed to render markers error=$error');
    }
  }

  _AlertMarker? _alertToMarker(Alert alert) {
    final location = alert.location;

    if (location is Map) {
      final coordinates = location['coordinates'];
      if (coordinates is List && coordinates.length >= 2) {
        final longitude = _asDouble(coordinates[0]);
        final latitude = _asDouble(coordinates[1]);
        if (_isValidLatLng(latitude, longitude)) {
          return _AlertMarker(
            alertId: alert.id,
            latitude: latitude!,
            longitude: longitude!,
          );
        }
      }

      final latitude = _asDouble(location['latitude'] ?? location['lat']);
      final longitude = _asDouble(
        location['longitude'] ?? location['lng'] ?? location['lon'],
      );
      if (_isValidLatLng(latitude, longitude)) {
        return _AlertMarker(
          alertId: alert.id,
          latitude: latitude!,
          longitude: longitude!,
        );
      }
    }

    if (location is String) {
      final point = RegExp(
        r'POINT\s*\(\s*([-+]?\d*\.?\d+)\s+([-+]?\d*\.?\d+)\s*\)',
        caseSensitive: false,
      ).firstMatch(location);
      if (point != null) {
        final longitude = double.tryParse(point.group(1)!);
        final latitude = double.tryParse(point.group(2)!);
        if (_isValidLatLng(latitude, longitude)) {
          return _AlertMarker(
            alertId: alert.id,
            latitude: latitude!,
            longitude: longitude!,
          );
        }
      }
    }

    return null;
  }

  bool _isValidLatLng(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return false;
    }
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  @override
  void dispose() {
    final map = _mapboxMap;
    final manager = _alertsAnnotationManager;
    if (map != null && manager != null) {
      unawaited(map.annotations.removeAnnotationManager(manager));
    }
    _markerBitmap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveLocation = ref.watch(locationProvider).valueOrNull;
    if (liveLocation != null) {
      _latestLocation = liveLocation;
      _centerOnDeviceIfReady();
    }

    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('alerts-mapbox-map'),
          cameraOptions: _initialCamera,
          styleUri: MapboxStyles.STANDARD,
          onMapCreated: (controller) {
            _mapboxMap = controller;
            _centerOnDeviceIfReady();
          },
          onStyleLoadedListener: (_) {
            _isStyleLoaded = true;
            _lastRenderedAlertsKey = '';
            _markerImageRegistered = false;
            _alertsAnnotationManager = null;
          },
          onCameraChangeListener:
              (cameraChangedEventData) => {
                print(
                  'Camera changed: ${cameraChangedEventData.cameraState.toString()}',
                ),
              },
        ),
        if (_resolvingDeviceLocation && !_centeredOnDevice)
          const Positioned(
            right: 16,
            top: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.topLeft,
          child: ElevatedButton(
            onPressed: _fetchingMapAlerts ? null : fetchAlertsInCurrentMapView,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.public_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _fetchingMapAlerts ? 'Loading area...' : 'Load this area',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlertMarker {
  const _AlertMarker({
    required this.alertId,
    required this.latitude,
    required this.longitude,
  });

  final int alertId;
  final double latitude;
  final double longitude;
}

class _MapboxSetupNotice extends StatelessWidget {
  const _MapboxSetupNotice({required this.text});

  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 56,
            color: AppColors.secondary.withOpacity(0.6),
          ),
          const SizedBox(height: 14),
          Text(
            'Mapbox token required',
            style: text.titleLarge?.copyWith(color: AppColors.neutral),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Run the app with --dart-define=MAPBOX_ACCESS_TOKEN=your_public_token to load the map.',
            style: text.bodyMedium?.copyWith(color: AppColors.neutral),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MapboxUnavailableNotice extends StatelessWidget {
  const _MapboxUnavailableNotice({required this.text});

  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_rounded,
            size: 56,
            color: AppColors.secondary.withOpacity(0.6),
          ),
          const SizedBox(height: 14),
          Text(
            'Map view is mobile-only for now',
            style: text.titleLarge?.copyWith(color: AppColors.neutral),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Open Alertly on iOS or Android to use the Mapbox map.',
            style: text.bodyMedium?.copyWith(color: AppColors.neutral),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
