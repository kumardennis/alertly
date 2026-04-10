import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/session_provider.dart';
import '../../core/notifications/notification_permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../users/data/users_devices_repository.dart';
import 'onboarding_provider.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _ageController;
  late final TextEditingController _preferredRadiusController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingProvider).draft;
    _firstNameController = TextEditingController(text: draft.firstName);
    _lastNameController = TextEditingController(text: draft.lastName);
    _usernameController = TextEditingController(text: draft.username);
    _ageController = TextEditingController(
      text: draft.age == null ? '' : draft.age.toString(),
    );
    _preferredRadiusController = TextEditingController(
      text: draft.preferredRadiusM.toString(),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _ageController.dispose();
    _preferredRadiusController.dispose();
    super.dispose();
  }

  void _clearErrorIfNeeded() {
    final notifier = ref.read(onboardingProvider.notifier);
    final error = ref.read(onboardingProvider).error;
    if (error != null) {
      notifier.clearError();
    }
  }

  Future<void> _submit() async {
    final user = await ref.read(onboardingProvider.notifier).submit();
    if (!mounted) return;
    if (user != null) {
      final settings = await NotificationPermissionService.request();
      if (!mounted) return;

      if (NotificationPermissionService.isGranted(settings)) {
        final token = await NotificationPermissionService.getFcmToken();
        if (token != null && token.isNotEmpty) {
          final devicesRepo = UsersDevicesRepository(Supabase.instance.client);
          final platform = NotificationPermissionService.currentPlatform();
          await devicesRepo.upsertDeviceForUser(
            userId: user.id,
            fcmToken: token,
            platform: platform,
          );
        }
      }

      if (!NotificationPermissionService.isGranted(settings)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are off. You can enable them later in settings.',
            ),
          ),
        );
      }

      context.go('/');
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(sessionProvider.notifier).signOut();
      if (mounted) {
        context.go('/login');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sign out failed: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final state = ref.watch(onboardingProvider);
    final draft = state.draft;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.secondary.withOpacity(0.20),
                    AppColors.background,
                    AppColors.primary.withOpacity(0.12),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -30,
            child: Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.28),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -70,
            child: Container(
              height: 260,
              width: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.16),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.94),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text('Set up account', style: text.labelLarge),
                          ],
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: state.submitting ? null : _signOut,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.tertiary,
                        ),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text('Finish your profile', style: text.displaySmall),
                  const SizedBox(height: 10),
                  Text(
                    'Choose the identity other people will see when you post or interact in the app.',
                    style: text.bodyLarge?.copyWith(
                      color: AppColors.ink.withOpacity(0.72),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.secondary.withOpacity(0.45),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 52,
                                width: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _initialsFor(draft),
                                  style: text.titleLarge?.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Preview', style: text.labelMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      _displayNameFor(draft),
                                      style: text.titleLarge,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      draft.username.trim().isEmpty
                                          ? '@username'
                                          : '@${draft.username.trim().toLowerCase()}',
                                      style: text.bodyMedium?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _LabeledField(
                                label: 'First Name',
                                hint: 'Maya',
                                controller: _firstNameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                onChanged: (value) {
                                  _clearErrorIfNeeded();
                                  ref
                                      .read(onboardingProvider.notifier)
                                      .updateFirstName(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LabeledField(
                                label: 'Last Name',
                                hint: 'Laanemets',
                                controller: _lastNameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                onChanged: (value) {
                                  _clearErrorIfNeeded();
                                  ref
                                      .read(onboardingProvider.notifier)
                                      .updateLastName(value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _LabeledField(
                          label: 'Username',
                          hint: 'hoodwatcher',
                          controller: _usernameController,
                          prefixText: '@',
                          textInputAction: TextInputAction.next,
                          onChanged: (value) {
                            _clearErrorIfNeeded();
                            ref
                                .read(onboardingProvider.notifier)
                                .updateUsername(value.trim().toLowerCase());
                          },
                        ),
                        const SizedBox(height: 14),
                        _LabeledField(
                          label: 'Age',
                          hint: 'Optional',
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          onChanged: (value) {
                            _clearErrorIfNeeded();
                            final age =
                                value.trim().isEmpty
                                    ? null
                                    : int.tryParse(value.trim());
                            ref
                                .read(onboardingProvider.notifier)
                                .updateAge(age);
                          },
                          onSubmitted:
                              (_) => state.submitting ? null : _submit(),
                        ),
                        const SizedBox(height: 16),
                        _LabeledField(
                          label: 'Preferred Alert Radius (meters)',
                          hint: 'Required',
                          controller: _preferredRadiusController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          onChanged: (value) {
                            _clearErrorIfNeeded();
                            final radius =
                                value.trim().isEmpty
                                    ? null
                                    : int.tryParse(value.trim());
                            ref
                                .read(onboardingProvider.notifier)
                                .updatePreferredRadius(radius);
                          },
                          onSubmitted:
                              (_) => state.submitting ? null : _submit(),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _InfoChip(
                              icon: Icons.visibility_rounded,
                              label: 'Public username',
                            ),
                            _InfoChip(
                              icon: Icons.lock_outline_rounded,
                              label: 'Phone stays private',
                            ),
                            _InfoChip(
                              icon: Icons.edit_note_rounded,
                              label: 'You can edit later',
                            ),
                          ],
                        ),
                        if (state.error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.tertiary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.tertiary.withOpacity(0.28),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    color: AppColors.tertiary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    state.error!,
                                    style: text.bodyMedium?.copyWith(
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                state.submitting || !draft.isValid
                                    ? null
                                    : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.surface,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            icon:
                                state.submitting
                                    ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.surface,
                                            ),
                                      ),
                                    )
                                    : const Icon(
                                      Icons.check_circle_outline_rounded,
                                    ),
                            label: Text(
                              state.submitting
                                  ? 'Creating account...'
                                  : 'Complete setup',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _initialsFor(OnboardingDraft draft) {
  final first = draft.firstName.trim();
  final last = draft.lastName.trim();
  final chars =
      [
        if (first.isNotEmpty) first.substring(0, 1),
        if (last.isNotEmpty) last.substring(0, 1),
      ].join();

  if (chars.isNotEmpty) {
    return chars.toUpperCase();
  }

  final username = draft.username.trim();
  if (username.isNotEmpty) {
    return username.substring(0, 1).toUpperCase();
  }

  return 'HC';
}

String _displayNameFor(OnboardingDraft draft) {
  final fullName = [
    draft.firstName.trim(),
    draft.lastName.trim().isNotEmpty
        ? draft.lastName.trim().substring(0, 1).toUpperCase()
        : '',
  ].where((part) => part.isNotEmpty).join(' ');
  return fullName.isNotEmpty ? fullName : 'Your public profile';
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.inputFormatters,
    this.prefixText,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.neutral),
            prefixText: prefixText,
            prefixStyle: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.secondary.withOpacity(0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(label, style: text.labelMedium?.copyWith(color: AppColors.ink)),
        ],
      ),
    );
  }
}
