import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../models/app_user.dart';
import '../users/data/users_repository.dart';
import '../users/profile_provider.dart';

// ---------------------------------------------------------------------------
// Draft state
// ---------------------------------------------------------------------------

class OnboardingDraft {
  const OnboardingDraft({
    this.firstName = '',
    this.lastName = '',
    this.username = '',
    this.age,
    this.preferredRadiusM = 2000,
  });

  final String firstName;
  final String lastName;
  final String username;
  final int? age;
  final int preferredRadiusM;

  OnboardingDraft copyWith({
    String? firstName,
    String? lastName,
    String? username,
    int? age,
    int? preferredRadiusM,
  }) {
    return OnboardingDraft(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      age: age ?? this.age,
      preferredRadiusM: preferredRadiusM ?? this.preferredRadiusM,
    );
  }

  bool get isValid =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      username.trim().isNotEmpty;

  Map<String, dynamic> toPayload(String authId) => {
    'auth_id': authId,
    'first_name': firstName.trim(),
    'last_name': lastName.trim(),
    'username': username.trim().toLowerCase(),
    'preferred_radius_m': preferredRadiusM,
    if (age != null) 'age': age,
  };
}

// ---------------------------------------------------------------------------
// Provider state wrapper
// ---------------------------------------------------------------------------

class OnboardingState {
  const OnboardingState({
    this.draft = const OnboardingDraft(),
    this.submitting = false,
    this.error,
  });

  final OnboardingDraft draft;
  final bool submitting;
  final String? error;

  OnboardingState copyWith({
    OnboardingDraft? draft,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) {
    return OnboardingState(
      draft: draft ?? this.draft,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier / controller
// ---------------------------------------------------------------------------

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
      OnboardingNotifier.new,
    );

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void updateFirstName(String value) =>
      state = state.copyWith(draft: state.draft.copyWith(firstName: value));

  void updateLastName(String value) =>
      state = state.copyWith(draft: state.draft.copyWith(lastName: value));

  void updateUsername(String value) =>
      state = state.copyWith(draft: state.draft.copyWith(username: value));

  void updateAge(int? value) =>
      state = state.copyWith(draft: state.draft.copyWith(age: value));

  void updatePreferredRadius(int? value) =>
      state = state.copyWith(
        draft: state.draft.copyWith(preferredRadiusM: value),
      );

  Future<AppUser?> submit() async {
    if (!state.draft.isValid) {
      state = state.copyWith(error: 'Please fill in all required fields.');
      return null;
    }

    final client = ref.read(supabaseClientProvider);
    final authId = client.auth.currentUser?.id;

    if (authId == null) {
      state = state.copyWith(error: 'Not authenticated. Please sign in again.');
      return null;
    }

    state = state.copyWith(submitting: true, clearError: true);

    try {
      final repo = UsersRepository(client);
      final profile = await repo.createUser(state.draft.toPayload(authId));
      ref.read(profileProvider.notifier).setProfile(profile);
      return profile;
    } catch (e) {
      state = state.copyWith(submitting: false, error: e.toString());
      return null;
    } finally {
      state = state.copyWith(submitting: false);
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  void reset() => state = const OnboardingState();
}
