import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A Hermes dashboard that serves a session token, the model endpoints the
/// Settings screen reads, and `{}` for anything else, so screens that talk to
/// the dashboard render their loaded state in widget and golden tests.
///
/// Use with `http.runWithClient(body, () => fakeDashboardClient())`.
http.Client fakeDashboardClient({Map<String, Object?> extra = const {}}) {
  return MockClient((request) async {
    final path = request.url.path;
    if (path == '/' || path.isEmpty) {
      return http.Response(
        '<script>window.__HERMES_SESSION_TOKEN__="fixture-token";</script>',
        200,
      );
    }
    final routes = <String, Object?>{
      '/api/model/info': {
        'model': 'gpt-oss-20b',
        'provider': 'local',
        'effective_context_length': 131072,
      },
      '/api/model/options': {
        'providers': [
          {
            'slug': 'local',
            'models': ['gpt-oss-20b', 'qwen3-32b'],
          },
        ],
      },
      ...extra,
    };
    final body = routes[path] ?? <String, Object?>{};
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}
