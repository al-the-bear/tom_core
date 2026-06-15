## Unreleased

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
