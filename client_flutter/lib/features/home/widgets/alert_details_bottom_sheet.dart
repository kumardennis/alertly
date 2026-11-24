import 'package:alertly/features/alerts/users_received_alerts_provider.dart';
import 'package:alertly/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/maps/alert_map_marker.dart';
import '../../../core/network/api_client.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/alert.dart';
import '../../alerts/data/alerts_repository.dart';
import '../../alerts/alerts_provider.dart';
import '../../users/profile_provider.dart';

class AlertDetailsBottomSheet extends ConsumerStatefulWidget {
  const AlertDetailsBottomSheet({super.key, required this.alert});

  final Alert alert;

  @override
  ConsumerState<AlertDetailsBottomSheet> createState() =>
      _AlertDetailsBottomSheetState();
}

class _AlertDetailsBottomSheetState
    extends ConsumerState<AlertDetailsBottomSheet> {
  bool _resolving = false;
  bool _verifying = false;
  bool _verifiedByCurrentUserJustNow = false;
  bool _loadingCoordinates = false;
  Map<String, double>? _coordinates;

  @override
  void initState() {
    super.initState();
    _loadCoordinates();
  }

  Future<void> _loadCoordinates() async {
    setState(() => _loadingCoordinates = true);

    try {
      final client = ref.read(supabaseClientProvider);
      final repo = AlertsRepository(client, createApiClient());
      final coordinates = await repo.getAlertLocation(alertId: widget.alert.id);

      if (!mounted) return;
      setState(() => _coordinates = coordinates);
    } catch (_) {
      // Keep silent and fall back to existing location label.
    } finally {
      if (mounted) {
        setState(() => _loadingCoordinates = false);
      }
    }
  }

  String _reportedLabel(DateTime reportedAt) {
    if (_loadingCoordinates) {
      return 'Locating… • Reported ${_timeAgo(reportedAt)}';
    }
    if (_coordinates == null) {
      return 'Location unavailable • Reported ${_timeAgo(reportedAt)}';
    }
    return 'Reported ${_timeAgo(reportedAt)}';
  }

  Future<void> _openCoordinatesInMaps() async {
    final coordinates = _coordinates;
    if (coordinates == null) {
      return;
    }

    final lat = coordinates['latitude'];
    final lng = coordinates['longitude'];
    if (lat == null || lng == null) {
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    final didLaunch = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!didLaunch && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open maps app.')));
    }
  }

  Future<void> _resolveAlert() async {
    if (_resolving) return;

    setState(() => _resolving = true);
    try {
      await ref
          .read(alertsProvider.notifier)
          .updateAlert(id: widget.alert.id, payload: {'status': 'resolved'});
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert marked as resolved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to resolve alert: $e')));
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final text = Theme.of(context).textTheme;
    final reportedAt = alert.publishedAt ?? alert.createdAt;
    final creatorUsername = alert.creator?.username.trim();
    final profile = ref.watch(profileProvider).valueOrNull;
    final canResolve =
        profile != null &&
        alert.userId == profile.id &&
        (alert.status?.toLowerCase() != 'resolved');

    final createdByCurrentUser = profile != null && alert.userId == profile.id;
    final verifiedRows =
        alert.verifications.where((item) => item.verified != false).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _AlertLocationPreview(
                alert: alert,
                reportedLabel: _reportedLabel(reportedAt),
                loadingCoordinates: _loadingCoordinates,
                coordinates: _coordinates,
                onOpenMaps: _openCoordinatesInMaps,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _prettyCategory(alert.category),
                          style: text.titleLarge?.copyWith(
                            color:
                                alert.tier == 4
                                    ? AppColors.danger
                                    : AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          ' • ',
                          style: text.titleLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          alert.status != null
                              ? alert.status!.toLowerCase()
                              : 'status unknown',
                          style: text.titleLarge?.copyWith(
                            color: AppColors.primary.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatusMetricCard(
                            label: 'Tier Level',
                            value: _severityLevel(alert),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatusMetricCard(
                            label: 'Impact Radius',
                            value: _radiusLabel(alert.radiusM),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (profile != null)
                      _CommunityVerificationCard(
                        verifications: verifiedRows,
                        profile: profile,
                        forceAlreadyVerified: _verifiedByCurrentUserJustNow,
                        disabled: createdByCurrentUser || _verifying,
                        onVerify: () async {
                          if (_verifying) return;

                          setState(() => _verifying = true);
                          try {
                            await ref
                                .read(alertsProvider.notifier)
                                .verifyAlert(alert.id);
                            await ref
                                .read(usersReceivedAlertsProvider.notifier)
                                .reload();
                            if (!mounted) return;
                            setState(() {
                              _verifiedByCurrentUserJustNow = true;
                            });
                            final messenger = ScaffoldMessenger.maybeOf(
                              context,
                            );
                            Navigator.of(context).pop();
                            messenger?.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Thanks. Your verification was recorded.',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Verification failed: $e'),
                              ),
                            );
                          } finally {
                            if (mounted) setState(() => _verifying = false);
                          }
                        },
                      )
                    else
                      const SizedBox.shrink(),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        alert.body?.isNotEmpty == true
                            ? alert.body!
                            : 'No additional description provided for this alert.',
                        style: text.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.90),
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    _InfoRow(
                      label: 'Published at',
                      value:
                          alert.publishedAt != null
                              ? _formatDateTime(alert.publishedAt!)
                              : 'Not published yet',
                    ),
                    if (creatorUsername != null && creatorUsername.isNotEmpty)
                      _InfoRow(label: 'Creator', value: '@$creatorUsername'),
                    if (canResolve) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient:
                                _resolving ? null : AppColors.primaryGradient,
                            color:
                                _resolving
                                    ? AppColors.primary.withOpacity(0.6)
                                    : null,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _resolving ? null : _resolveAlert,
                            icon:
                                _resolving
                                    ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.surface,
                                            ),
                                      ),
                                    )
                                    : const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.surface,
                                    ),
                            label: Text(
                              _resolving ? 'Resolving...' : 'Mark as Resolved',
                              style: text.labelLarge?.copyWith(
                                color: AppColors.surface,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _prettyCategory(String category) {
    if (category.isEmpty) return 'General';
    return '${category[0].toUpperCase()}${category.substring(1)}';
  }

  String _severityLevel(Alert item) {
    final tierLabel = item.tierInfo?.priority;
    debugPrint('Alert ${item.id} has tier label: $tierLabel, ${item.tierInfo}');
    switch (tierLabel) {
      case 'low':
        return 'Low';
      case 'medium':
        return 'Medium';
      case 'high':
        return 'High';
      case 'emergency':
        return 'Emergency';
    }
    return tierLabel ?? 'Unknown';
  }

  String _radiusLabel(int? radiusM) {
    if (radiusM == null || radiusM <= 0) {
      return 'N/A';
    }
    if (radiusM >= 1000) {
      final km = radiusM / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
    return '$radiusM m';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }
}

class _CommunityVerificationCard extends StatelessWidget {
  const _CommunityVerificationCard({
    required this.verifications,
    required this.onVerify,
    required this.profile,
    this.forceAlreadyVerified = false,
    this.disabled = false,
  });

  final List<AlertVerification> verifications;
  final VoidCallback onVerify;
  final AppUser profile;
  final bool forceAlreadyVerified;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final currentUserAlreadySeenThis =
        forceAlreadyVerified ||
        verifications.any((item) => item.userId == profile.id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Verified by',
                style: text.titleMedium?.copyWith(
                  color:
                      verifications.isNotEmpty
                          ? AppColors.primary
                          : AppColors.neutral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              ...verifications.asMap().entries.map((entry) {
                final index = entry.key;
                final verification = entry.value;
                final user = verification.users;
                final firstName = user?.firstName?.trim() ?? '';
                final lastName = user?.lastName?.trim() ?? '';
                final initials =
                    firstName.isNotEmpty || lastName.isNotEmpty
                        ? '${firstName.isNotEmpty ? firstName[0] : '?'}${lastName.isNotEmpty ? lastName[0] : '?'}'
                        : '??';
                return _WitnessAvatar(
                  initials: initials,
                  offsetLeft: index == 0 ? 0 : -20.0 * index,
                );
              }).toList(),
              if (verifications.length > 2)
                _WitnessCountBadge(count: verifications.length - 2),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  verifications.isNotEmpty
                      ? 'Witnesses nearby'
                      : 'No one yet :(',
                  style: text.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!disabled)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    disabled || currentUserAlreadySeenThis ? null : onVerify,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.surface,
                  disabledForegroundColor: AppColors.primary.withOpacity(0.6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  currentUserAlreadySeenThis
                      ? 'Already verified'
                      : 'I can see this',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WitnessAvatar extends StatelessWidget {
  const _WitnessAvatar({required this.initials, required this.offsetLeft});

  final String initials;
  final double offsetLeft;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offsetLeft, 0),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _WitnessCountBadge extends StatelessWidget {
  const _WitnessCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-20, 0),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '+$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMetricCard extends StatelessWidget {
  const _StatusMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: text.labelMedium?.copyWith(
              color: AppColors.primary.withOpacity(0.85),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: text.headlineMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 25,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: AppColors.neutral),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: text.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertLocationPreview extends StatelessWidget {
  const _AlertLocationPreview({
    required this.alert,
    required this.reportedLabel,
    required this.loadingCoordinates,
    required this.coordinates,
    required this.onOpenMaps,
  });

  final Alert alert;
  final String reportedLabel;
  final bool loadingCoordinates;
  final Map<String, double>? coordinates;
  final VoidCallback onOpenMaps;

  static const double _height = 220;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canOpenMaps = coordinates != null && !loadingCoordinates;
    final tierAccent = AlertMapMarkerStyle.tierColor(alert.tier);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canOpenMaps ? onOpenMaps : null,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: _height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: tierAccent.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dpr = MediaQuery.devicePixelRatioOf(context);
                final mapWidth = constraints.maxWidth.round().clamp(1, 1280);
                final mapHeight = _height.round();
                final lat = coordinates?['latitude'];
                final lng = coordinates?['longitude'];
                final mapUrl =
                    (lat != null &&
                            lng != null &&
                            AppConfig.hasMapboxAccessToken)
                        ? buildAlertStaticMapUrl(
                          latitude: lat,
                          longitude: lng,
                          width: mapWidth,
                          height: mapHeight,
                          pixelRatio: dpr,
                        )
                        : null;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildMapBackground(mapUrl: mapUrl, tierAccent: tierAccent),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x99000000),
                            Color(0x40000000),
                            Color(0xCC000000),
                          ],
                          stops: [0, 0.45, 1],
                        ),
                      ),
                    ),
                    if (!loadingCoordinates && coordinates != null)
                      Center(
                        child: IgnorePointer(
                          child: PulsingAlertMapMarker(
                            tier: alert.tier,
                            category: alert.category,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.title ?? 'Untitled alert',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              fontSize: 24,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(
                                Icons.near_me_rounded,
                                size: 18,
                                color:
                                    canOpenMaps
                                        ? AppColors.secondary
                                        : Colors.white.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  reportedLabel,
                                  style: text.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (canOpenMaps)
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '© Mapbox © OpenStreetMap',
                            style: text.labelMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (loadingCoordinates)
                      const ColoredBox(
                        color: Color(0x33000000),
                        child: Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapBackground({
    required String? mapUrl,
    required Color tierAccent,
  }) {
    if (mapUrl == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, tierAccent],
          ),
        ),
      );
    }

    return Image.network(
      mapUrl,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder:
          (context, error, stackTrace) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, tierAccent],
              ),
            ),
          ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ColoredBox(
          color: AppColors.secondary.withValues(alpha: 0.35),
          child: const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        );
      },
    );
  }
}
