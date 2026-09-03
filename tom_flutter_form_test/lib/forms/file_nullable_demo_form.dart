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

/// Standalone source for the nullable enum dropdown demo so the field
/// can sit on the form without a corresponding `TomObject<Priority?>`
/// in the bound state (the kernel only ships nullable primitives).
final TomSelectableSource<Priority> _demoLPrioritySource = phase4PrioritySource;

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

  // ---------------------------------------------------------------------
  // Demo of the three null-display modes wired directly into the field
  // construction. Each row's null state is rendered differently so the
  // adaptability is visible without any extra plumbing in the demo:
  //   * notes — hint-based (resolves to `hintTextOverride`).
  //   * age — explicit "no value set" via `nullDisplayOverride`.
  //   * score — truly empty (`nullDisplayOverride: ''`).
  //   * birthday — default "— null —" sentinel (no override).
  //   * priority — nullable dropdown with an overridden null label.
  // ---------------------------------------------------------------------

  late final notes = TomFormNStringInput(
    'notes',
    null,
    form: this,
    labelTextOverride: 'Notes (hint-based null)',
    hintTextOverride: 'type a note…',
    descriptionTextOverride:
        'Null display falls back to the hintText — same as a regular '
        'empty input',
    maxLength: 80,
  );

  late final age = TomFormNIntInput(
    'age',
    null,
    form: this,
    labelTextOverride: 'Age (custom null text)',
    nullDisplayOverride: 'no value set',
    descriptionTextOverride:
        'nullDisplayOverride: "no value set" — fully custom placeholder',
  );

  late final score = TomFormNDoubleInput(
    'score',
    null,
    form: this,
    decimals: 2,
    labelTextOverride: 'Score (empty when null)',
    nullDisplayOverride: '',
    descriptionTextOverride:
        'nullDisplayOverride: "" — render nothing when the value is null',
  );

  late final birthday = TomFormNDateInput(
    'birthday',
    null,
    form: this,
    firstDate: DateTime(1900),
    lastDate: DateTime(2100),
    labelTextOverride: 'Birthday (resource-backed null text)',
    // Round-5 (k.b) — leaving `nullDisplayOverride` unset on purpose so
    // the resolver picks up the `birthday.nullDisplay` entry from
    // demo_resources.json (resolves to "Not set"). Demonstrates the
    // resource-backing path documented on
    // `_NullableFieldLabels.resolveNullDisplay`.
    descriptionTextOverride:
        'Null display sourced from resources via "<basePath>.nullDisplay"',
  );

  // The nullable dropdown isn't bound through a TomObject (the kernel
  // has no nullable enum primitive), so it stays detached from the form
  // and is constructed standalone in the demo state. See
  // [makeDemoLPriorityField] below.

  @override
  void createFormElements() {}
}

/// Builds the standalone nullable-dropdown field for Demo L's Priority
/// row. Lives outside the form because the bound [FileNullableDemoState]
/// has no `TomObject<Priority?>` to register against — the kernel only
/// ships nullable primitives. The demo state owns and disposes it.
TomFormNEnumDropdown<Priority> makeDemoLPriorityField() =>
    TomFormNEnumDropdown<Priority>(
      'priority',
      null,
      source: _demoLPrioritySource,
      labelTextOverride: 'Priority (nullable dropdown)',
      nullDisplayOverride: '— please select —',
      descriptionTextOverride:
          'Null is a real menu entry — its label is fully customizable',
    );

/// In-memory deterministic picker so the demo doesn't depend on a
/// platform file picker and so the smoke test can still call it.
Future<FileRef?> demoFilePicker(_) async {
  // Simulate the user choosing a small text file.
  final bytes = Uint8List.fromList(
    'Hello from the in-memory demo picker.\n'.codeUnits,
  );
  return FileRef(
    name: 'demo_picked_file.txt',
    sizeBytes: bytes.length,
    mimeType: 'text/plain',
    bytes: bytes,
  );
}
