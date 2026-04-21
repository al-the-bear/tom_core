/// Phase 4 — File upload field.
///
/// `FileRef` is a minimal value type — name + size + mime + optional
/// in-memory bytes — chosen so the field works without dragging a file
/// picker package into `tom_flutter_ui`. Apps wire a concrete
/// `picker` callback when constructing the field; the framework calls
/// it on user action and stores whatever `FileRef` it returns.
///
/// Two concretes ship:
///   * [TomFormFileUpload] — compact "Choose file…" button + selected
///     file caption.
///   * [TomFormFileDropzone] — large dashed drop-target surface that
///     also opens the picker on tap.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../decoration/tom_generic_field_decoration_mixin.dart';
import '../style/tom_form_style.dart';
import '../style/tom_form_style_scope.dart';
import '../tom_form.dart';
import 'tom_field_widget_adapter.dart';

/// Lightweight, framework-agnostic file reference. Apps may extend or
/// adapt to richer types (e.g. wrap a `PlatformFile` from `file_picker`).
@immutable
class FileRef {
  final String name;
  final int sizeBytes;
  final String? mimeType;

  /// Optional in-memory bytes (small uploads). Larger files should keep
  /// `bytes` null and stream from disk via a separate channel.
  final Uint8List? bytes;

  const FileRef({
    required this.name,
    required this.sizeBytes,
    this.mimeType,
    this.bytes,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileRef &&
          other.name == name &&
          other.sizeBytes == sizeBytes &&
          other.mimeType == mimeType;

  @override
  int get hashCode => Object.hash(name, sizeBytes, mimeType);

  @override
  String toString() =>
      'FileRef($name, $sizeBytes B${mimeType != null ? ', $mimeType' : ''})';
}

/// Picker callback contract. Returns the chosen file (or `null` if the
/// user cancels). Implementations can wrap `file_picker`, `image_picker`,
/// or any platform-specific picker.
typedef FilePicker = Future<FileRef?> Function(BuildContext context);

// ===========================================================================
// Abstract type
// ===========================================================================

abstract class TomFormFileField extends TomField<FileRef?> {
  final String? labelTextOverride;
  final String? descriptionTextOverride;

  /// Optional list of allowed file extensions (without dot, lowercase).
  /// Surfaced to the picker callback and used for client-side validation
  /// after a file is returned.
  final List<String>? allowedExtensions;

  /// Optional inclusive maximum file size in bytes.
  final int? maxSizeBytes;

  /// Required picker callback. Called when the user activates the
  /// "Choose file…" affordance.
  final FilePicker picker;

  TomFormFileField(
    super.tomId,
    super.initialValue, {
    required this.picker,
    this.labelTextOverride,
    this.descriptionTextOverride,
    this.allowedExtensions,
    this.maxSizeBytes,
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

  String? get labelText =>
      labelTextOverride ?? TomCtr.textOrNull(basePath, 'label');
  String? get descriptionText =>
      descriptionTextOverride ?? TomCtr.textOrNull(basePath, 'description');

  /// Validate the picked file against `allowedExtensions` / `maxSizeBytes`.
  /// Returns an error key string on failure, null on success.
  String? checkFile(FileRef ref) {
    if (allowedExtensions != null) {
      final dot = ref.name.lastIndexOf('.');
      final ext = dot < 0 ? '' : ref.name.substring(dot + 1).toLowerCase();
      if (!allowedExtensions!.contains(ext)) return 'error.fileExtension';
    }
    if (maxSizeBytes != null && ref.sizeBytes > maxSizeBytes!) {
      return 'error.fileTooLarge';
    }
    return null;
  }
}

// ===========================================================================
// Shared widget logic
// ===========================================================================

mixin _FileFieldStateMixin<TWidget extends StatefulWidget> on State<TWidget> {
  late final TomFunctionObserver<TomObservable> _observer;

  TomFormFileField get field;

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

  Future<void> pick() async {
    final picked = await field.picker(context);
    if (picked == null) return;
    final err = field.checkFile(picked);
    if (err != null) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(err)),
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
}

// ===========================================================================
// TomFormFileUpload — compact "Choose file…" affordance
// ===========================================================================

@tomReflector
class TomFormFileUpload extends TomFormFileField
    with TomGenericFieldDecorationMixin<FileRef?> {
  TomFormFileUpload(
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
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.dropdownStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _FileUploadWidget(field: this),
      );
}

class _FileUploadWidget extends StatefulWidget {
  final TomFormFileUpload field;
  const _FileUploadWidget({required this.field});

  @override
  State<_FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<_FileUploadWidget>
    with _FileFieldStateMixin<_FileUploadWidget> {
  @override
  TomFormFileField get field => widget.field;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final v = f.get();

    final row = Row(
      children: [
        OutlinedButton.icon(
          onPressed: f.isEditable ? pick : null,
          icon: const Icon(Icons.upload_file),
          label: const Text('Choose file…'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            v == null ? '— no file selected' : '${v.name} (${_humanSize(v.sizeBytes)})',
            style: style.inputStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (v != null && f.isEditable)
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.clear),
            onPressed: () => f.setValue(null),
          ),
      ],
    );

    return f.decorateField(context, row);
  }
}

// ===========================================================================
// TomFormFileDropzone — large dashed drop-target affordance
// ===========================================================================

@tomReflector
class TomFormFileDropzone extends TomFormFileField
    with TomGenericFieldDecorationMixin<FileRef?> {
  /// Height of the drop-zone surface.
  final double height;

  TomFormFileDropzone(
    super.tomId,
    super.initialValue, {
    required super.picker,
    this.height = 120.0,
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
  TomFieldStyle resolveStyle(BuildContext context) {
    final form = TomFormStyleScope.of(context);
    final width = TomFormStyleScope.widthOf(context);
    return form.resolveFieldStyle(form.dropdownStyle, width);
  }

  @override
  Widget get widget => TomFieldWidgetAdapter(
        field: this,
        child: _FileDropzoneWidget(field: this),
      );
}

class _FileDropzoneWidget extends StatefulWidget {
  final TomFormFileDropzone field;
  const _FileDropzoneWidget({required this.field});

  @override
  State<_FileDropzoneWidget> createState() => _FileDropzoneWidgetState();
}

class _FileDropzoneWidgetState extends State<_FileDropzoneWidget>
    with _FileFieldStateMixin<_FileDropzoneWidget> {
  @override
  TomFormFileField get field => widget.field;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final style = f.resolveStyle(context);
    final scheme = Theme.of(context).colorScheme;
    final v = f.get();

    final dropzone = InkWell(
      onTap: f.isEditable ? pick : null,
      child: Container(
        height: f.height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.outline,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                v == null ? Icons.cloud_upload_outlined : Icons.insert_drive_file_outlined,
                size: 36,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                v == null
                    ? 'Tap to choose a file'
                    : '${v.name} (${_humanSize(v.sizeBytes)})',
                style: style.inputStyle,
                overflow: TextOverflow.ellipsis,
              ),
              if (v != null && f.isEditable)
                TextButton(
                  onPressed: () => f.setValue(null),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
      ),
    );

    return f.decorateField(context, dropzone);
  }
}
