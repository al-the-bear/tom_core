/// Cupertino File concretes.
///
/// Two concretes that subclass the same `TomFormFileField` abstract used
/// by the Material side:
///   * [TomCupertinoFormFileUpload]  → `CupertinoButton.filled` + selected
///                                     file caption + clear icon.
///   * [TomCupertinoFormFileThumbnail] → square preview of the file's own
///                                     content, with the file-kind icon as
///                                     the fallback.
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
import '../../files/tom_file_labels.dart';
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
      title: Text(TomFileLabels.rejectedTitle(field.basePath)),
      content: Text(rejectionMessage(errorKey)),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(TomFileLabels.rejectedDismiss(field.basePath)),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.cloud_upload, size: 16),
              const SizedBox(width: 6),
              Text(TomFileLabels.choose(f.basePath)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            v == null
                ? TomFileLabels.none(f.basePath)
                : selectedCaption(v),
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
            basePath: f.basePath,
            onCancel: cancelTransfer,
            onRetry: retryTransfer,
          ),
      ],
    );

    return f.decorateField(context, column);
  }
}

// ===========================================================================
// TomCupertinoFormFileThumbnail — square preview of the file itself
// ===========================================================================

/// The Cupertino sibling of `TomFormFileThumbnail`.
///
/// Same abstract base, same preview logic — `TomFileThumbnailStateMixin`
/// decides what can be painted and fetches a stored file's bytes once — and
/// only the chrome differs: Cupertino icons, a `GestureDetector` where the
/// Material side uses an `InkWell`, and the hand-built transfer status row.
@tomReflector
class TomCupertinoFormFileThumbnail extends TomFormFileField
    with TomGenericFieldDecorationMixin<FileRef?> {
  /// Edge length of the square preview surface.
  final double thumbnailSize;

  TomCupertinoFormFileThumbnail(
    super.tomId,
    super.initialValue, {
    super.picker,
    super.pickKind,
    super.transferClient,
    super.storageSlot,
    super.autoUpload,
    super.onDownload,
    this.thumbnailSize = 96.0,
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
    child: _CupertinoFileThumbnailWidget(field: this),
  );
}

class _CupertinoFileThumbnailWidget extends StatefulWidget {
  final TomCupertinoFormFileThumbnail field;
  const _CupertinoFileThumbnailWidget({required this.field});

  @override
  State<_CupertinoFileThumbnailWidget> createState() =>
      _CupertinoFileThumbnailWidgetState();
}

class _CupertinoFileThumbnailWidgetState
    extends State<_CupertinoFileThumbnailWidget>
    with
        TomFileFieldStateMixin<_CupertinoFileThumbnailWidget>,
        TomFileThumbnailStateMixin<_CupertinoFileThumbnailWidget> {
  @override
  TomCupertinoFormFileThumbnail get field => widget.field;

  @override
  Future<void> showFileRejected(String errorKey) => showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(TomFileLabels.rejectedTitle(field.basePath)),
      content: Text(rejectionMessage(errorKey)),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(TomFileLabels.rejectedDismiss(field.basePath)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final v = f.get();
    final size = f.thumbnailSize;

    final placeholder = Icon(
      v == null ? CupertinoIcons.photo : CupertinoIcons.doc,
      size: size / 2.5,
      color: CupertinoColors.systemGrey,
    );

    final preview = GestureDetector(
      onTap: f.isEditable && f.canPick ? pick : null,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: CupertinoColors.systemGrey4.resolveFrom(context),
          ),
        ),
        child: Center(
          child: previewOrFallback(size: size, fallback: placeholder),
        ),
      ),
    );

    final row = Row(
      children: [
        preview,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            v == null ? TomFileLabels.none(f.basePath) : selectedCaption(v),
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
            basePath: f.basePath,
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
///
/// The chrome differs from the Material indicator; the *wording* deliberately
/// does not. Both read the same [TomFileLabels] keys, so an application that
/// translates its file widgets translates them once rather than once per
/// widget family.
class _CupertinoTransferStatus extends StatelessWidget {
  const _CupertinoTransferStatus({
    required this.controller,
    this.basePath,
    this.onCancel,
    this.onRetry,
  });

  final TomFileTransferController controller;

  /// The field's resource path, so this row's wording can be overridden per
  /// field exactly as the Material indicator's can.
  final String? basePath;
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
            return _row(
              child: Row(
                children: [
                  const CupertinoActivityIndicator(radius: 8),
                  const SizedBox(width: 8),
                  Text(
                    _runningLabel(state),
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
                      child: Text(
                        TomFileLabels.cancel(basePath),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
            );

          case TomTransferPhase.cancelled:
          case TomTransferPhase.failed:
            final failed = state.phase == TomTransferPhase.failed;
            return _row(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      // A cancellation is not a failure and must not borrow a
                      // failure's wording: the user asked for it, and the
                      // transfer often carries no error to describe.
                      failed
                          ? tomTransferErrorMessage(state, basePath: basePath)
                          : TomFileLabels.cancelled(basePath),
                      style: TextStyle(
                        fontSize: 13,
                        color: failed
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
                      child: Text(
                        TomFileLabels.retry(basePath),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
            );
        }
      },
    );
  }

  /// The progress line, on the same keys the Material indicator uses.
  String _runningLabel(TomFileTransferState state) {
    final isDownload = state.kind == TomTransferKind.download;
    final fraction = state.fraction;
    return fraction == null
        ? TomFileLabels.progressBusy(basePath, isDownload)
        : TomFileLabels.progress(basePath, isDownload, (fraction * 100).round());
  }

  Widget _row({required Widget child}) =>
      Padding(padding: const EdgeInsets.only(top: 6), child: child);
}
