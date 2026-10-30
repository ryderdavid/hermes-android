import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/chat_icons/chat_topics.dart';

void main() {
  String? topicOf(String title) => matchChatTopic(title)?.name;

  group('matchChatTopic', () {
    test('reads the titles on a real Home screen', () {
      expect(topicOf("What does this server doesn't offer background…"), 'dns');
      expect(topicOf('Update Claude Code and Claude Desktop'), 'system_update');
      expect(topicOf('Hermes settings page not loading'), 'bug_report');
      // Two subject words outweigh one "vs"; Hermes can do better.
      expect(topicOf('Conduit web UI vs Hermes Agent app'), 'smart_toy');
      expect(topicOf('Pixel vs Galaxy'), 'phone_android');
      expect(topicOf('Postgres vs SQLite'), 'table_chart');
      expect(topicOf('List available tools'), 'handyman');
      expect(topicOf('Enable Codex remote in Nacre repo'), 'terminal');
      expect(topicOf('Identify current assistant agent'), 'smart_toy');
    });

    test('matches plurals and longer forms of a word', () {
      expect(topicOf('Nightly backups'), 'cloud_sync');
      expect(topicOf('Printing the grip plate'), 'print');
      expect(topicOf('Fix the leaking garden hose'), 'water_drop');
      expect(topicOf('Dogs and cats'), 'pets');
    });

    test('a phrase beats a single word', () {
      expect(topicOf('Home Assistant automations'), 'sensors');
    });

    test('returns null when nothing fits', () {
      expect(matchChatTopic('Untitled'), isNull);
      expect(matchChatTopic(''), isNull);
      expect(matchChatTopic('…'), isNull);
    });
  });

  group('vocabulary', () {
    test('names are unique Material icon names', () {
      final names = chatTopics.map((t) => t.name).toList();
      expect(names.toSet().length, names.length);
      for (final name in names) {
        expect(name, matches(RegExp(r'^[a-z0-9_]+$')), reason: name);
      }
      expect(chatTopics.length, greaterThan(150));
    });

    test('chatTopicNamed only accepts names in the vocabulary', () {
      expect(chatTopicNamed('yard')?.name, 'yard');
      expect(chatTopicNamed(' Yard ')?.name, 'yard');
      expect(chatTopicNamed('not_an_icon'), isNull);
      expect(chatTopicNamed(null), isNull);
    });
  });
}
