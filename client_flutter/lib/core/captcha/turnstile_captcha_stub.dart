import 'package:flutter/widgets.dart';

class TurnstileCaptcha extends StatelessWidget {
  const TurnstileCaptcha({
    super.key,
    required this.siteKey,
    required this.onToken,
  });

  final String siteKey;
  final ValueChanged<String?> onToken;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
