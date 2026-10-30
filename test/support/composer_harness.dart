import 'package:flutter/material.dart';
import 'package:hermes_android/core/controllers/voice_composer_controller.dart';
import 'package:hermes_android/core/models/attachment_draft.dart';
import 'package:hermes_android/core/widgets/chat_composer.dart';

import 'fake_voice_composer_adapter.dart';

/// Records what a [ChatComposer] asked its host to do, and lets a test drive
/// its state the way ChatScreen would.
class ComposerHost {
  ComposerHost({String text = '', this.attachments = const []})
    : textController = TextEditingController(text: text) {
    voiceComposer = VoiceComposerController(
      textController: textController,
      adapter: FakeVoiceComposerAdapter(),
    );
  }

  final TextEditingController textController;
  late final VoiceComposerController voiceComposer;
  List<AttachmentDraft> attachments;

  bool streaming = false;
  int sends = 0;
  int stops = 0;

  ChatComposer build({double availableHeight = 600}) => ChatComposer(
    availableHeight: availableHeight,
    textController: textController,
    textEnabled: true,
    attachments: attachments,
    attachmentsBusy: false,
    onMoveAttachment: (_, _) {},
    onRetryAttachment: (_) {},
    onRemoveAttachment: (_) {},
    voiceComposer: voiceComposer,
    onStartVoice: streaming ? null : () {},
    onAttach: streaming ? null : () {},
    streaming: streaming,
    onSend: () => sends++,
    onStop: () => stops++,
    turnStatus: streaming ? 'Thinking…' : null,
  );

  /// An image draft that has finished uploading.
  static AttachmentDraft photo(int index) => AttachmentDraft(
    id: 'photo-$index',
    cachedPath: '/fixture/photo-$index.png',
    name: 'photo-$index.png',
    byteLength: 2048,
    mediaType: 'image/png',
    kind: AttachmentDraftKind.image,
    sanitized: true,
    status: AttachmentDraftStatus.attached,
  );
}

/// Hosts the composer at the bottom of a scaffold, rebuilding through
/// [StatefulBuilder] so a test can flip host state with `setState`.
class ComposerScaffold extends StatefulWidget {
  const ComposerScaffold({required this.host, super.key});

  final ComposerHost host;

  @override
  State<ComposerScaffold> createState() => ComposerScaffoldState();
}

class ComposerScaffoldState extends State<ComposerScaffold> {
  void update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          const Expanded(child: SizedBox.shrink()),
          widget.host.build(),
        ],
      ),
    );
  }
}
