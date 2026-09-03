/// The transfer UX: a progress bar, a cancel button, a retry button and an
/// error line, driven by a [TomFileTransferController].
///
/// Separate from the file fields because it is useful on its own — an upload
/// started by a form's save button, a background download, a detail page
/// showing an attachment — and because a widget that only reads a
/// `ValueListenable` is far easier to test than one embedded in a field.
///
/// It renders **nothing** while the controller is idle, so a field can include
/// it unconditionally without gaining a permanent empty row.
///
/// Every word it shows comes from [TomFileLabels], so an application localises
/// the transfer UX by declaring resources rather than by replacing the widget.
library;

import 'package:flutter/material.dart';

import 'tom_file_labels.dart';
import 'tom_file_transfer_controller.dart';

/// Shows the state of the transfer [controller] is running.
class TomFileTransferIndicator extends StatelessWidget {
  /// Creates an indicator for [controller].
  const TomFileTransferIndicator({
    super.key,
    required this.controller,
    this.basePath,
    this.onCancel,
    this.onRetry,
    this.onDownload,
    this.showSuccess = true,
  });

  /// The transfer to display.
  final TomFileTransferController controller;

  /// The resource path this indicator's wording is scoped to — a field's
  /// `basePath` when it sits inside one.
  ///
  /// Optional because the indicator is useful on its own (a background
  /// download, a detail page), and a stand-alone one simply resolves its
  /// wording from the global `file.*` keys. Supplying it is what lets one field
  /// say "Uploading picture…" while the rest say "Uploading…".
  final String? basePath;

  /// Called when the user cancels a running transfer.
  ///
  /// When `null` no cancel affordance is offered — appropriate for a transfer
  /// the user must not interrupt.
  final VoidCallback? onCancel;

  /// Called when the user retries a failed or cancelled transfer.
  final VoidCallback? onRetry;

  /// Called when the user asks to download the stored file.
  final VoidCallback? onDownload;

  /// Whether a completed transfer leaves a confirmation line behind.
  final bool showSuccess;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TomFileTransferState>(
      valueListenable: controller,
      builder: (context, state, _) => _buildFor(context, state),
    );
  }

  Widget _buildFor(BuildContext context, TomFileTransferState state) {
    final theme = Theme.of(context);
    switch (state.phase) {
      case TomTransferPhase.idle:
        return onDownload == null
            ? const SizedBox.shrink()
            : _downloadRow(context);

      case TomTransferPhase.running:
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                // A null fraction is exactly what LinearProgressIndicator
                // means by "indeterminate", so an unmeasurable transfer needs
                // no special case here.
                child: LinearProgressIndicator(value: state.fraction),
              ),
              const SizedBox(width: 8),
              Text(_runningLabel(state), style: theme.textTheme.bodySmall),
              if (onCancel != null)
                IconButton(
                  tooltip: TomFileLabels.cancel(basePath),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onCancel,
                ),
            ],
          ),
        );

      case TomTransferPhase.succeeded:
        if (!showSuccess) {
          return onDownload == null
              ? const SizedBox.shrink()
              : _downloadRow(context);
        }
        return _statusRow(
          context,
          icon: Icons.check_circle_outline,
          color: theme.colorScheme.primary,
          message: _successLabel(state),
          trailing: onDownload == null ? null : _downloadButton(),
        );

      case TomTransferPhase.cancelled:
        return _statusRow(
          context,
          icon: Icons.cancel_outlined,
          color: theme.colorScheme.onSurfaceVariant,
          message: TomFileLabels.cancelled(basePath),
          trailing: onRetry == null ? null : _retryButton(),
        );

      case TomTransferPhase.failed:
        return _statusRow(
          context,
          icon: Icons.error_outline,
          color: theme.colorScheme.error,
          message: tomTransferErrorMessage(state, basePath: basePath),
          trailing: onRetry == null ? null : _retryButton(),
        );
    }
  }

  Widget _statusRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String message,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _retryButton() => TextButton(
    onPressed: onRetry,
    child: Text(TomFileLabels.retry(basePath)),
  );

  Widget _downloadButton() => TextButton.icon(
    onPressed: onDownload,
    icon: const Icon(Icons.download, size: 16),
    label: Text(TomFileLabels.download(basePath)),
  );

  Widget _downloadRow(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Align(alignment: Alignment.centerLeft, child: _downloadButton()),
  );

  String _runningLabel(TomFileTransferState state) {
    final isDownload = state.kind == TomTransferKind.download;
    final fraction = state.fraction;
    return fraction == null
        ? TomFileLabels.progressBusy(basePath, isDownload)
        : TomFileLabels.progress(
            basePath,
            isDownload,
            (fraction * 100).round(),
          );
  }

  String _successLabel(TomFileTransferState state) => switch (state.kind) {
    TomTransferKind.upload => TomFileLabels.uploaded(basePath),
    TomTransferKind.download => TomFileLabels.downloaded(basePath),
    TomTransferKind.removal => TomFileLabels.removed(basePath),
    TomTransferKind.none => TomFileLabels.done(basePath),
  };
}

/// A user-facing message for a failed transfer.
///
/// Keyed on the transfer layer's own stable error keys, so the wording lives in
/// one place instead of being re-invented by every widget that has to show a
/// failure — and so a server that already publishes those keys localises the
/// line without anyone declaring a second vocabulary for it. [basePath] scopes
/// the lookup to a field; anything unrecognised falls back to the exception's
/// own text.
String tomTransferErrorMessage(TomFileTransferState state, {String? basePath}) {
  final fallback = switch (state.errorKey) {
    'file_transfer.not_found' => 'The file is no longer available.',
    'file_transfer.rejected' => 'The server rejected the transfer.',
    'file_transfer.cancelled' => 'Transfer cancelled.',
    'file_transfer.invalid_slot' => 'The file location is not valid.',
    'file_transfer.invalid_descriptor' =>
      'The server sent an unreadable response.',
    _ => state.error?.toString() ?? 'The transfer failed.',
  };
  final key = state.errorKey;
  if (key == null) return fallback;
  return TomFileLabels.resolve(basePath, key, fallback);
}
