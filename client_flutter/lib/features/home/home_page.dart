import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/supabase/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/alert.dart';
import '../alerts/data/alerts_repository.dart';
import '../alerts/users_received_alerts_provider.dart';
import 'widgets/alert_details_bottom_sheet.dart';
import 'widgets/alerts_map_sliver.dart';

// ─── category helpers ─────────────────────────────────────────────────────────

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

Color _severityColor(Alert alert) {
  if (alert.category == 'emergency') {
    return AppColors.danger;
  }
  if (alert.status == 'published') return AppColors.primary;
  if (alert.flagged) return AppColors.tertiary;
  return AppColors.neutral;
}

Color _severityBg(Alert alert) {
  if (alert.category == 'emergency') {
    return AppColors.danger.withOpacity(0.10);
  }
  if (alert.status == 'published') return AppColors.primary.withOpacity(0.10);

  if (alert.flagged) return AppColors.tertiary.withOpacity(0.10);
  return AppColors.neutral.withOpacity(0.10);
}

String _severityLabel(Alert alert) {
  if (alert.category == 'emergency') return 'CRITICAL';
  if (alert.status == 'published') return 'ACTIVE';
  if (alert.flagged) return 'FLAGGED';
  if (alert.status == 'pending') return 'PENDING';
  return alert.status?.toUpperCase() ?? 'UNKNOWN';
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().toUtc().difference(dt.toUtc());
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// ─── filter enum ─────────────────────────────────────────────────────────────

enum _Filter { district, proximity, time }

// ─── page ─────────────────────────────────────────────────────────────────────

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.deepLinkAlertId});

  final int? deepLinkAlertId;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _Filter _activeFilter = _Filter.district;
  int? _pendingDeepLinkAlertId;
  bool _handlingDeepLink = false;

  @override
  void initState() {
    super.initState();
    _pendingDeepLinkAlertId = widget.deepLinkAlertId;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.deepLinkAlertId != null &&
        widget.deepLinkAlertId != oldWidget.deepLinkAlertId) {
      _pendingDeepLinkAlertId = widget.deepLinkAlertId;
      _handlingDeepLink = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openAlertDetails(Alert alert) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlertDetailsBottomSheet(alert: alert),
    );
  }

  Alert? _findAlertById(List<Alert> alerts, int id) {
    for (final alert in alerts) {
      if (alert.id == id) {
        return alert;
      }
    }
    return null;
  }

  void _handlePendingDeepLink(List<Alert> alerts) {
    if (_handlingDeepLink || _pendingDeepLinkAlertId == null) {
      return;
    }

    _handlingDeepLink = true;
    final targetId = _pendingDeepLinkAlertId!;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      Alert? targetAlert = _findAlertById(alerts, targetId);

      if (targetAlert == null) {
        await ref.read(usersReceivedAlertsProvider.notifier).reload();
        final refreshedAlerts =
            ref.read(usersReceivedAlertsProvider).valueOrNull;
        if (refreshedAlerts != null) {
          targetAlert = _findAlertById(refreshedAlerts, targetId);
        }
      }

      if (targetAlert == null) {
        try {
          final client = ref.read(supabaseClientProvider);
          final repo = AlertsRepository(client, createApiClient());
          targetAlert = await repo.getAlertById(targetId);
        } catch (_) {
          targetAlert = null;
        }
      }

      _pendingDeepLinkAlertId = null;
      _handlingDeepLink = false;

      if (!mounted) return;

      if (targetAlert == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert not available anymore.')),
        );
        return;
      }

      await _openAlertDetails(targetAlert);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final alertsAsync = ref.watch(usersReceivedAlertsProvider);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── hero banner ───────────────────────────────────────────
                _HeroBanner(),
                const SizedBox(height: 20),

                // ── feed / map toggle ─────────────────────────────────────
                _TabToggle(controller: _tabController),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── tab content ──────────────────────────────────────────────────
          Expanded(
            child:
                _tabController.index == 0
                    ? RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh:
                          () =>
                              ref
                                  .read(usersReceivedAlertsProvider.notifier)
                                  .reload(),
                      child: CustomScrollView(
                        slivers: [
                          // ── feed body ────────────────────────────────────
                          alertsAsync.when(
                            loading:
                                () => const SliverFillRemaining(
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            error:
                                (e, _) => SliverFillRemaining(
                                  child: Center(
                                    child: Text(
                                      'Failed to load alerts. $e',
                                      style: text.bodyMedium,
                                    ),
                                  ),
                                ),
                            data: (alerts) {
                              _handlePendingDeepLink(alerts);
                              return alerts.isEmpty
                                  ? SliverFillRemaining(
                                    child: Center(
                                      child: Text(
                                        'No alerts in your area.',
                                        style: text.bodyMedium?.copyWith(
                                          color: AppColors.neutral,
                                        ),
                                      ),
                                    ),
                                  )
                                  : SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      24,
                                    ),
                                    sliver: SliverList.separated(
                                      itemCount: alerts.length,
                                      separatorBuilder:
                                          (_, __) => const SizedBox(height: 12),
                                      itemBuilder:
                                          (_, i) =>
                                              _AlertCard(alert: alerts[i]),
                                    ),
                                  );
                            },
                          ),
                        ],
                      ),
                    )
                    : const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: AlertsMapView(),
                    ),
          ),
        ],
      ),
    );
  }
}

// ─── hero banner ─────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
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
          // watermark icon
          Positioned(
            right: -8,
            bottom: -14,
            child: Icon(
              Icons.shield_outlined,
              size: 110,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stay Vigilant',
                style: text.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Real-time updates for a safer,\nmore connected neighborhood.',
                style: text.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.80),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'Emergency Protocol',
                  style: text.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── feed / map toggle ────────────────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  const _TabToggle({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(50),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.neutral,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [Tab(text: 'Feed'), Tab(text: 'Map')],
      ),
    );
  }
}

// ─── filter chips ─────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.active, required this.onChanged});
  final _Filter active;
  final ValueChanged<_Filter> onChanged;

  static const _items = [
    (_Filter.district, Icons.tune_rounded, 'District'),
    (_Filter.proximity, Icons.location_on_rounded, 'Proximity'),
    (_Filter.time, Icons.access_time_rounded, 'Time'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (filter, icon, label) in _items) ...[
          _FilterChip(
            icon: icon,
            label: label,
            selected: active == filter,
            onTap: () => onChanged(filter),
          ),
          if (filter != _Filter.time) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.secondary.withOpacity(0.25)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color:
                selected
                    ? AppColors.primary
                    : AppColors.secondary.withOpacity(0.55),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? AppColors.primary : AppColors.neutral,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── alert card ──────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});
  final Alert alert;

  void _openDetails(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = _severityColor(alert);
    final bgColor = _severityBg(alert);
    final label = _severityLabel(alert);
    final icon = _categoryIcon(alert.category);
    final timeText = _timeAgo(alert.publishedAt ?? alert.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetails(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── severity bar ─────────────────────────────────────────────
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),

                // ── body ────────────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // top row: icon + status badge + time
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icon, size: 20, color: color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    alert.title ?? 'Untitled alert',
                                    style: text.titleMedium,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeText,
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.neutral,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        // body text
                        if (alert.body != null && alert.body!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            alert.body!,
                            style: text.bodyMedium?.copyWith(
                              color: AppColors.ink.withOpacity(0.75),
                              height: 1.45,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        // divider + footer
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.divider),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 15,
                              color: AppColors.neutral,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Comments',
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.neutral,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Details  ↗',
                              style: text.labelMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
