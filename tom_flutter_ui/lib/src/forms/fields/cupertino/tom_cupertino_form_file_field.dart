/// Cupertino File concrete.
///
/// One concrete that subclasses the same `TomFormFileField` abstract used
/// by the Material side:
///   * [TomCupertinoFormFileUpload]  → `CupertinoButton.filled` + selected
///                                     file caption + clear icon.
///
/// Picking errors surface through a `CupertinoAlertDialog` (Material's
/// equivalent uses `ScaffoldMessenger`, which doesn't naturally exist in
/// a pure-Cupertino tree). Otherwise the surface mirrors the Material
/// `TomFormFileUpload` exactly so mixed-family demos line up vertically.
///
/// The picker, upload and download behaviour is shared with the Material side
/// through `TomFileFieldStateMixin`; only the chrome differs — which is why
/// the transfer status row below is hand-built from Cupertino widgets rather
/// than reusing `TomFileTransferIndicator`.
library;

import 'package:flutter/cupertino.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../../widget_base/tom_construction_helpers.dart';
import '../../decoration/tom_generic_field_decoration_mixin.dart';
import '../../files/tom_file_transfer_controller.dart';
import '../../files/tom_file_transfer_indicator.dart';
import '../../style/tom_form_style.dart';
import '../../style/tom_form_style_scope.dart';
import '../tom_field_widget_adapter.dart';
import '../tom_form_file_field.dart';

@tomReflector
class TomCupertinoFormFileUpload extends TomFormFileField
    with TomGenericFieldDecorationMixin<FileRef?> {
  TomCupertinoFormFileUpload(
    super.tomId,
    super.initialValue, {
    super.picker,
    super.pickKind,
    super.transferClient,
    super.storageSlot,
    super.autoUpload,
    super.onDownload,
    super.labelTextOverride,
    super.descriptionTextOverride,
    super.allowedExtensions,
    super.maxSizeBytes,
    super.form,
    super.validators,
    super.autoValidate,
    super.tomGroup,
    super.authorizer,
    super.uiStateController,
    super.actionIcon,
    super.actionIconTooltip,
    super.onActionIconPressed,
  });

  @override
  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');

  @override
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  @override
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.dropdownStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
    field: this,
    child: _CupertinoFileUploadWidget(field: this),
  );
}

class _CupertinoFileUploadWidget extends StatefulWidget {
  final TomCupertinoFormFileUpload field;
  const _CupertinoFileUploadWidget({required this.field});

  @override
  State<_CupertinoFileUploadWidget> createState() =>
      _CupertinoFileUploadWidgetState();
}

class _CupertinoFileUploadWidgetState extends State<_CupertinoFileUploadWidget>
    with TomFileFieldStateMixin<_CupertinoFileUploadWidget> {
  @override
  TomCupertinoFormFileUpload get field => widget.field;

  @override
  Future<void> showFileRejected(String errorKey) => showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('File rejected'),
      content: Text(errorKey),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final v = f.get();

    final row = Row(
      children: [
        CupertinoButton.filled(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          onPressed: f.isEditable && f.canPick ? pick : null,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.cloud_upload, size: 16),
              SizedBox(width: 6),
              Text('Choose file…'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            v == null
                ? '— no file selected'
                : '${v.name} (${humanSize(v.sizeBytes)})',
            style: style.inputStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (canDownload)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: download,
            child: const Icon(
              CupertinoIcons.cloud_download,
              size: 20,
              color: CupertinoColors.activeBlue,
            ),
          ),
        if (v != null && f.isEditable)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: clear,
            child: const Icon(
              CupertinoIcons.clear_circled_solid,
              size: 20,
              color: CupertinoColors.systemGrey,
            ),
          ),
      ],
    );

    final controller = transferController;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        if (controller != null)
          _CupertinoTransferStatus(
            controller: controller,
            onCancel: cancelTransfer,
            onRetry: retryTransfer,
          ),
      ],
    );

    return f.decorateField(context, column);
  }
}

/// The Cupertino counterpart of `TomFileTransferIndicator`.
///
/// Renders nothing while idle, so it can be included unconditionally.
class _CupertinoTransferStatus extends StatelessWidget {
  const _CupertinoTransferStatus({
    required this.controller,
    this.onCancel,
    this.onRetry,
  });

  final TomFileTransferController controller;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TomFileTransferState>(
      valueListenable: controller,
      builder: (context, state, _) {
        switch (state.phase) {
          case TomTransferPhase.idle:
          case TomTransferPhase.succeeded:
            return const SizedBox.shrink();

          case TomTransferPhase.running:
            final fraction = state.fraction;
            return _row(
              child: Row(
                children: [
                  const CupertinoActivityIndicator(radius: 8),
                  const SizedBox(width: 8),
                  Text(
                    fraction == null
                        ? 'Transferring…'
                        : 'Transferring ${(fraction * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const Spacer(),
                  if (onCancel != null)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(28, 28),
                      onPressed: onCancel,
                      child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            );

          case TomTransferPhase.cancelled:
          case TomTransferPhase.failed:
            return _row(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tomTransferErrorMessage(state),
                      style: TextStyle(
                        fontSize: 13,
                        color: state.phase == TomTransferPhase.failed
                            ? CupertinoColors.systemRed
                            : CupertinoColors.systemGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onRetry != null)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(28, 28),
                      onPressed: onRetry,
                      child: const Text('Retry', style: TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            );
        }
      },
    );
  }

  Widget _row({required Widget child}) =>
      Padding(padding: const EdgeInsets.only(top: 6), child: child);
}
