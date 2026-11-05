import 'package:flutter/material.dart';

import '../services/agent_credential_service.dart';
import '../services/biometric_gate.dart';
import '../services/connection_manager.dart' show SavedConnection;
import '../expressive/expressive.dart';
import 'package:hermes_android/core/l10n/l10n.dart';

/// Settings card for the stored agent SUDO password: save, enable automatic
/// answers, review the audit trail, or clear. The password itself is never
/// displayed, logged, or copied into state that outlives the save dialog.
class AgentCredentialCard extends StatefulWidget {
  const AgentCredentialCard({
    required this.connection,
    super.key,
    this.serviceFactory,
    this.gateFactory,
  });

  final SavedConnection connection;

  /// Test hooks: how to build the credential service and the biometric gate.
  final Future<AgentCredentialService> Function()? serviceFactory;
  final BiometricGate Function()? gateFactory;

  @override
  State<AgentCredentialCard> createState() => _AgentCredentialCardState();
}

class _AgentCredentialCardState extends State<AgentCredentialCard> {
  AgentCredentialService? _service;
  bool _saved = false;
  bool _autoAnswer = false;
  bool _fetch = false;
  List<AgentSudoAuditEntry> _audit = const [];

  String get _connectionIdentity =>
      '${widget.connection.baseUrl}|'
      '${widget.connection.gatewayPrefix ?? ''}|'
      '${widget.connection.desktopGatewayUrl ?? ''}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service =
        await (widget.serviceFactory ?? AgentCredentialService.open)();
    if (!mounted) return;
    final saved = await service.hasSudoPassword(_connectionIdentity);
    if (!mounted) return;
    setState(() {
      _service = service;
      _saved = saved;
      _autoAnswer = service.isAutoAnswerEnabled(_connectionIdentity);
      _fetch = service.isFetchEnabled(_connectionIdentity);
      _audit = service.auditEntries();
    });
  }

  Future<void> _refresh() async {
    final service = _service;
    if (service == null) return;
    final saved = await service.hasSudoPassword(_connectionIdentity);
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _autoAnswer = service.isAutoAnswerEnabled(_connectionIdentity);
      _fetch = service.isFetchEnabled(_connectionIdentity);
      _audit = service.auditEntries();
    });
  }

  Future<void> _onAutoAnswerChanged(bool value) async {
    final service = _service;
    if (service == null) return;
    final l10n = context.l10n;
    final biometricReason = l10n.agent_sudo_biometric_reason;
    if (!value) {
      await service.setAutoAnswerEnabled(_connectionIdentity, false);
      await _refresh();
      return;
    }
    if (!_saved) {
      // Nothing stored yet: saving below is the gate.
      final saved = await _showSaveDialog();
      if (!saved) {
        _showEnableCancelled(l10n.agent_sudo_enable_needs_password);
        return;
      }
    }
    final gate = (widget.gateFactory ?? BiometricGate.new)();
    final outcome = await gate.authenticateDetailed(
      localizedReason: biometricReason,
    );
    if (outcome.result == BiometricGateResult.authenticated) {
      // Gate passed; enable below.
    } else if (outcome.result == BiometricGateResult.cancelled) {
      _showEnableCancelled(l10n.agent_sudo_enable_cancelled);
      await _refresh();
      return;
    } else {
      // No biometric/PIN, or a platform error: say why, then fall back to
      // re-entering the SUDO password as the gate.
      _showEnableCancelled(
        l10n.agent_sudo_enable_biometric_error(outcome.errorCode ?? 'unknown'),
      );
      final saved = await _showSaveDialog();
      if (!saved) {
        _showEnableCancelled(l10n.agent_sudo_enable_needs_password);
        return;
      }
    }
    await service.setAutoAnswerEnabled(_connectionIdentity, true);
    await _refresh();
  }

  Future<void> _onFetchChanged(bool value) async {
    final service = _service;
    if (service == null) return;
    final l10n = context.l10n;
    final biometricReason = l10n.agent_sudo_biometric_reason;
    if (!value) {
      await service.setFetchEnabled(_connectionIdentity, false);
      await _refresh();
      return;
    }
    if (!_saved) {
      final saved = await _showSaveDialog();
      if (!saved) {
        _showEnableCancelled(l10n.agent_sudo_enable_needs_password);
        return;
      }
    }
    final gate = (widget.gateFactory ?? BiometricGate.new)();
    final outcome = await gate.authenticateDetailed(
      localizedReason: biometricReason,
    );
    if (outcome.result == BiometricGateResult.authenticated) {
      // Gate passed; enable below.
    } else if (outcome.result == BiometricGateResult.cancelled) {
      _showEnableCancelled(l10n.agent_sudo_enable_cancelled);
      await _refresh();
      return;
    } else {
      _showEnableCancelled(
        l10n.agent_sudo_enable_biometric_error(outcome.errorCode ?? 'unknown'),
      );
      final saved = await _showSaveDialog();
      if (!saved) {
        _showEnableCancelled(l10n.agent_sudo_enable_needs_password);
        return;
      }
    }
    await service.setFetchEnabled(_connectionIdentity, true);
    await _refresh();
  }

  void _showEnableCancelled(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Shows the two-field save dialog. Returns true when the password was saved.
  Future<bool> _showSaveDialog() async {
    final service = _service;
    if (service == null || !mounted) return false;
    final first = TextEditingController();
    final second = TextEditingController();
    var errorKey = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final l10n = context.l10n;
            return AlertDialog(
              icon: const Icon(Icons.lock_outline),
              title: Text(l10n.agent_sudo_password_dialog_title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: first,
                    obscureText: true,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.agent_sudo_password_dialog_hint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: second,
                    obscureText: true,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.agent_sudo_password_confirm_hint,
                    ),
                  ),
                  if (errorKey.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorKey == 'mismatch'
                          ? l10n.agent_sudo_password_mismatch
                          : l10n.agent_sudo_password_empty,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final a = first.text;
                    final b = second.text;
                    if (a.trim().isEmpty) {
                      setDialogState(() => errorKey = 'empty');
                      return;
                    }
                    if (a != b) {
                      setDialogState(() => errorKey = 'mismatch');
                      return;
                    }
                    await service.saveSudoPassword(_connectionIdentity, a);
                    first.clear();
                    second.clear();
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
    first.dispose();
    second.dispose();
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.agent_sudo_saved_snackbar)),
      );
      await _refresh();
    }
    return result == true;
  }

  Future<void> _clear() async {
    final service = _service;
    if (service == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.agent_sudo_clear),
        content: Text(context.l10n.agent_sudo_clear_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.agent_sudo_clear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await service.clearSudoPassword(_connectionIdentity);
    await service.setAutoAnswerEnabled(_connectionIdentity, false);
    await service.setFetchEnabled(_connectionIdentity, false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.agent_sudo_cleared_snackbar)),
      );
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: TonalIcon(
              Icons.lock_outline,
              tone: (scheme.secondaryContainer, scheme.onSecondaryContainer),
            ),
            title: Text(l10n.agent_sudo_credential_title),
            subtitle: Text(
              _saved
                  ? l10n.agent_sudo_credential_subtitle_saved
                  : l10n.agent_sudo_credential_subtitle_not_saved,
            ),
          ),
          SwitchListTile(
            secondary: TonalIcon(
              Icons.bolt_outlined,
              tone: (scheme.tertiaryContainer, scheme.onTertiaryContainer),
            ),
            title: Text(l10n.agent_sudo_auto_answer),
            subtitle: Text(l10n.agent_sudo_auto_answer_subtitle),
            value: _autoAnswer,
            onChanged: _onAutoAnswerChanged,
          ),
          SwitchListTile(
            secondary: TonalIcon(
              Icons.download_outlined,
              tone: (scheme.errorContainer, scheme.onErrorContainer),
            ),
            title: Text(l10n.agent_sudo_fetch),
            subtitle: Text(l10n.agent_sudo_fetch_subtitle),
            value: _fetch,
            onChanged: _onFetchChanged,
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(l10n.agent_sudo_save),
            onTap: _showSaveDialog,
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.agent_sudo_clear),
            enabled: _saved,
            onTap: _clear,
          ),
          ExpansionTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.agent_sudo_audit_title),
            children: _audit.isEmpty
                ? [
                    ListTile(
                      dense: true,
                      title: Text(
                        l10n.agent_sudo_audit_empty,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ]
                : _audit.reversed
                      .map(
                        (entry) => ListTile(
                          dense: true,
                          title: Text(entry.connectionLabel),
                          subtitle: Text(
                            '${entry.kind == AgentSudoAuditEntry.kindFetch ? l10n.agent_sudo_audit_kind_fetch : l10n.agent_sudo_audit_kind_auto} · ${DateTime.fromMillisecondsSinceEpoch(entry.timestampMillis).toLocal()} · ${entry.requestId}',
                          ),
                        ),
                      )
                      .toList(),
          ),
        ],
      ),
    );
  }
}
