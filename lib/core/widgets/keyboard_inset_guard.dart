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
/// The one hole in the focus signal: dismissing the IME with the system BACK
/// button keeps focus on the field, so the inset looks "live" forever. The
/// guard is therefore also a [WidgetsBindingObserver]: a back press that was
/// not handled by a route dismissed the IME, so the editable is unfocused and
/// the clamp applies.
///
/// The widget listens to [FocusManager] and provides the sanitized
/// [MediaQuery] to everything below the app root builder.
class KeyboardInsetGuard extends StatefulWidget {
  const KeyboardInsetGuard({required this.child, this.textScaler, super.key});

  final Widget child;

  /// Text scaler the root builder wants applied; kept here so the guard owns
  /// the final [MediaQuery] below it.
  final TextScaler? textScaler;

  @override
  State<KeyboardInsetGuard> createState() => _KeyboardInsetGuardState();
}

class _KeyboardInsetGuardState extends State<KeyboardInsetGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    // Binding observers are notified in registration order until one handles
    // the back press. WidgetsApp registered before this guard, so a route pop
    // it handled never reaches us. Reaching this callback with editable focus
    // therefore means back dismissed the IME without popping a route.
    if (_editableHasFocus()) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    return false;
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
