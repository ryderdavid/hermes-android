import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../utils/html_artifact_preview.dart';

/// Sandboxed live preview of one HTML artifact.
///
/// Security posture mirrors the desktop's opaque-origin `sandbox` iframe:
/// JavaScript runs, but file access is off, there is NO `addJavascriptInterface`
/// bridge, every top-level navigation is prevented, and the served document
/// carries [kArtifactPreviewCsp]. Content is loaded with `loadHtmlString`
/// (opaque base URL) — never `file://`, which fails anyway with file access
/// disabled. Single-file HTML artifacts render fully; relative sibling assets
/// do not resolve under an opaque base URL (same limitation as the desktop
/// srcdoc preview).
///
/// [controllerFactory] / [webViewBuilder] are injectable so widget tests can
/// pump the surrounding card without a platform WebView.
class HtmlArtifactPreview extends StatefulWidget {
  final Uint8List bytes;

  /// Background painted behind the page while it loads; comes from the
  /// theme at the call site (no hardcoded colors).
  final Color backgroundColor;

  final WebViewController Function()? controllerFactory;
  final Widget Function(WebViewController controller)? webViewBuilder;

  const HtmlArtifactPreview({
    super.key,
    required this.bytes,
    required this.backgroundColor,
    this.controllerFactory,
    this.webViewBuilder,
  });

  @override
  State<HtmlArtifactPreview> createState() => _HtmlArtifactPreviewState();
}

class _HtmlArtifactPreviewState extends State<HtmlArtifactPreview> {
  late final WebViewController _controller;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = (widget.controllerFactory ?? WebViewController.new)();
    unawaited(_configureAndLoad());
  }

  Future<void> _configureAndLoad() async {
    try {
      // Sandbox: scripts on, everything else locked down.
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => NavigationDecision.prevent,
        ),
      );
      await _controller.setBackgroundColor(widget.backgroundColor);
      // No addJavascriptInterface anywhere: the page gets no host bridge.
      final platform = _controller.platform;
      if (platform is AndroidWebViewController) {
        await platform.setAllowFileAccess(false);
        await platform.setAllowContentAccess(false);
      }
      await _controller.loadHtmlString(
        injectArtifactCsp(decodeArtifactHtml(widget.bytes)),
      );
    } catch (e) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return const SizedBox.shrink();
    }
    final builder = widget.webViewBuilder;
    if (builder != null) return builder(_controller);
    return WebViewWidget(controller: _controller);
  }
}
