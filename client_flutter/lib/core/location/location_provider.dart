import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/users/data/users_repository.dart';
import '../supabase/supabase_provider.dart';

final locationProvider = AsyncNotifierProvider<LocationNotifier, UserLocation?>(
  LocationNotifier.new,
);

class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime capturedAt;
}

class LocationNotifier extends AsyncNotifier<UserLocation?> {
  UsersRepository get _usersRepo {
    final client = ref.read(supabaseClientProvider);
    return UsersRepository(client);
  }

  @override
  Future<UserLocation?> build() async {
    return null;
  }

  Future<UserLocation> refreshCurrentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Location services are disabled on this device.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is denied.');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );

    final location = UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      capturedAt: DateTime.now().toUtc(),
    );

    state = AsyncData(location);
    return location;
  }

  Future<UserLocation?> refreshAndSyncUserLocation(int userId) async {
    final location = await refreshCurrentLocation();

    final updatedUsers = await _usersRepo.updateUsers(
      payload: {
        'location':
            'SRID=4326;POINT(${location.longitude} ${location.latitude})',
        'location_updated_at': location.capturedAt.toIso8601String(),
      },
      filters: {'id': userId},
    );

    if (updatedUsers.isEmpty) {
      throw Exception(
        'Location sync updated 0 rows for user $userId. '
        'Check users.auth_id mapping and RLS update policy.',
      );
    }

    return location;
  }
}
