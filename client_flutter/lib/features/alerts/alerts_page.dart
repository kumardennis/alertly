import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/location_provider.dart';
import '../../core/theme/app_theme.dart';
import '../users/profile_provider.dart';
import 'alerts_provider.dart';
import 'widgets/alert_category_card.dart';

// ─── category meta ────────────────────────────────────────────────────────────

class _CategoryMeta {
  const _CategoryMeta(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}

const _categories = [
  _CategoryMeta('emergency', 'Emergency', Icons.local_fire_department_rounded),
  _CategoryMeta('crime', 'Crime', Icons.gpp_bad_rounded),
  _CategoryMeta('infrastructure', 'Infrastructure', Icons.construction_rounded),
  _CategoryMeta('weather', 'Weather', Icons.cloud_rounded),
  _CategoryMeta('civic', 'Civic', Icons.account_balance_rounded),
  _CategoryMeta('community', 'Community', Icons.groups_rounded),
  _CategoryMeta('other', 'Other', Icons.more_horiz_rounded),
];

// ─── step meta ────────────────────────────────────────────────────────────────

const _stepLabels = ['Category', 'Narrative', 'Location'];
const _stepTitles = [
  'Incident Classification',
  'Tell the Story',
  'Pin the Location',
];
const _stepSubtitles = [
  'What did you observe in your vicinity?',
  'Describe what happened in detail.',
  'Where did this take place?',
];

// ─── page ─────────────────────────────────────────────────────────────────────

class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  int _step = 0;
  String _category = 'emergency';
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _radiusController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLocationLoaded();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _radiusController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  bool get _stepValid {
    switch (_step) {
      case 0:
        return true;
      case 1:
        return _titleController.text.trim().isNotEmpty;
      case 2:
        return double.tryParse(_latController.text.trim()) != null &&
            double.tryParse(_lngController.text.trim()) != null;
      default:
        return false;
    }
  }

  void _applyLocation(UserLocation location) {
    final nextLat = location.latitude.toStringAsFixed(6);
    final nextLng = location.longitude.toStringAsFixed(6);
    if (_latController.text == nextLat && _lngController.text == nextLng) {
      return;
    }
    _latController.text = nextLat;
    _lngController.text = nextLng;
  }

  Future<void> _ensureLocationLoaded() async {
    final existing = ref.read(locationProvider).valueOrNull;
    if (existing != null) {
      _applyLocation(existing);
      return;
    }

    try {
      final location =
          await ref.read(locationProvider.notifier).refreshCurrentLocation();
      if (!mounted) return;
      _applyLocation(location);
      setState(() => _error = null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  void _goNext() {
    if (!_stepValid) {
      if (_step == 1) setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _error = null;
      _step++;
    });
  }

  void _goBack() {
    if (_step > 0) {
      setState(() {
        _step--;
        _error = null;
      });
    }
  }

  Widget _buildNavigationRow() {
    return Row(
      children: [
        if (_step > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _submitting ? null : _goBack,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.secondary.withOpacity(0.6)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child:
              _step < 2
                  ? _buildPrimaryActionButton(
                    onPressed: _stepValid ? _goNext : null,
                    child: const Text('Next'),
                  )
                  : _buildPrimaryActionButton(
                    onPressed: _submitting || !_stepValid ? null : _submit,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _submitting
                            ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.surface,
                                ),
                              ),
                            )
                            : const Icon(
                              Icons.send_rounded,
                              color: AppColors.secondary,
                            ),
                        const SizedBox(width: 8),
                        Text(_submitting ? 'Posting…' : 'Post alert'),
                      ],
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActionButton({
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? AppColors.primaryGradient : null,
        color: enabled ? null : AppColors.primary.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: AppColors.surface.withOpacity(0.70),
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: child,
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final radiusRaw = _radiusController.text.trim();
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (lat == null || lng == null) {
      setState(() => _error = 'Enter valid latitude and longitude.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final profile = ref.read(profileProvider).valueOrNull;

      if (profile == null) {
        // throw Exception('User profile not found. Please log in again.');
        setState(() => _error = 'User profile not found. Please log in again.');
        return;
      }
      final payload = <String, dynamic>{
        'category': _category,
        'title': title,
        if (body.isNotEmpty) 'message': body,
        'locationLatitude': lat.toString(),
        'locationLongitude': lng.toString(),
        if (radiusRaw.isNotEmpty) 'radius_m': int.tryParse(radiusRaw),
        if (profile != null) 'userId': profile.id,
      };

      await ref.read(alertsProvider.notifier).createAlert(payload);

      if (!mounted) return;
      _titleController.clear();
      _bodyController.clear();
      _radiusController.clear();
      _latController.clear();
      _lngController.clear();
      setState(() {
        _category = 'emergency';
        _step = 0;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alert posted!')));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildStepContent() {
    final locationState = ref.watch(locationProvider);
    locationState.whenData((location) {
      if (location != null) {
        _applyLocation(location);
      }
    });

    switch (_step) {
      case 0:
        return GridView.count(
          key: const ValueKey(0),
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            for (final cat in _categories)
              AlertCategoryCard(
                label: cat.label,
                icon: cat.icon,
                selected: _category == cat.value,
                onTap: () => setState(() => _category = cat.value),
              ),
          ],
        );
      case 1:
        return _StepCard(
          key: const ValueKey(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LabeledField(
                label: 'Title',
                hint: 'Short description of the incident',
                controller: _titleController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Details (optional)',
                hint: 'Add more context for your neighbours…',
                controller: _bodyController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {},
              ),
            ],
          ),
        );
      case 2:
        return _StepCard(
          key: const ValueKey(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (locationState.isLoading) ...[
                const LinearProgressIndicator(minHeight: 3),
                const SizedBox(height: 12),
              ],
              if (locationState.hasError) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Could not fetch current location.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.tertiary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _ensureLocationLoaded,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: _LabeledField(
                      label: 'Latitude',
                      hint: 'Auto-detected',
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      readOnly: true,
                      onChanged: (_) {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LabeledField(
                      label: 'Longitude',
                      hint: 'Auto-detected',
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      readOnly: true,
                      onChanged: (_) {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Radius (metres, optional)',
                hint: 'e.g. 500',
                controller: _radiusController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) {},
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── header ──────────────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.10),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.campaign_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text('New Alert', style: text.labelLarge),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Post an alert', style: text.displaySmall),
                  const SizedBox(height: 8),
                  Text(
                    'Let your neighbourhood know about something important.',
                    style: text.bodyLarge?.copyWith(
                      color: AppColors.ink.withOpacity(0.65),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── step indicator ───────────────────────────────────────────────
                  _StepIndicator(currentStep: _step),
                  const SizedBox(height: 24),

                  // ── step title ───────────────────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(
                      key: ValueKey('title-$_step'),
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_stepTitles[_step], style: text.headlineMedium),
                          const SizedBox(height: 4),
                          Text(
                            _stepSubtitles[_step],
                            style: text.bodyMedium?.copyWith(
                              color: AppColors.ink.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── step content ─────────────────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder:
                        (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut,
                              ),
                            ),
                            child: child,
                          ),
                        ),
                    child: _buildStepContent(),
                  ),

                  // ── error ────────────────────────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 12),
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
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.tertiary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.secondary.withOpacity(0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _buildNavigationRow(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── sub-widgets ──────────────────────────────────────────────────────────────

enum _StepState { idle, active, done }

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _stepLabels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 17),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 2,
                  decoration: BoxDecoration(
                    color:
                        i <= currentStep
                            ? AppColors.primary
                            : AppColors.secondary.withOpacity(0.30),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          _StepDot(
            index: i,
            state:
                i == currentStep
                    ? _StepState.active
                    : i < currentStep
                    ? _StepState.done
                    : _StepState.idle,
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.state});
  final int index;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final isActive = state == _StepState.active;
    final isDone = state == _StepState.done;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isActive
                    ? AppColors.primary
                    : isDone
                    ? AppColors.primary.withOpacity(0.12)
                    : AppColors.surface,
            border: Border.all(
              color:
                  isActive || isDone
                      ? AppColors.primary
                      : AppColors.secondary.withOpacity(0.45),
              width: 1.5,
            ),
            boxShadow:
                isActive
                    ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : [],
          ),
          child: Center(
            child:
                isDone
                    ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.primary,
                    )
                    : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.surface : AppColors.neutral,
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _stepLabels[index].toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isActive || isDone ? AppColors.primary : AppColors.neutral,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.readOnly = false,
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelMedium?.copyWith(
            color: AppColors.ink.withOpacity(0.55),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          readOnly: readOnly,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          style: text.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: text.bodyLarge?.copyWith(
              color: AppColors.neutral.withOpacity(0.60),
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.secondary.withOpacity(0.4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.secondary.withOpacity(0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
