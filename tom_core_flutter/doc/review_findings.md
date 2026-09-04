# Tom Flutter - Review Findings

Date: 10 January 2026

> **Status: all findings resolved (OT2 refactoring pass, 2026-07-15).** This
> document is kept as a historical record. Every issue below has been fixed:
> the broken `Awesome` test/example are gone; `pubspec.yaml` has
> `publish_to: none` and an accurate description; the unused `_onChange` is
> removed; `security/authentication.dart` was exported from the barrel; the
> README is customized (~10 KB); the empty `iding/` folder and the four
> placeholder modules (`camera/`, `localstorage/`, `preferences/`, `qrcode/`)
> were removed (see `CHANGELOG.md` 1.1.0). The package now passes `dart analyze`
> clean and `flutter test --concurrency=1` 59/59 green.
>
> **`preferences/` has since come back, and is not a placeholder.** What 1.1.0
> removed from that directory was a `readme.md` of research links with no code
> behind it; the directory now holds the real device-preferences module, with
> its own barrel exports, [`doc/preferences.md`](preferences.md), an example and
> a test suite. Everything above is a record of 15 July 2026 and is left as
> written — this note exists because the sentence before it is the one a reader
> lands on after following a "where did local storage go?" redirection to
> `preferences`, and on its own it answers that the destination was deleted.
> `camera/`, `localstorage/`, `qrcode/` and `iding/` are still gone.
>
> **`security/authentication.dart` has since been deleted, not fixed.** The
> finding below — that its `TomClient2FAAdaptor` was missing from the barrel —
> was resolved in 1.1.0 by exporting it. Exporting it made the deeper problem
> visible: nothing anywhere read the annotation, so the export published a
> dispatch route that did not exist. The file and the type are gone (1.2.1);
> `Tom2FAClientRegistry.register` is the module's only route. The tables below
> are a record of 10 January 2026 and are left as written.

## Critical Issues

| Priority | File | Issue |
|----------|------|-------|
| 🔴 High | `test/tom_core_flutter_test.dart` | References undefined class `Awesome` - test will fail |
| 🔴 High | `example/tom_core_flutter_example.dart` | References undefined class `Awesome` - example is broken |
| 🟡 Medium | `pubspec.yaml` | Missing `publish_to: none` - causes warning about path dependencies |

## Code Quality Issues

| Priority | File | Issue |
|----------|------|-------|
| 🟡 Medium | `lib/src/tomclient/forms/tom_fields.dart` | Unused private declaration `_onChange` |
| 🟡 Medium | `lib/src/tomclient/security/authentication.dart` | Not exported in `tom_core_flutter.dart` barrel file |

## Documentation Issues

| Priority | File | Issue |
|----------|------|-------|
| 🟡 Medium | `README.md` | Template content - not customized for the package |
| 🟡 Medium | `README.md` | Missing first-line heading (markdown lint) |
| 🟡 Medium | `README.md` | Trailing spaces on lines 29, 37, 38 |
| 🟢 Low | `pubspec.yaml` | Generic description - should describe Flutter extensions |

## Structure Issues

| Priority | Location | Issue |
|----------|----------|-------|
| 🟡 Medium | `lib/src/tomclient/iding/` | Empty directory - no files |
| 🟢 Low | `lib/src/tomclient/camera/` | Only contains `readme.md` - placeholder module |
| 🟢 Low | `lib/src/tomclient/localstorage/` | Only contains `readme.md` - placeholder module |
| 🟢 Low | `lib/src/tomclient/preferences/` | Only contains `readme.md` - placeholder module |
| 🟢 Low | `lib/src/tomclient/qrcode/` | Only contains `readme.md` - placeholder module |

## Potential Improvements

1. **Fix broken test and example**: Replace `Awesome` references with actual tom_core_flutter classes
2. **Add `publish_to: none`**: Clarify this is a private package
3. **Update README.md**: Write actual documentation for the package
4. **Export missing files**: Add `authentication.dart` to barrel exports
5. **Clean up dead code**: Remove unused `_onChange` in `tom_fields.dart`
6. **Clean up empty directories**: Remove `iding/` or add placeholder readme
7. **Consider removing placeholder modules**: Camera, localstorage, preferences, qrcode are empty
8. **Add local _copilot_guidelines**: If this package has specific patterns

## Dependency Review

Current dependencies appear appropriate:
- `flutter` - Required for Flutter widgets
- `tom_core` - Core framework (path dependency is correct for monorepo)
- `cupertino_icons` - May not be needed if not using Cupertino widgets
- `fetch_client` - HTTP client for web platform
- `timezone_to_country` - Timezone utilities
- `web` - Web platform APIs

**Potential cleanup**: Verify `cupertino_icons` is actually used in any widget code.
