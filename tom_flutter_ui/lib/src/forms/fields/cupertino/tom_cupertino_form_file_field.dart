/// Phase 5c — Cupertino File concrete.
///
/// One concrete that subclasses the same `TomFormFileField` abstract used
/// by the Material side (Phase 4):
///   * [TomCupertinoFormFileUpload]  → `CupertinoButton.filled` + selected
///                                     file caption + clear icon.
///
/// Picking errors surface through a `CupertinoAlertDialog` (Material's
/// equivalent uses `ScaffoldMessenger`, which doesn't naturally exist in
/// a pure-Cupertino tree). Otherwise the surface mirrors the Material
/// `TomFormFileUpload` exactly so mixed-family demos line up vertically.
library;

import 'package:flutter/cupertino.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../../widget_base/tom_construction_helpers.dart';
import '../../decoration/tom_generic_field_decoration_mixin.dart';
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
    required super.picker,
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

class _CupertinoFileUploadWidgetState
    extends State<_CupertinoFileUploadWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomCupertinoFormFileUpload get field => widget.field;

  @override
  void initState() {
    super.initState();
    _observer = field >> (_) {
      if (mounted) setState(() {});
    };
    field.validationListenable.addListener(_onValidationChanged);
  }

  void _onValidationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    field.validationListenable.removeListener(_onValidationChanged);
    field.removeObserver(_observer);
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await field.picker(context);
    if (picked == null) return;
    final err = field.checkFile(picked);
    if (err != null) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('File rejected'),
          content: Text(err),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    field.setValue(picked);
  }

  String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final v = f.get();

    final row = Row(
      children: [
        CupertinoButton.filled(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          onPressed: f.isEditable ? _pick : null,
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
                : '${v.name} (${_humanSize(v.sizeBytes)})',
            style: style.inputStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (v != null && f.isEditable)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: () => f.setValue(null),
            child: const Icon(
              CupertinoIcons.clear_circled_solid,
              size: 20,
              color: CupertinoColors.systemGrey,
            ),
          ),
      ],
    );

    return f.decorateField(context, row);
  }
}
