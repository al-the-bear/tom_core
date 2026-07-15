## 1.2.0

### Removed

- **Legacy forms module (RCF2).** Removed the back-compat `forms` module
  (`TomFieldOld`, `TomEmailField`, `TomPasswordField`, `TomFormOld`) — its two
  source files, both barrel exports, the executable example (`example/forms/`),
  the test suite (`test/forms_test.dart`), and the module docs (`doc/forms.md`,
  `doc/api_reference/api_summary_forms.md`). These primitives were superseded by
  the declarative forms framework in `tom_flutter_ui` (`TomForm` +
  `TomFormStringInput` et al.); per the no-back-compat policy the old surface is
  deleted rather than deprecated. The sole in-workspace consumer, the
  `tom_uam_client` sample app, was migrated onto `tom_flutter_ui`'s `TomForm` in
  the same pass. README, CHANGELOG, and the API summary index were updated to
  drop the module.

## 1.1.1

### Documentation

- **API reference (OT6).** Added a per-module API summary set under
  `doc/api_reference/` following
  `_copilot_guidelines/dart/api_summary_creation.md` — one
  `api_summary_{module}.md` per module (`forms`, `little_things`, `observing`,
  `resources`, `runtime`, `security`) plus an `api_summary_index.md` with quick
  navigation, per-module type tables, and an alphabetical type index. Each
  summary lists only the public surface (constructors, properties, methods,
  operators, and top-level functions) cross-checked against the actual source
  and the package barrel. The runtime summary documents the single exported
  getter `clientPlatformUtils` and the three compile-time `TomFlutterPlatformUtils`
  variants (io / web / neutral). No source or public API change.

## 1.1.0

### Verified

- **OT2 refactoring pass (2026-07-15)**: confirmed the whole-package gates —
  `dart analyze` clean and `flutter test --concurrency=1` 59/59 green — and that
  every review finding is resolved (see `doc/review_findings.md`). No code
  change; deeper per-module surface coverage tracked as quest todo RCE3.

### Documentation

- **Forms module**: added dartdoc to `TomFieldOld`, `TomEmailField`,
  `TomPasswordField`, and `TomFormOld`; a module guide at `doc/forms.md`; an
  executable example at `example/forms/`; and the first test suite at
  `test/forms_test.dart`. No public API change (removed only dead comments).
- **Little Things module**: added dartdoc to `TomClientException` and
  `TomClientUIException`; a module guide at `doc/little_things.md`; an executable
  example at `example/little_things/`; and tests at
  `test/little_things_test.dart`. No public API change.
- **Observing module**: added dartdoc to `TomObservingWidget`,
  `TomObservingWidgetState`, and `ValueListenableObserver`; a module guide at
  `doc/observing.md`; an executable example at `example/observing/`; and tests
  at `test/observing_test.dart`. Corrected the README usage snippet (the
  `subState:`/`child:` API; the old snippet referenced non-existent
  `observable:`/`builder:` parameters). No public API change.
- **Resources module**: added dartdoc to `TomProperty` and its typed subclasses
  (`TomStringProperty`, `TomIntProperty`, `TomDoubleProperty`,
  `TomBoolProperty`); a module guide at `doc/resources.md`; an executable
  example at `example/resources/`; and tests at `test/resources_test.dart`. No
  public API change.
- **Runtime module**: added dartdoc to `clientPlatformUtils` and the three
  conditional-import `TomFlutterPlatformUtils` variants (native IO, web,
  neutral); a module guide at `doc/runtime.md`; an executable example at
  `example/runtime/`; and tests at `test/runtime_test.dart`. No public API
  change.
- **Security module**: added dartdoc to the `TomClient2FAAdaptor` marker
  annotation; a module guide at `doc/security.md`; an executable example at
  `example/security/`; and tests at `test/security_test.dart`. Confirmed the
  module is exported from the package barrel. No public API change.

### Changed

- **Runtime module cleanup**: removed dead code in
  `platform_detection_flutter_io.dart` — an orphaned `@override` annotation, a
  commented-out `_maxCacheSize` constant, and a commented-out CupertinoClient
  block with two vague TODOs, replaced by a single concise note recording the
  deferred native-client intent. No behavior change.

### Removed

- **`camera/` placeholder module**: the folder contained only an aspirational
  `readme.md` with no implementation and was referenced by nothing. Removed
  rather than implemented — camera capture is a substantial feature (plugin,
  platform channels, capture/switch/video) outside the scope of this pass.
- **`localstorage/` placeholder module**: contained only a `readme.md` of
  research links (shared prefs / secure storage / hive / sqflite / objectbox)
  with no implementation and no references. Removed rather than implemented — a
  storage abstraction is a substantial feature with no current consumer.
- **`preferences/` placeholder module**: contained only a `readme.md` of
  research links (local-storage / database-adapter options) with no
  implementation and no references. Removed rather than implemented — user
  preferences would be a thin layer over a not-yet-chosen storage backend, with
  no current consumer.
- **`qrcode/` placeholder module**: contained only a three-line aspirational
  `readme.md` (generate/scan QR, camera integration) with no implementation and
  no references. Removed rather than implemented — QR generation and scanning
  require a plugin and camera/image-decode integration (a substantial feature),
  with no current consumer.

## 1.0.0

- Initial version.
