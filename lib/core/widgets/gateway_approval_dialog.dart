import 'package:flutter/material.dart';

import '../expressive/expressive.dart';
import '../models/gateway_approval.dart';
import '../theme/hermes_theme.dart';

import 'package:hermes_android/core/l10n/l10n.dart';

typedef ApprovalResponder = Future<void> Function(GatewayApprovalChoice choice);

/// The approval prompt, presented as a modal bottom sheet by [show]: what
/// Hermes wants to run, Deny, and a split Allow button whose primary half is
/// the narrowest grant and whose menu holds the broader ones.
class GatewayApprovalDialog extends StatefulWidget {
  /// Opens the sheet. Resolves `true` once a response was delivered; the
  /// sheet cannot be swiped or tapped away, as the dialog could not.
  static Future<bool?> show(
    BuildContext context, {
    required GatewayApprovalRequest request,
    required ApprovalResponder onRespond,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) =>
          GatewayApprovalDialog(request: request, onRespond: onRespond),
    );
  }

  final GatewayApprovalRequest request;
  final ApprovalResponder onRespond;

  const GatewayApprovalDialog({
    required this.request,
    required this.onRespond,
    super.key,
  });

  @override
  State<GatewayApprovalDialog> createState() => _GatewayApprovalDialogState();
}

class _GatewayApprovalDialogState extends State<GatewayApprovalDialog> {
  GatewayApprovalChoice? _submitting;
  bool _confirmAlways = false;
  String? _error;

  Future<void> _respond(GatewayApprovalChoice choice) async {
    if (_submitting != null) return;
    if (choice == GatewayApprovalChoice.always && !_confirmAlways) {
      setState(() {
        _confirmAlways = true;
        _error = null;
      });
      return;
    }

    setState(() {
      _submitting = choice;
      _error = null;
    });
    try {
      await widget.onRespond(choice);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = null;
        _error = context.l10n.could_not_send_the_approval(error);
      });
    }
  }

  String _labelFor(GatewayApprovalChoice choice) {
    return switch (choice) {
      GatewayApprovalChoice.once => context.l10n.allow_once,
      GatewayApprovalChoice.session => context.l10n.allow_for_this_session,
      GatewayApprovalChoice.always =>
        _confirmAlways
            ? context.l10n.confirm_always_allow
            : context.l10n.always_allow,
      GatewayApprovalChoice.deny => context.l10n.deny,
    };
  }

  String _scopeFor(GatewayApprovalChoice choice) {
    return switch (choice) {
      GatewayApprovalChoice.once => context.l10n.run_only_this_command,
      GatewayApprovalChoice.session =>
        context.l10n.allow_matching_commands_until_this_hermes_session_ends,
      GatewayApprovalChoice.always =>
        context.l10n.save_a_permanent_rule_in_the_hermes_configuration,
      GatewayApprovalChoice.deny => context.l10n.do_not_run_this_command,
    };
  }

  IconData _iconFor(GatewayApprovalChoice choice) {
    return switch (choice) {
      GatewayApprovalChoice.once => Icons.play_arrow_rounded,
      GatewayApprovalChoice.session => Icons.timer_outlined,
      GatewayApprovalChoice.always => Icons.verified_user_outlined,
      GatewayApprovalChoice.deny => Icons.block_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final request = widget.request;
    final busy = _submitting != null;
    final allows = [
      for (final choice in request.choices)
        if (choice != GatewayApprovalChoice.deny) choice,
    ];
    final canDeny = request.choices.contains(GatewayApprovalChoice.deny);
    // Confirming "always" promotes it to the primary half so the second tap
    // lands where the first one did.
    final primary = _confirmAlways
        ? GatewayApprovalChoice.always
        : allows.firstOrNull;
    final others = [
      for (final choice in allows)
        if (choice != primary) choice,
    ];

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox.square(
                      dimension: 48,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: scheme.tertiaryContainer,
                          shape: const ExpressiveShapeBorder(
                            ExpressiveShape.clover,
                          ),
                        ),
                        child: Icon(
                          Icons.gpp_maybe_outlined,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          context.l10n.approval_needed,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (request.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(request.description, style: theme.textTheme.bodyLarge),
                ],
                if (request.command.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.command,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(HermesRadius.lg),
                    ),
                    child: SelectableText(
                      request.command,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                if (_confirmAlways) ...[
                  const SizedBox(height: 14),
                  Text(
                    context
                        .l10n
                        .this_creates_a_permanent_rule_in_hermes_review_the_full,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    key: const Key('approval-error'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (primary != null) ...[
                  Text(
                    _scopeFor(primary),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (canDeny)
                      OutlinedButton.icon(
                        key: const Key('approval-deny'),
                        onPressed: busy
                            ? null
                            : () => _respond(GatewayApprovalChoice.deny),
                        icon: _submitting == GatewayApprovalChoice.deny
                            ? const ExpressiveLoadingIndicator(
                                size: 20,
                                contained: false,
                              )
                            : Icon(_iconFor(GatewayApprovalChoice.deny)),
                        label: Text(_labelFor(GatewayApprovalChoice.deny)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          minimumSize: const Size(0, 56),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    if (primary != null)
                      SplitButton(
                        primaryKey: Key('approval-${primary.wireValue}'),
                        label: _labelFor(primary),
                        onPressed: busy ? null : () => _respond(primary),
                        menuTooltip: others.isEmpty
                            ? null
                            : context.l10n.more_approval_options,
                        menuKey: const Key('approval-more'),
                        items: [
                          for (final choice in others)
                            SplitButtonItem(
                              key: Key('approval-${choice.wireValue}'),
                              label: _labelFor(choice),
                              subtitle: _scopeFor(choice),
                              icon: _iconFor(choice),
                              onPressed: busy ? null : () => _respond(choice),
                            ),
                        ],
                        child: busy && _submitting != GatewayApprovalChoice.deny
                            ? ExpressiveLoadingIndicator(
                                size: 24,
                                contained: false,
                                color: scheme.onPrimary,
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_iconFor(primary), size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _labelFor(primary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
