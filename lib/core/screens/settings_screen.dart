// Settings screen for model selection, theme toggle, and app info.
import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/hermes_components.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/config_backup_io.dart';
import '../services/config_backup_service.dart';
import '../services/connection_manager.dart';
import '../services/notification_prefs.dart';
import '../services/turn_notification_service.dart';
import '../expressive/expressive.dart';
import '../theme/hermes_theme.dart';
import 'appearance_screen.dart';
import '../widgets/config_backup_card.dart';
import '../widgets/settings_group.dart';
import '../../main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_update_service.dart';
import '../widgets/update_available_dialog.dart';

import 'package:hermes_android/core/l10n/l10n.dart';

class SettingsScreen extends StatefulWidget {
  final SavedConnection connection;
  const SettingsScreen({required this.connection, super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late DashboardClient _client;
  Map<String, dynamic>? _modelInfo;
  Map<String, dynamic>? _modelOptions;
  bool _loading = true;
  String? _error;
  String? _successMsg;

  // Selected values
  String _selectedProvider = '';
  String _selectedModel = '';
  List<String> _providers = [];
  Map<String, List<Map<String, dynamic>>> _providerModels = {};

  @override
  void initState() {
    super.initState();
    _client = DashboardClient(
      host: widget.connection.host,
      port: widget.connection.dashboardPort,
      pathPrefix: widget.connection.dashboardPrefix ?? "",
      proxied: widget.connection.dashboardProxied,
      useHttps: widget.connection.useHttps,
      username: widget.connection.dashboardUsername,
      password: widget.connection.dashboardPassword,
    );
    _loadData();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _client.getModelInfo(),
        _client.getModelOptions(),
      ]);

      if (!mounted) return;
      setState(() {
        _modelInfo = results[0];
        _modelOptions = results[1];
        _loading = false;
        _parseModelOptions();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _parseModelOptions() {
    if (_modelOptions == null) return;

    final providers = _modelOptions!['providers'] as List<dynamic>? ?? [];
    _providers = [];
    _providerModels = {};

    for (final p in providers) {
      if (p is! Map<String, dynamic>) continue;
      final pMap = p;
      // Provider key is 'slug', not 'id'
      final providerId =
          (pMap['slug'] as String?) ?? (pMap['id'] as String?) ?? '';
      final rawModels = pMap['models'] as List<dynamic>? ?? [];
      if (providerId.isEmpty || rawModels.isEmpty) continue;

      _providers.add(providerId);
      // Models are strings (model IDs), not dicts
      // Convert to list of {'id': modelId, 'name': modelId} maps for dropdown
      _providerModels[providerId] = rawModels
          .map((m) {
            if (m is String) {
              return {'id': m, 'name': m};
            } else if (m is Map<String, dynamic>) {
              return m;
            }
            return <String, dynamic>{};
          })
          .where((m) => m['id'] != null && (m['id'] as String).isNotEmpty)
          .toList();
    }

    // Set initial selections from current model
    if (_modelInfo != null) {
      _selectedProvider = (_modelInfo!['provider'] as String?) ?? '';
      _selectedModel = (_modelInfo!['model'] as String?) ?? '';
    }
  }

  Future<void> _applyModel() async {
    if (_selectedProvider.isEmpty || _selectedModel.isEmpty) return;

    setState(() {
      _error = null;
      _successMsg = null;
    });

    try {
      await _client.setModel('main', _selectedProvider, _selectedModel);
      if (!mounted) return;
      setState(() {
        _successMsg = context.l10n
            .profile_default_set_to_chats_with_their_own_model_keep(
              _selectedModel,
            );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadData,
            tooltip: context.l10n.refresh,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: ExpressiveLoadingIndicator());
    }

    if (_error != null && _modelOptions == null) {
      // Device-local controls remain available without the dashboard.
      return ListView(
        padding: _listPadding,
        children: [
          _buildHeader(),
          ErrorState(
            title: context.l10n.failed_to_load_settings,
            message: _error!,
            onRetry: _loadData,
          ),
          const SizedBox(height: HermesSpacing.xl),
          _buildPreferencesGroup(),
          SettingsGroup(title: context.l10n.about, children: [_AboutCard()]),
        ],
      );
    }

    return ListView(
      padding: _listPadding,
      children: [
        _buildHeader(),
        _ConnectionCard(connection: widget.connection),
        const SizedBox(height: HermesSpacing.xl),
        _buildPreferencesGroup(verbose: true),

        // ---- Section: Model ----
        SettingsGroup(
          title: context.l10n.profile_default_model,
          children: [_buildModelTile()],
        ),
        if (_successMsg != null) ...[
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(HermesSpacing.lg),
              child: Text(
                _successMsg!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: HermesSpacing.xl),
        ],
        if (_error != null && _modelOptions != null) ...[
          InlineErrorBanner(message: _error!),
          const SizedBox(height: HermesSpacing.xl),
        ],

        // ---- Section: Notifications ----
        SettingsGroup(
          title: context.l10n.notifications,
          children: const [_NotificationSettings()],
        ),

        // ---- Section: Voice ----
        SettingsGroup(title: context.l10n.voice, children: [_VoicePicker()]),

        // ---- Section: Session Sources ----
        SettingsGroup(
          title: context.l10n.session_sources,
          children: [_SessionSourcesFilter(connectionId: widget.connection.id)],
        ),

        // ---- Section: Backup ----
        SettingsGroup(
          title: context.l10n.backup_restore,
          children: [
            ConfigBackupCard(
              onExport: _exportConfig,
              onDeliverExport: _deliverExport,
              onPickBackupFile: _pickBackupFile,
              onImport: _importConfig,
            ),
          ],
        ),

        // ---- Section: About ----
        SettingsGroup(title: context.l10n.about, children: [_AboutCard()]),
      ],
    );
  }

  ConfigBackupIo _backupIo() {
    final app = context.findAncestorStateOfType<HermesAppState>()!;
    return ConfigBackupIo(connectionManager: app.widget.connManager);
  }

  Future<String> _exportConfig(String passphrase) {
    return _backupIo().exportEncrypted(passphrase);
  }

  Future<String?> _deliverExport(String contents) {
    return _backupIo().deliverExport(contents);
  }

  Future<String?> _pickBackupFile() {
    return _backupIo().pickBackupFile();
  }

  Future<ConfigImportResult> _importConfig(
    String contents,
    String passphrase,
    ConfigImportMode mode,
  ) async {
    final result = await _backupIo().importEncrypted(
      contents,
      passphrase,
      mode,
    );
    if (mounted) {
      // Text size is read at app root; refresh so a restored preference is
      // visible without restarting the app. Appearance refreshes itself.
      context.findAncestorStateOfType<HermesAppState>()?.setState(() {});
    }
    return result;
  }

  static const EdgeInsets _listPadding = EdgeInsets.fromLTRB(
    HermesSpacing.lg,
    0,
    HermesSpacing.lg,
    HermesSpacing.xl,
  );

  Widget _buildHeader() => LargeHeader(
    title: context.l10n.settings,
    padding: const EdgeInsets.fromLTRB(4, 0, 4, HermesSpacing.lg),
  );

  /// The profile's default model: what it is now and the pickers to change
  /// it, as one tile.
  Widget _buildModelTile() {
    return Padding(
      padding: const EdgeInsets.all(HermesSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.changes_the_default_for_use_the_selector_in_a_chat(
              widget.connection.label,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (_modelInfo != null)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(HermesRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.smart_toy,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.current_profile_default,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.model_via_provider(
                        _modelInfo!['model'] ?? '???',
                        _modelInfo!['provider'] ?? '???',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_modelInfo!['effective_context_length'] != null &&
                        _modelInfo!['effective_context_length'] != 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          context.l10n.context_tokens(
                            _modelInfo!['effective_context_length'],
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Provider picker
          if (_providers.isNotEmpty) ...[
            _buildDropdown<String>(
              label: context.l10n.provider,
              value:
                  _selectedProvider.isNotEmpty &&
                      _providers.contains(_selectedProvider)
                  ? _selectedProvider
                  : null,
              items: _providers
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedProvider = val!;
                  // Reset model when switching providers
                  final models = _providerModels[val];
                  if (models != null && models.isNotEmpty) {
                    _selectedModel = models.first['id'] as String? ?? '';
                  } else {
                    _selectedModel = '';
                  }
                });
              },
            ),
            const SizedBox(height: 12),
          ],

          // Model picker
          if (_selectedProvider.isNotEmpty &&
              _providerModels.containsKey(_selectedProvider)) ...[
            _buildDropdown<String>(
              label: context.l10n.model,
              value: _selectedModel,
              items: _providerModels[_selectedProvider]!.map((m) {
                final id = m['id'] as String? ?? '';
                final name = m['name'] as String? ?? id;
                return DropdownMenuItem(value: id, child: Text(name));
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedModel = val!);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _applyModel,
                icon: const Icon(Icons.check),
                label: Text(context.l10n.set_profile_default),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Device-local preferences, so they stay available when the dashboard
  /// cannot be reached: the Appearance page, and (with [verbose]) the
  /// chat-metadata toggle.
  Widget _buildPreferencesGroup({bool verbose = false}) {
    return SettingsGroup(
      children: [
        ListTile(
          key: const Key('settings-appearance'),
          minTileHeight: 72,
          leading: const TonalIcon(Icons.palette_outlined),
          title: Text(context.l10n.appearance),
          subtitle: Text(context.l10n.appearance_summary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AppearanceScreen(
                connectionId: widget.connection.id,
                connectionLabel: widget.connection.label,
              ),
            ),
          ),
        ),
        if (verbose) _VerboseToggle(),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

/// About card that reads the real version from package_info_plus.
class _AboutCard extends StatefulWidget {
  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  String _version = '';
  bool _checking = false;
  bool _checkOnLaunch = true;
  String? _updateStatus;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadUpdatePreference();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = '${info.version}+${info.buildNumber}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _version = 'unknown');
    }
  }

  Future<void> _loadUpdatePreference() async {
    final enabled = await AppUpdateService().checkOnLaunchEnabled();
    if (!mounted) return;
    setState(() => _checkOnLaunch = enabled);
  }

  Future<void> _setCheckOnLaunch(bool enabled) async {
    setState(() => _checkOnLaunch = enabled);
    await AppUpdateService().setCheckOnLaunchEnabled(enabled);
  }

  /// The manual path: always a real check, and always an answer — the
  /// launch-time prompt is the one that stays quiet when GitHub cannot be
  /// reached, because there the user did not ask.
  Future<void> _checkForUpdates() async {
    setState(() {
      _checking = true;
      _updateStatus = null;
    });
    final service = AppUpdateService();
    AppUpdateResult result;
    try {
      final current = await installedAppVersion() ?? _version;
      result = await service.checkForUpdate(
        currentVersion: current,
        force: true,
      );
    } catch (_) {
      result = const AppUpdateResult(AppUpdateOutcome.failed);
    }
    if (!mounted) return;
    setState(() => _checking = false);
    final l10n = context.l10n;
    switch (result.outcome) {
      case AppUpdateOutcome.updateAvailable:
        final release = result.release!;
        final action = await showUpdateAvailableDialog(
          context,
          release: release,
        );
        if (action == UpdatePromptAction.skipVersion) {
          await service.skipVersion(release.version);
        }
      case AppUpdateOutcome.upToDate:
        setState(() => _updateStatus = l10n.you_re_on_the_latest_version);
      case AppUpdateOutcome.throttled:
      case AppUpdateOutcome.failed:
        setState(() => _updateStatus = l10n.couldn_t_check_for_updates);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.hermes_agent_for_android,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(context.l10n.material_you_fork_build),
            const SizedBox(height: 4),
            Text(
              context.l10n.version_label(_version.isNotEmpty ? _version : '…'),
            ),
            const SizedBox(height: 8),
            Text(
              context
                  .l10n
                  .browse_and_manage_your_hermes_agent_sessions_from_your_phone,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.check_for_updates),
              subtitle: _updateStatus == null ? null : Text(_updateStatus!),
              trailing: _checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onTap: _checking ? null : _checkForUpdates,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.check_for_updates_on_launch),
              value: _checkOnLaunch,
              onChanged: _setCheckOnLaunch,
            ),
            const Divider(height: 24),
            _RepositoryLink(
              icon: Icons.palette_outlined,
              title: context.l10n.fork_repository_on_github,
              url: AppUpdateService.forkRepositoryUrl,
            ),
            _RepositoryLink(
              icon: Icons.call_split,
              title: context.l10n.upstream_project,
              url: AppUpdateService.upstreamRepositoryUrl,
            ),
          ],
        ),
      ),
    );
  }
}

/// A repository row in the About card; opens [url] in the browser.
class _RepositoryLink extends StatelessWidget {
  const _RepositoryLink({
    required this.icon,
    required this.title,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(url.replaceFirst('https://', '')),
      trailing: const Icon(Icons.open_in_new),
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}

/// Toggle for verbose mode — shows tool calls, thinking, and message metadata in chat.
class _VerboseToggle extends StatefulWidget {
  @override
  State<_VerboseToggle> createState() => _VerboseToggleState();
}

class _VerboseToggleState extends State<_VerboseToggle> {
  bool _verbose = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _verbose = prefs.getBool('verbose_mode') ?? false);
  }

  Future<void> _set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('verbose_mode', value);
    setState(() => _verbose = value);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        title: Text(context.l10n.verbose_mode),
        subtitle: Text(
          context.l10n.show_tool_calls_thinking_and_message_metadata,
        ),
        secondary: TonalIcon(
          Icons.terminal,
          tone: (
            Theme.of(context).colorScheme.secondaryContainer,
            Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        value: _verbose,
        onChanged: _set,
      ),
    );
  }
}

class _VoicePicker extends StatefulWidget {
  @override
  State<_VoicePicker> createState() => _VoicePickerState();
}

class _VoicePickerState extends State<_VoicePicker> {
  final FlutterTts _tts = FlutterTts();
  final List<Map<String, String>> _voices = [];
  String? _selectedVoiceName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedVoiceName = prefs.getString('voice_name');

    try {
      final raw = await _tts.getVoices;
      if (raw is List && raw.isNotEmpty) {
        for (final item in raw) {
          if (item is Map) {
            final m = <String, String>{};
            m['name'] = (item['name'] ?? '').toString();
            m['locale'] = (item['locale'] ?? '').toString();
            if (m['name']!.isNotEmpty) _voices.add(m);
          }
        }
      }
    } catch (_) {}

    if (_voices.isEmpty) {
      try {
        final raw = await _tts.getLanguages;
        final seen = <String>{};
        if (raw is List) {
          for (final item in raw) {
            final lang = item.toString();
            if (lang.isNotEmpty && seen.add(lang)) {
              _voices.add({'name': lang, 'locale': lang});
            }
          }
        }
      } catch (_) {}
    }

    _voices.sort((a, b) => (a['locale'] ?? '').compareTo(b['locale'] ?? ''));

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _set(Map<String, String>? voice) async {
    final prefs = await SharedPreferences.getInstance();
    if (voice == null) {
      await prefs.remove('voice_name');
      await prefs.remove('voice_locale');
      // Check immediately before setState: the awaits above can outlive the
      // widget, and a mounted check before them does not cover the gap.
      if (!mounted) return;
      setState(() => _selectedVoiceName = null);
    } else {
      final name = voice['name'] ?? '';
      final locale = voice['locale'] ?? '';
      await prefs.setString('voice_name', name);
      await prefs.setString('voice_locale', locale);
      if (!mounted) return;
      setState(() => _selectedVoiceName = name);
    }
  }

  String _voiceLabel(Map<String, String> voice) {
    final name = voice['name'] ?? '';
    final locale = voice['locale'] ?? '';
    if (name == locale) return locale;
    final gender = name.contains('male')
        ? '(male)'
        : name.contains('female')
        ? '(female)'
        : '';
    return '$locale $gender  [$name]';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: ExpressiveLoadingIndicator()),
        ),
      );
    }

    if (_voices.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            context.l10n.no_tts_voices_found_ninstall_google_text_to_speech_and,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final items = <DropdownMenuItem<Map<String, String>?>>[
      DropdownMenuItem(
        value: null,
        child: Text(context.l10n.auto_device_default),
      ),
      ..._voices.map(
        (v) => DropdownMenuItem(
          value: v,
          child: Text(
            _voiceLabel(v),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    final current = _selectedVoiceName != null
        ? _voices.where((v) => v['name'] == _selectedVoiceName).firstOrNull
        : null;

    return DropdownButtonFormField<Map<String, String>?>(
      initialValue: current,
      decoration: InputDecoration(
        labelText: context.l10n.voice,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items,
      onChanged: _set,
    );
  }
}

/// Checkbox list of session sources. Unchecked sources are filtered
/// client-side from the fetched session list by `Session.source`.
class _SessionSourcesFilter extends StatefulWidget {
  final String connectionId;
  const _SessionSourcesFilter({required this.connectionId});

  @override
  State<_SessionSourcesFilter> createState() => _SessionSourcesFilterState();
}

class _SessionSourcesFilterState extends State<_SessionSourcesFilter> {
  /// Known session source types. Hermes Gateway persists `session.source` for
  /// every session. Sources not in this list are always shown (whitelisted).
  Map<String, String> get _knownSources => {
    'acp': context.l10n.autonomous_agents,
    'api_server': context.l10n.external_api_clients,
    'cli': context.l10n.command_line_chats,
    'cron': context.l10n.scheduled_tasks,
    'desktop': context.l10n.desktop_app,
    'discord': context.l10n.discord_chats,
    'gateway': context.l10n.gateway_api_access,
    'mobile': context.l10n.phone_or_tablet,
    'signal': context.l10n.signal_messages,
    'slack': context.l10n.slack_chats,
    'telegram': context.l10n.telegram_messages,
    'tool': context.l10n.developer_tool_calls,
    'tui': context.l10n.terminal_sessions,
    'whatsapp': context.l10n.whatsapp_messages,
  };

  Set<String> _excluded = {};

  String get _prefsKey => 'excluded_session_sources_${widget.connectionId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _excluded = prefs.getStringList(_prefsKey)?.toSet() ?? {};
    });
  }

  Future<void> _toggle(String source, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (enabled) {
        _excluded.remove(source);
      } else {
        _excluded.add(source);
      }
    });
    await prefs.setStringList(_prefsKey, _excluded.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: _knownSources.entries.map((entry) {
          final source = entry.key;
          final label = entry.value;
          final isVisible = !_excluded.contains(source);
          return CheckboxListTile(
            title: Text(label),
            subtitle: Text(
              source,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            value: isVisible,
            onChanged: (val) => _toggle(source, val ?? true),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
          );
        }).toList(),
      ),
    );
  }
}

/// Desktop-parity notification settings: one master switch, a toggle per kind,
/// and the same "send test" affordance so a silent OS-level block is visible
/// instead of looking like a dead feature.
class _NotificationSettings extends StatefulWidget {
  const _NotificationSettings();

  @override
  State<_NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<_NotificationSettings> {
  @override
  void initState() {
    super.initState();
    // Resolve the Android 13+ permission state so a denied app shows the hint
    // instead of looking silently broken.
    unawaited(
      TurnNotificationService.shared.ensureInitialized().then((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  static String _kindLabel(BuildContext context, HermesNotificationKind kind) =>
      switch (kind) {
        HermesNotificationKind.approval => context.l10n.approval_needed,
        HermesNotificationKind.input => context.l10n.input_needed,
        HermesNotificationKind.turnDone => context.l10n.response_complete,
        HermesNotificationKind.turnError => context.l10n.turn_failed,
        HermesNotificationKind.backgroundDone =>
          context.l10n.background_task_completed,
        HermesNotificationKind.credits => context.l10n.credit_notifications,
        HermesNotificationKind.plugin => context.l10n.plugin_notifications,
      };

  static String _kindDescription(
    BuildContext context,
    HermesNotificationKind kind,
  ) => switch (kind) {
    HermesNotificationKind.approval => context.l10n.approval_needed_description,
    HermesNotificationKind.input => context.l10n.input_needed_description,
    HermesNotificationKind.turnDone =>
      context.l10n.response_complete_description,
    HermesNotificationKind.turnError => context.l10n.turn_failed_description,
    HermesNotificationKind.backgroundDone =>
      context.l10n.background_task_completed_description,
    HermesNotificationKind.credits =>
      context.l10n.credit_notifications_description,
    HermesNotificationKind.plugin =>
      context.l10n.plugin_notifications_description,
  };

  Future<void> _sendTest() async {
    final ok = await TurnNotificationService.shared.sendTestNotification(
      title: context.l10n.test_notification_title,
      body: context.l10n.test_notification_body,
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? context.l10n.test_notification_sent
                : context.l10n.test_notification_unsupported,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NotificationPrefs>(
      valueListenable: notificationPrefs,
      builder: (context, prefs, _) => Card(
        child: Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: Text(context.l10n.enable_notifications),
              subtitle: Text(context.l10n.enable_notifications_description),
              value: prefs.enabled,
              onChanged: (on) =>
                  unawaited(NotificationPrefsStore.setEnabled(on)),
            ),
            for (final kind in HermesNotificationKind.values) ...[
              const Divider(height: 1),
              SwitchListTile(
                title: Text(_kindLabel(context, kind)),
                subtitle: Text(_kindDescription(context, kind)),
                value: prefs.enabled && prefs.kinds[kind] == true,
                onChanged: prefs.enabled
                    ? (on) =>
                          unawaited(NotificationPrefsStore.setKind(kind, on))
                    : null,
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.send_outlined),
              title: Text(context.l10n.send_test_notification),
              onTap: () => unawaited(_sendTest()),
            ),
            if (!TurnNotificationService.shared.permissionGranted) ...[
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.warning_amber_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(context.l10n.notifications_permission_denied),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The connection this Settings page edits, as a hero card: its shape mark,
/// name and address.
class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.connection});

  final SavedConnection connection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(HermesSpacing.xl - 4),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(HermesRadius.xlPlus),
        ),
        child: Row(
          children: [
            // The connection's shape, filled with primary so it stands out
            // on the primary-container card.
            ExcludeSemantics(
              child: SizedBox.square(
                dimension: 56,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: scheme.primary,
                    shape: ExpressiveShapeBorder(
                      MarkStyle.forKey(connection.label).shape,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      connection.label.trim().isEmpty
                          ? '?'
                          : connection.label
                                .trim()
                                .characters
                                .first
                                .toUpperCase(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: HermesSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connection.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    connection.baseUrl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
