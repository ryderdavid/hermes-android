import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/voice_composer_controller.dart';
import '../l10n/l10n.dart';
import '../models/attachment_draft.dart';
import 'attachment_draft_tile.dart';
import 'voice_composer_controls.dart';

/// The chat message input bar.
///
/// Stateless: every value and callback comes from `ChatScreen`, which keeps
/// the draft, attachments, voice and turn state. A null callback disables
/// its control.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    required this.availableHeight,
    required this.textController,
    required this.textEnabled,
    required this.modelName,
    required this.modelScope,
    required this.modelLoading,
    required this.onChooseModel,
    required this.attachments,
    required this.attachmentsBusy,
    required this.onMoveAttachment,
    required this.onRetryAttachment,
    required this.onRemoveAttachment,
    required this.voiceComposer,
    required this.onStartVoice,
    required this.onAttach,
    required this.voiceReplyEnabled,
    required this.onToggleVoiceReply,
    required this.streaming,
    required this.onSend,
    required this.onStop,
    this.turnStatus,
    super.key,
  });

  /// Height the scaffold leaves for the transcript and composer together.
  final double availableHeight;

  final TextEditingController textController;
  final bool textEnabled;

  /// The gateway's live turn status line, shown while a turn runs.
  final String? turnStatus;

  final String modelName;

  /// Whether [modelName] is this chat's override or the profile default.
  final String modelScope;
  final bool modelLoading;
  final VoidCallback? onChooseModel;

  final List<AttachmentDraft> attachments;
  final bool attachmentsBusy;
  final void Function(AttachmentDraft draft, int offset) onMoveAttachment;
  final void Function(AttachmentDraft draft) onRetryAttachment;
  final void Function(AttachmentDraft draft) onRemoveAttachment;

  final VoiceComposerController voiceComposer;
  final VoidCallback? onStartVoice;
  final VoidCallback? onAttach;

  final bool voiceReplyEnabled;
  final VoidCallback onToggleVoiceReply;

  /// A turn is streaming: the primary action is Stop.
  final bool streaming;
  final VoidCallback? onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    const minimumControlsHeight = 56.0;
    final composerMaxHeight = availableHeight <= minimumControlsHeight
        ? availableHeight
        : (availableHeight * 0.85)
              .clamp(minimumControlsHeight, availableHeight)
              .toDouble();
    return Container(
      key: const Key('chat-input-bar'),
      // Leave some transcript visible when space permits. At very small
      // heights, the fixed controls take priority and extras scroll away.
      constraints: BoxConstraints(maxHeight: composerMaxHeight),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (turnStatus != null) _buildTurnStatus(context),
                    _buildModelButton(context),
                    if (attachments.isNotEmpty) _buildAttachmentTray(context),
                    if (voiceComposer.listening)
                      VoiceComposerIndicator(
                        controller: voiceComposer,
                        onStop: () => unawaited(voiceComposer.stop()),
                        onCancel: () => unawaited(voiceComposer.cancel()),
                      ),
                  ],
                ),
              ),
            ),
            _buildInputRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnStatus(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              turnStatus!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
        child: Semantics(
          label: context.l10n.choose_chat_model,
          value: modelName,
          button: true,
          enabled: onChooseModel != null,
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton.icon(
              onPressed: onChooseModel,
              icon: modelLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.tune, size: 18),
              label: Text(
                context.l10n.model_scope_label(modelName, modelScope),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentTray(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Semantics(
        label: context.l10n.attachment_drafts,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // Scaffold has already subtracted the keyboard and app bar.
            maxHeight: availableHeight * 0.32,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: attachments.length,
            itemBuilder: (context, index) => AttachmentDraftTile(
              draft: attachments[index],
              index: index,
              total: attachments.length,
              busy: attachmentsBusy,
              onMovePrevious: () => onMoveAttachment(attachments[index], -1),
              onMoveNext: () => onMoveAttachment(attachments[index], 1),
              onRetry: () => onRetryAttachment(attachments[index]),
              onRemove: () => onRemoveAttachment(attachments[index]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow(BuildContext context) {
    return Row(
      children: [
        Semantics(
          label: context.l10n.add_attachment,
          button: true,
          enabled: onAttach != null,
          excludeSemantics: true,
          child: IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: onAttach,
            tooltip: context.l10n.attach_image_or_file,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          ),
        ),
        Expanded(
          child: Semantics(
            label: context.l10n.message,
            textField: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (availableHeight * 0.30).clamp(48.0, 160.0),
              ),
              child: TextField(
                key: const Key('chat-message-composer'),
                controller: textController,
                decoration: InputDecoration(
                  hintText: context.l10n.message_hermes,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                enabled: textEnabled,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (!voiceComposer.listening)
          VoiceComposerStartButton(
            enabled: onStartVoice != null,
            onPressed: onStartVoice ?? () {},
          ),
        Semantics(
          label: context.l10n.spoken_replies,
          value: voiceReplyEnabled ? context.l10n.on : context.l10n.off,
          toggled: voiceReplyEnabled,
          button: true,
          excludeSemantics: true,
          child: IconButton(
            icon: Icon(voiceReplyEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: onToggleVoiceReply,
            tooltip: voiceReplyEnabled
                ? context.l10n.spoken_replies_on
                : context.l10n.spoken_replies_off,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          ),
        ),
        const SizedBox(width: 4),
        Semantics(
          label: streaming
              ? context.l10n.stop_response
              : context.l10n.send_message,
          button: true,
          enabled: streaming || onSend != null,
          excludeSemantics: true,
          child: SizedBox.square(
            dimension: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: streaming
                  ? IconButton(
                      icon: const Icon(Icons.stop_rounded, size: 20),
                      onPressed: onStop,
                      tooltip: context.l10n.stop_response,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send, size: 20),
                      onPressed: onSend,
                      tooltip: context.l10n.send,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
