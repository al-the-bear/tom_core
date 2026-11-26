# Changelog

## 0.1.0

### Added

- **`PackageTexts`**: a package's `lib/resources/<package-name>_<language>.json`
  loaded, mounted under the package scope or any scope path (`mountedAt`,
  `install`, `installAt`), and a body run in that scope (`run`);
  `withPackageTexts`, `mountTexts`, `mergeTexts`, `installTexts`,
  `clearTexts`, `runInScopePath`.
- **The coverage check** of the workspace's internationalisation guideline:
  `checkTextCoverage` / `expectTextCoverage` with `TextIdCarrier`,
  `AllowedLiteral`, the findings (`TextCoverageKind`) and the element kinds of
  the guideline's suffix table (`TextElementKinds.standard`).
- `DartSource`: the lexical reading of a Dart file the check rests on.
