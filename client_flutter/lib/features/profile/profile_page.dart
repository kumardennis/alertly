import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/session_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/alert.dart';
import '../../models/app_user.dart';
import '../home/widgets/alert_details_bottom_sheet.dart';
import '../users/profile_provider.dart';
import 'profile_alerts_provider.dart';

// ─── helpers ─────────────────────────────────────────────────────────────────

String _rankLabel(int? repScore) {
  final s = repScore ?? 0;
  if (s >= 5000) return 'ELITE SENTINEL';
  if (s >= 1000) return 'DIAMOND SENTINEL';
  if (s >= 500) return 'GOLD SENTINEL';
  if (s >= 100) return 'SILVER SENTINEL';
  return 'COMMUNITY SCOUT';
}

IconData _categoryIcon(String category) {
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

Color _categoryColor(String category, String status, bool flagged) {
  if (category == 'emergency') return AppColors.danger;
  if (status == 'resolved') return AppColors.neutral;
  if (flagged && status != 'published') return AppColors.tertiary;
  return AppColors.primary;
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().toUtc().difference(dt.toUtc());
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String _formatDate(DateTime dt) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

// ─── page ────────────────────────────────────────────────────────────────────

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(profileProvider.notifier).reload(),
      ref.refresh(profileAlertsProvider.future),
      ref.refresh(profileVerificationsCountProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final alertsAsync = ref.watch(profileAlertsProvider);
    final verificationsCountAsync = ref.watch(
      profileVerificationsCountProvider,
    );

    return SafeArea(
      child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _refresh(ref),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── app bar ──────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Alertly Profile',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),

                // ── profile header ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _ProfileHeader(user: user),
                  ),
                ),

                // ── metrics ──────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _MetricsRow(
                      alertsAsync: alertsAsync,
                      verificationsCountAsync: verificationsCountAsync,
                    ),
                  ),
                ),

                // ── recent contributions ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Text(
                      'Recent Contributions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _RecentContributions(alertsAsync: alertsAsync),
                ),

                // ── account settings ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                    child: _AccountSettings(user: user),
                  ),
                ),

                // ── footer ───────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    child: _Footer(user: user, ref: ref),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── profile header ──────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -8,
            bottom: -14,
            child: Icon(
              Icons.shield_outlined,
              size: 120,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // avatar placeholder
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // display name
              Text(
                user.displayName,
                style: text.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),

              // rank badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.white.withOpacity(0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _rankLabel(user.repScore),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── metrics row ─────────────────────────────────────────────────────────────

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.alertsAsync,
    required this.verificationsCountAsync,
  });
  final AsyncValue<List<Alert>> alertsAsync;
  final AsyncValue<int> verificationsCountAsync;

  @override
  Widget build(BuildContext context) {
    final alertCount = alertsAsync.valueOrNull?.length ?? 0;
    final verificationCount = verificationsCountAsync.valueOrNull ?? 0;

    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Icons.campaign_rounded,
            label: 'ALERTS CREATED',
            value: alertsAsync.isLoading ? '—' : '$alertCount',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            icon: Icons.verified_user_rounded,
            label: 'VERIFICATIONS',
            value:
                verificationsCountAsync.isLoading ? '—' : '$verificationCount',
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            label,
            style: text.labelMedium?.copyWith(fontSize: 11, letterSpacing: 0.6),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: text.headlineMedium?.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── recent contributions ────────────────────────────────────────────────────

class _RecentContributions extends StatelessWidget {
  const _RecentContributions({required this.alertsAsync});
  final AsyncValue<List<Alert>> alertsAsync;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return alertsAsync.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Could not load contributions.',
              style: text.bodyMedium,
            ),
          ),
      data: (alerts) {
        if (alerts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'No contributions yet.',
              style: text.bodyMedium?.copyWith(color: AppColors.neutral),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              for (int i = 0; i < alerts.length; i++) ...[
                _ContributionCard(alert: alerts[i]),
                if (i < alerts.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ContributionCard extends StatelessWidget {
  const _ContributionCard({required this.alert});
  final Alert alert;

  void _openDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder:
          (_) => SizedBox(
            height: MediaQuery.of(context).size.height - 350,
            child: AlertDetailsBottomSheet(alert: alert),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = _categoryColor(
      alert.category,
      alert.status ?? 'pending',
      alert.flagged,
    );
    final icon = _categoryIcon(alert.category);
    final timeText = _timeAgo(alert.publishedAt ?? alert.createdAt);
    final statusLabel = (alert.status ?? 'pending').toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // category icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 12),

              // content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            alert.title ?? 'Untitled alert',
                            style: text.titleMedium?.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeText,
                          style: text.bodyMedium?.copyWith(
                            fontSize: 11,
                            color: AppColors.neutral,
                          ),
                        ),
                      ],
                    ),
                    if (alert.body != null && alert.body!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        alert.body!,
                        style: text.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: AppColors.ink.withOpacity(0.65),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    // status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.5,
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
    );
  }
}

// ─── account settings ────────────────────────────────────────────────────────

class _AccountSettings extends StatelessWidget {
  const _AccountSettings({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'ACCOUNT SETTINGS',
            style: text.labelMedium?.copyWith(letterSpacing: 0.8, fontSize: 11),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.notifications_outlined,
                label: 'Notification Preferences',
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56, color: AppColors.divider),
              _SettingsRow(
                icon: Icons.lock_outline_rounded,
                label: 'Privacy',
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56, color: AppColors.divider),
              _SettingsRow(
                icon: Icons.gps_fixed_rounded,
                label: 'Vigilance Radius',
                badge:
                    user.preferredRadiusM >= 1000
                        ? '${(user.preferredRadiusM / 1000).toStringAsFixed(1)} km'
                        : '${user.preferredRadiusM} m',
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56, color: AppColors.divider),
              _SettingsRow(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.neutral),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: text.bodyLarge?.copyWith(fontSize: 15)),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  badge!,
                  style: text.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.neutral,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── footer ──────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.user, required this.ref});
  final AppUser user;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Member Since',
                style: text.labelMedium?.copyWith(
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(user.createdAt),
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger.withOpacity(0.10),
              foregroundColor: AppColors.danger,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () async {
              await ref.read(sessionProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
