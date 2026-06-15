## Unreleased

### Documentation

- **Forms module**: added dartdoc to `TomFieldOld`, `TomEmailField`,
  `TomPasswordField`, and `TomFormOld`; a module guide at `doc/forms.md`; an
  executable example at `example/forms/`; and the first test suite at
  `test/forms_test.dart`. No public API change (removed only dead comments).

### Removed

- **`camera/` placeholder module**: the folder contained only an aspirational
  `readme.md` with no implementation and was referenced by nothing. Removed
  rather than implemented — camera capture is a substantial feature (plugin,
  platform channels, capture/switch/video) outside the scope of this pass.

## 1.0.0

- Initial version.
