import 'dart:convert';

import 'package:hermes_android/core/services/projects_gateway_client.dart';
import 'package:hermes_android/core/services/projects_repository.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _now = 1750000000.0;

const _titles = [
  'Deploy the photo backup job',
  'Why is the print queue stuck?',
  'Summarise yesterday’s build logs',
  'Plan the garden irrigation schedule',
  'Rename the media library folders',
  'Draft the quarterly budget note',
];

/// A gateway with a healthy API server, a short page of chats and a short
/// transcript, for goldens and accessibility checks of loaded screens.
class FixtureGateway extends http.BaseClient {
  http.StreamedResponse _json(Object body) => http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    200,
    headers: {'content-type': 'application/json'},
  );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.endsWith('/health')) return _json({'status': 'ok'});
    if (path.endsWith('/api/sessions')) {
      if (!request.url.queryParameters.containsKey('offset')) {
        return _json({'object': 'list', 'data': [], 'has_more': false});
      }
      if (request.url.queryParameters['offset'] != '0') {
        return _json({'object': 'list', 'data': [], 'has_more': false});
      }
      return _json({
        'object': 'list',
        'has_more': false,
        'data': [
          for (var i = 0; i < _titles.length; i++)
            {
              'id': 'chat-$i',
              'title': _titles[i],
              'model': 'gpt-oss-20b',
              'source': i.isEven ? 'gateway' : 'cli',
              'message_count': 4 + i,
              'preview': 'Last reply from Hermes about ${_titles[i]}',
              'started_at': _now - i * 3600,
              'last_active': _now - i * 3600,
            },
        ],
      });
    }
    if (path.endsWith('/messages')) {
      return _json({
        'data': [
          {
            'role': 'user',
            'content': 'Can you check why the nightly backup failed?',
          },
          {
            'role': 'assistant',
            'content':
                'The backup stopped because the target disk was full. '
                'I cleared old snapshots and re-ran it:\n\n'
                '```bash\nrestic forget --keep-daily 7 --prune\n'
                'restic backup ~/Photos\n```\n\n'
                'It finished in **4 min 12 s**.',
          },
          {'role': 'user', 'content': 'Great — schedule it for 2am.'},
        ],
      });
    }
    return _json(<String, Object?>{});
  }
}

Future<ProjectsRepository> fixtureProjects(String connectionId) async {
  return ProjectsRepository(
    client: ProjectsGatewayClient((method, params) async {
      if (method == 'projects.list') {
        return {
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'projects': [
              for (final name in ['Home lab', 'Garden'])
                {
                  'id': name.toLowerCase().replaceAll(' ', '-'),
                  'slug': name.toLowerCase(),
                  'name': name,
                  'archived': false,
                  'created_at': 1750000000,
                  'folders': const [],
                },
            ],
            'active_id': null,
          },
        };
      }
      if (method == 'projects.tree') {
        return {
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'projects': const [],
            'active_id': null,
            'scoped_session_ids': const [],
          },
        };
      }
      return {'jsonrpc': '2.0', 'id': 1, 'result': const {}};
    }),
    preferences: await SharedPreferences.getInstance(),
    connectionId: connectionId,
  );
}
