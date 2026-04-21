/// Form for Demo L — File upload + nullable input variants.
///
/// File fields don't bind into a `TomClass` (no `TomObject<FileRef>` in
/// the kernel), so they live directly on the form. The nullable text /
/// numeric / date inputs all bind into [FileNullableDemoState].
library;

import 'package:flutter/foundation.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/phase4_state.dart';

@tomReflector
class FileNullableDemoForm extends TomForm<FileNullableDemoState> {
  FileNullableDemoForm({required this.picker})
      : super(formId: 'fileNullableDemo');

  final FilePicker picker;

  late final upload = TomFormFileUpload(
    'upload',
    null,
    form: this,
    picker: picker,
    labelTextOverride: 'Choose file',
    descriptionTextOverride: 'Compact "Choose file…" affordance',
    allowedExtensions: const ['txt', 'md', 'json', 'csv'],
    maxSizeBytes: 5 * 1024 * 1024,
  );

  late final dropzone = TomFormFileDropzone(
    'dropzone',
    null,
    form: this,
    picker: picker,
    labelTextOverride: 'Drop a file',
    descriptionTextOverride: 'Larger drop-target affordance, same picker',
    height: 140,
  );

  late final notes = TomFormNStringInput(
    'notes',
    null,
    form: this,
    labelTextOverride: 'Notes (nullable)',
    descriptionTextOverride: 'Empty text → null',
    maxLength: 80,
  );

  late final age = TomFormNIntInput(
    'age',
    null,
    form: this,
    labelTextOverride: 'Age (nullable int)',
  );

  late final score = TomFormNDoubleInput(
    'score',
    null,
    form: this,
    decimals: 2,
    labelTextOverride: 'Score (nullable double)',
  );

  late final birthday = TomFormNDateInput(
    'birthday',
    null,
    form: this,
    firstDate: DateTime(1900),
    lastDate: DateTime(2100),
    labelTextOverride: 'Birthday (nullable date)',
  );

  @override
  void createFormElements() {}
}

/// In-memory deterministic picker so the demo doesn't depend on a
/// platform file picker and so the smoke test can still call it.
Future<FileRef?> demoFilePicker(_) async {
  // Simulate the user choosing a small text file.
  final bytes = Uint8List.fromList(
      'Hello from the in-memory demo picker.\n'.codeUnits);
  return FileRef(
    name: 'demo_picked_file.txt',
    sizeBytes: bytes.length,
    mimeType: 'text/plain',
    bytes: bytes,
  );
}
