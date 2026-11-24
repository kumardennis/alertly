import 'package:alertly/core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/session_provider.dart';
import '../../core/captcha/turnstile_captcha.dart';
import '../../core/config/app_config.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  static const _resendCooldownSeconds = 180;

  final _otpController = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  bool _verifyInFlight = false;
  bool _resendInFlight = false;
  int _resendCooldown = _resendCooldownSeconds;
  String? _captchaToken;
  int _captchaResetKey = 0;

  bool get _requiresCaptcha => kIsWeb && AppConfig.hasTurnstileSiteKey;

  bool get _canVerify => _otpController.text.trim().length == 6;
  bool get _canResend =>
      !_resending &&
      !_loading &&
      !_resendInFlight &&
      _resendCooldown <= 0 &&
      (!_requiresCaptcha ||
          (_captchaToken != null && _captchaToken!.isNotEmpty));

  @override
  void initState() {
    super.initState();
    // OTP was just requested on the login screen, so start cooldown immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startResendCooldown();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendCooldown = _resendCooldownSeconds;
    if (mounted) setState(() {});
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_resendCooldown <= 1) {
        setState(() => _resendCooldown = 0);
        return false;
      }
      setState(() => _resendCooldown -= 1);
      return true;
    });
  }

  Future<void> _verify() async {
    final token = _otpController.text.trim();
    if (token.length < 6 || _verifyInFlight) return;

    _verifyInFlight = true;
    setState(() => _loading = true);
    try {
      final isNewUser = await ref
          .read(sessionProvider.notifier)
          .verify(widget.phone, token);

      if (mounted) {
        context.go(isNewUser ? '/onboarding' : '/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
      }
    } finally {
      _verifyInFlight = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;

    _resendInFlight = true;
    setState(() => _resending = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .register(widget.phone, captchaToken: _captchaToken);
      if (mounted) {
        _captchaToken = null;
        _captchaResetKey += 1;
        _startResendCooldown();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('OTP sent again')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _captchaToken = null;
          _captchaResetKey += 1;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to resend OTP: $e')));
      }
    } finally {
      _resendInFlight = false;
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.secondary.withOpacity(0.14),
                    scheme.primary.withOpacity(0.12),
                    theme.scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(height: 8),
                  Text('Verify OTP', style: text.displaySmall),
                  const SizedBox(height: 10),
                  Text(
                    'Enter the 6-digit code sent to ${widget.phone}',
                    style: text.bodyLarge?.copyWith(
                      color: scheme.onSurface.withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.secondary.withOpacity(0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('One-time code', style: text.titleMedium),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: text.headlineMedium?.copyWith(
                            letterSpacing: 8,
                            fontWeight: FontWeight.w700,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: const InputDecoration(
                            hintText: '123456',
                            hintStyle: TextStyle(
                              letterSpacing: 8,
                              color: AppColors.neutral,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _verify(),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                (_loading || !_canVerify) ? null : _verify,
                            icon:
                                _loading
                                    ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.verified_rounded),
                            label: Text(
                              _loading ? 'Verifying...' : 'Verify Code',
                            ),
                          ),
                        ),
                        if (_requiresCaptcha) ...[
                          const SizedBox(height: 12),
                          TurnstileCaptcha(
                            key: ValueKey(_captchaResetKey),
                            siteKey: AppConfig.turnstileSiteKey,
                            onToken: (token) {
                              setState(() => _captchaToken = token);
                            },
                          ),
                        ],
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            onPressed: _canResend ? _resend : null,
                            child: Text(
                              _resending
                                  ? 'Resending...'
                                  : _resendCooldown > 0
                                  ? 'Resend OTP in ${_resendCooldown}s'
                                  : 'Resend OTP',
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
