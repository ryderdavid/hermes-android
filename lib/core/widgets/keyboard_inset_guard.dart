import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// Repairs a stale keyboard inset at the app root.
///
/// On Android 15+ edge-to-edge with `adjustResize`, some OEM builds (seen on
/// Samsung One UI) fail to clear `MediaQuery.viewInsets.bottom` when the IME
/// is dismissed, so the Scaffold keeps reserving the keyboard area and the
/// composer floats mid-screen above a blank gap. The IME can only be visible
/// while an [EditableText] holds primary focus, so an inset with no editable
/// focus is always stale: clamp it to zero here.
///
/// The widget listens to [FocusManager] (focus survives keyboard dismissal
/// via the back button, so the inset alone cannot be trusted) and provides
/// the sanitized [MediaQuery] to everything below the app root builder.
class KeyboardInsetGuard extends StatefulWidget {
  const KeyboardInsetGuard({required this.child, this.textScaler, super.key});

  final Widget child;

  /// Text scaler the root builder wants applied; kept here so the guard owns
  /// the final [MediaQuery] below it.
  final TextScaler? textScaler;

  @override
  State<KeyboardInsetGuard> createState() => _KeyboardInsetGuardState();
}

class _KeyboardInsetGuardState extends State<KeyboardInsetGuard> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  /// True when the primary focus sits on an editable text field, the only
  /// case where the IME can actually be on screen.
  static bool _editableHasFocus() {
    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    if (context == null) return false;
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    var viewInsets = data.viewInsets;
    if (viewInsets.bottom > 0 && !_editableHasFocus()) {
      viewInsets = viewInsets.copyWith(bottom: 0);
    }
    return MediaQuery(
      data: data.copyWith(
        viewInsets: viewInsets,
        textScaler: widget.textScaler ?? data.textScaler,
      ),
      child: widget.child,
    );
  }
}
