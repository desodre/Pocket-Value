import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps the application fullscreen, including after keyboard interactions.
class ImmersiveMode extends StatefulWidget {
  const ImmersiveMode({super.key, required this.child});

  final Widget child;

  @override
  State<ImmersiveMode> createState() => _ImmersiveModeState();
}

class _ImmersiveModeState extends State<ImmersiveMode>
    with WidgetsBindingObserver {
  static const _androidChannel = MethodChannel('pocket_value/system_ui');
  Timer? _restoreTimer;
  bool _keyboardWasVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enterImmersiveMode());
  }

  Future<void> _enterImmersiveMode() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Native insets APIs also work when Flutter's legacy mode is ignored
        // by Android apps targeting API 36 and above.
        await _androidChannel.invokeMethod<void>('enterImmersiveMode');
      }
    } on MissingPluginException {
      // Framework mode remains available on hosts without the Android bridge.
    } on PlatformException {
      // A system UI policy must not prevent the app from opening.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_enterImmersiveMode());
    }
  }

  @override
  void didChangeMetrics() {
    _restoreTimer?.cancel();
    final keyboardVisible = View.of(context).viewInsets.bottom > 0;
    if (_keyboardWasVisible && !keyboardVisible) {
      // Android temporarily prevents system UI changes after the IME closes.
      _restoreTimer = Timer(const Duration(milliseconds: 1100), () {
        if (mounted &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          unawaited(_enterImmersiveMode());
        }
      });
    }
    _keyboardWasVisible = keyboardVisible;
  }

  @override
  void dispose() {
    _restoreTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
