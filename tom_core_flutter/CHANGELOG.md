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

### Removed

- **`camera/` placeholder module**: the folder contained only an aspirational
  `readme.md` with no implementation and was referenced by nothing. Removed
  rather than implemented — camera capture is a substantial feature (plugin,
  platform channels, capture/switch/video) outside the scope of this pass.
- **`localstorage/` placeholder module**: contained only a `readme.md` of
  research links (shared prefs / secure storage / hive / sqflite / objectbox)
  with no implementation and no references. Removed rather than implemented — a
  storage abstraction is a substantial feature with no current consumer.

## 1.0.0

- Initial version.
