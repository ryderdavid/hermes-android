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
      color: Theme.of(context).colorScheme.surface,
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
                    _buildChipRow(context),
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

  /// Model and spoken-reply controls as compact chips above the field, so
  /// the input row holds only the field and the send button.
  Widget _buildChipRow(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: Row(
          children: [
            Semantics(
              label: l10n.choose_chat_model,
              value: modelName,
              button: true,
              enabled: onChooseModel != null,
              excludeSemantics: true,
              child: ConstrainedBox(
                // Long model ids ellipsize instead of pushing the row wide.
                constraints: const BoxConstraints(maxWidth: 260),
                child: ActionChip(
                  key: const Key('chat-model-chip'),
                  avatar: modelLoading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.tune, size: 18),
                  label: Text(
                    l10n.model_scope_label(modelName, modelScope),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: onChooseModel,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: l10n.spoken_replies,
              value: voiceReplyEnabled ? l10n.on : l10n.off,
              toggled: voiceReplyEnabled,
              button: true,
              excludeSemantics: true,
              child: Tooltip(
                message: voiceReplyEnabled
                    ? l10n.spoken_replies_on
                    : l10n.spoken_replies_off,
                child: FilterChip(
                  key: const Key('chat-spoken-replies-chip'),
                  avatar: Icon(
                    voiceReplyEnabled ? Icons.volume_up : Icons.volume_off,
                    size: 18,
                  ),
                  showCheckmark: false,
                  label: Text(l10n.spoken_replies),
                  selected: voiceReplyEnabled,
                  onSelected: (_) => onToggleVoiceReply(),
                ),
              ),
            ),
          ],
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

  /// One rounded field that owns attach (leading) and dictation (trailing),
  /// with a single send/stop button outside it, bottom-aligned and never
  /// taller than the field.
  Widget _buildInputRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const noBorder = InputBorder.none;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            key: const Key('chat-composer-field'),
            constraints: const BoxConstraints(minHeight: fieldHeight),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(fieldHeight / 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Semantics(
                  label: context.l10n.add_attachment,
                  button: true,
                  enabled: onAttach != null,
                  excludeSemantics: true,
                  child: IconButton(
                    icon: const Icon(Icons.attach_file),
                    color: scheme.onSurfaceVariant,
                    onPressed: onAttach,
                    tooltip: context.l10n.attach_image_or_file,
                    constraints: const BoxConstraints.tightFor(
                      width: fieldHeight,
                      height: fieldHeight,
                    ),
                  ),
                ),
                Expanded(
                  // The field is centred in the 48dp pill: a field stretched
                  // by an outer constraint puts all its spare height below
                  // the text. Merged semantics keep the whole pill height as
                  // the field's touch target, and at the minimum height the
                  // editable keeps more than a line of viewport.
                  child: MergeSemantics(
                    child: Semantics(
                      label: context.l10n.message,
                      textField: true,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: fieldHeight,
                          maxHeight: (availableHeight * 0.30).clamp(
                            fieldHeight,
                            160.0,
                          ),
                        ),
                        child: Align(
                          heightFactor: 1,
                          child: TextField(
                            key: const Key('chat-message-composer'),
                            controller: textController,
                            decoration: InputDecoration(
                              hintText: context.l10n.message_hermes,
                              filled: false,
                              border: noBorder,
                              enabledBorder: noBorder,
                              focusedBorder: noBorder,
                              disabledBorder: noBorder,
                              contentPadding: const EdgeInsets.symmetric(
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
                  ),
                ),
                if (!voiceComposer.listening)
                  VoiceComposerStartButton(
                    enabled: onStartVoice != null,
                    onPressed: onStartVoice ?? () {},
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildSendButton(context),
      ],
    );
  }

  Widget _buildSendButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: streaming ? context.l10n.stop_response : context.l10n.send_message,
      button: true,
      enabled: streaming || onSend != null,
      excludeSemantics: true,
      child: streaming
          ? IconButton.filled(
              icon: const Icon(Icons.stop_rounded),
              onPressed: onStop,
              tooltip: context.l10n.stop_response,
              constraints: const BoxConstraints.tightFor(
                width: fieldHeight,
                height: fieldHeight,
              ),
            )
          : ListenableBuilder(
              listenable: textController,
              builder: (context, _) {
                // Empty sends are already a no-op in ChatScreen; the button
                // just looks disabled until there is something to send.
                final hasContent =
                    textController.text.trim().isNotEmpty ||
                    attachments.isNotEmpty;
                final looksEnabled = onSend != null && hasContent;
                return IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: onSend,
                  tooltip: context.l10n.send,
                  style: looksEnabled
                      ? null
                      : IconButton.styleFrom(
                          backgroundColor: scheme.onSurface.withValues(
                            alpha: 0.12,
                          ),
                          foregroundColor: scheme.onSurface.withValues(
                            alpha: 0.38,
                          ),
                        ),
                  constraints: const BoxConstraints.tightFor(
                    width: fieldHeight,
                    height: fieldHeight,
                  ),
                );
              },
            ),
    );
  }

  /// Height of the rounded field at one line, and of the send button.
  static const double fieldHeight = 48;
}
