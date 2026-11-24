import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

@JS('turnstile')
external TurnstileApi? get _turnstile;

extension type TurnstileApi._(JSObject _) implements JSObject {
  external String render(web.HTMLElement element, JSObject options);
  external void remove(JSAny widgetId);
}

class TurnstileCaptcha extends StatefulWidget {
  const TurnstileCaptcha({
    super.key,
    required this.siteKey,
    required this.onToken,
  });

  final String siteKey;
  final ValueChanged<String?> onToken;

  @override
  State<TurnstileCaptcha> createState() => _TurnstileCaptchaState();
}

class _TurnstileCaptchaState extends State<TurnstileCaptcha> {
  late final String _viewType;
  late final web.HTMLDivElement _host;
  String? _widgetId;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _viewType =
        'turnstile-${identityHashCode(this)}-${DateTime.now().microsecondsSinceEpoch}';
    _host =
        web.HTMLDivElement()
          ..style.width = '100%'
          ..style.minHeight = '65px';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      scheduleMicrotask(_renderWhenReady);
      return _host;
    });
  }

  void _renderWhenReady() {
    _pollTimer?.cancel();
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      attempts += 1;
      final api = _turnstile;
      if (api == null) {
        if (attempts > 50) timer.cancel();
        return;
      }
      timer.cancel();
      _mountWidget(api);
    });
  }

  void _mountWidget(TurnstileApi api) {
    final existing = _widgetId;
    if (existing != null) {
      try {
        api.remove(existing.toJS);
      } catch (_) {}
      _widgetId = null;
    }

    _host.innerHTML = ''.toJS;

    final options = JSObject();
    options['sitekey'] = widget.siteKey.toJS;
    options['theme'] = 'light'.toJS;
    options['callback'] =
        ((JSString token) {
          widget.onToken(token.toDart);
        }).toJS;
    options['expired-callback'] =
        (() {
          widget.onToken(null);
        }).toJS;
    options['error-callback'] =
        (() {
          widget.onToken(null);
        }).toJS;

    _widgetId = api.render(_host, options);
  }

  @override
  void didUpdateWidget(covariant TurnstileCaptcha oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.siteKey != widget.siteKey) {
      final api = _turnstile;
      if (api != null) _mountWidget(api);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    final api = _turnstile;
    final widgetId = _widgetId;
    if (api != null && widgetId != null) {
      try {
        api.remove(widgetId.toJS);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.siteKey.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 70,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
