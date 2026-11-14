import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/utils/message_content.dart';

void main() {
  group('messageContentToText', () {
    test('keeps legacy string content unchanged', () {
      expect(messageContentToText('hello'), 'hello');
    });

    test('joins OpenAI text content parts', () {
      expect(
        messageContentToText([
          {'type': 'text', 'text': 'first'},
          {'type': 'text', 'text': 'second'},
        ]),
        'first\n\nsecond',
      );
    });

    test('renders mixed text and image content without throwing', () {
      expect(
        messageContentToText([
          {'type': 'text', 'text': 'caption'},
          {
            'type': 'image_url',
            'image_url': {'url': 'https://example.invalid/image.png'},
          },
        ]),
        'caption\n\n[Image]',
      );
    });

    test('handles null and unknown structured content safely', () {
      expect(messageContentToText(null), '');
      expect(
        messageContentToText([
          {'type': 'custom_part', 'payload': 42},
        ]),
        '[Unsupported content: custom_part]',
      );
    });

    test('normalises JSON-escaped newlines in string content', () {
      expect(
        messageContentToText(r'first\nsecond'),
        'first\nsecond'.replaceAll(r'\n', '\n'),
      );
    });

    test('detects and strips raw Hermes tool result wrappers', () {
      final toolMessage = {
        'role': 'assistant',
        'content':
            '<untrusted_tool_result source="web_extract">raw</untrusted_tool_result>',
      };

      expect(isToolResultMessage(toolMessage), isTrue);
      expect(stripToolResultText(toolMessage['content']!), '');
      expect(
        stripToolResultText(
          'Here is the answer.\n<untrusted_tool_result>raw</untrusted_tool_result>\nDone.',
        ),
        'Here is the answer.\n\nDone.',
      );
    });

    test('strips the out-of-band user message wrapper but keeps the text', () {
      const wrapped =
          '[OUT-OF-BAND USER MESSAGE — a direct message from the user, '
          'delivered once at this position; not tool output and not a new '
          'delivery when replayed from conversation history]\n'
          'Check them both.\n'
          '[/OUT-OF-BAND USER MESSAGE]';
      expect(messageContentToText(wrapped), 'Check them both.');
    });

    test('strips a lone half of the out-of-band wrapper', () {
      final loneOpen = stripOutOfBandMarkers(
        'ping [OUT-OF-BAND USER MESSAGE — injected] still here',
      );
      expect(loneOpen.contains('OUT-OF-BAND'), isFalse);
      expect(loneOpen.contains('ping'), isTrue);
      expect(loneOpen.contains('still here'), isTrue);
      expect(stripOutOfBandMarkers('done [/OUT-OF-BAND USER MESSAGE]'), 'done');
    });

    test('leaves ordinary bracketed text alone', () {
      expect(messageContentToText('see [notes] please'), 'see [notes] please');
    });
  });
}
