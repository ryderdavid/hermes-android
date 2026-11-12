import 'package:flutter/material.dart';
import '../theme/hermes_theme.dart';

import '../models/gateway_insight.dart';

import 'package:hermes_android/core/l10n/l10n.dart';

class GatewaySubagentCard extends StatelessWidget {
  final List<GatewaySubagentActivity> activities;

  const GatewaySubagentCard({required this.activities, super.key});

  @override
  Widget build(BuildContext context) {
    final complete = activities.every((activity) => activity.isComplete);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        initiallyExpanded: !complete,
        leading: Icon(
          complete ? Icons.hub_outlined : Icons.account_tree_outlined,
        ),
        title: Text(
          complete
              ? context.l10n.delegated_tasks_completed(activities.length)
              : context.l10n.delegated_tasks_active(
                  activities.where((item) => !item.isComplete).length,
                ),
        ),
        children: [
          for (final activity in activities)
            ListTile(
              dense: true,
              leading: activity.isComplete
                  ? Icon(
                      Icons.check_circle_outline,
                      color: HermesTokens.of(context).success,
                    )
                  : const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
              title: Text(activity.goal),
              subtitle: Text(
                [
                  activity.phase.name,
                  if (activity.model != null) activity.model!,
                  if (activity.detail != null) activity.detail!,
                ].join(' • '),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
