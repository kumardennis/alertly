import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_user.dart';
import '../../core/supabase/supabase_provider.dart';
import '../users/data/users_repository.dart';

final profileProvider = AsyncNotifierProvider<ProfileNotifier, AppUser?>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<AppUser?> {
  late final UsersRepository _repo;

  @override
  Future<AppUser?> build() async {
    final client = ref.watch(supabaseClientProvider);
    _repo = UsersRepository(client);

    final authId = client.auth.currentUser?.id;
    if (authId == null) return null;

    return _fetchProfile(authId, client);
  }

  Future<AppUser?> _fetchProfile(String authId, SupabaseClient client) async {
    final rows = await _repo.getUsers(filters: {'auth_id': authId}, limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> reload() async {
    final client = ref.read(supabaseClientProvider);
    final authId = client.auth.currentUser?.id;
    if (authId == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchProfile(authId, client));
  }

  void setProfile(AppUser profile) {
    state = AsyncData(profile);
  }

  void clear() {
    state = const AsyncData(null);
  }
}
