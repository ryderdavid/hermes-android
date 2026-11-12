import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/coordinator_mode_store.dart';
import '../expressive/expressive.dart';

/// The Settings switch for "New chats use coordinator mode".
///
/// It only sets what a new chat starts with. Each chat keeps its own value
/// from then on, changed from the chat's menu.
class CoordinatorDefaultTile extends StatefulWidget {
  const CoordinatorDefaultTile({super.key});

  @override
  State<CoordinatorDefaultTile> createState() => _CoordinatorDefaultTileState();
}

class _CoordinatorDefaultTileState extends State<CoordinatorDefaultTile> {
  CoordinatorModeStore? _store;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final store = await CoordinatorModeStore.open();
    coordinatorNewChatsDefault.value = store.newChatsDefault;
    if (mounted) setState(() => _store = store);
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return ValueListenableBuilder<bool>(
      valueListenable: coordinatorNewChatsDefault,
      builder: (context, enabled, _) => SwitchListTile(
        key: const Key('settings-coordinator-default'),
        secondary: const TonalIcon(Icons.hub_outlined),
        title: Text(context.l10n.coordinator_default_new_chats),
        subtitle: Text(context.l10n.coordinator_default_new_chats_subtitle),
        value: enabled,
        onChanged: store == null
            ? null
            : (on) => unawaited(store.setNewChatsDefault(on)),
      ),
    );
  }
}
