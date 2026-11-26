# tom_text_testing

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and published on pub.dev.

> **⚠️ Work in progress — unstable API.** The Tom Core packages are under active
> development and not yet stable. Their version numbers carry no promise about
> API maturity: they are publishing counters, not semver. The patch number is
> bumped on every change — **including breaking changes** — so a patch bump may
> break you. Expect the public surface to shift without notice. Not recommended
> for production use yet.

Test support for internationalised Tom packages: a package's texts loaded from
its resource file and installed as Tom Core's text resources under the scope an
application mounts it under, and the coverage check that holds the resource
files and the code to each other.

## Overview

A Tom package keeps its user-visible texts in
`lib/resources/<package-name>_<language>.json` and names them in code by ids
relative to the package (`rename.nameField`); the scope a component is
constructed in supplies the front of the path. The rules are the workspace
guideline `_agent_guidelines/i18n.md`. This package is what a package's tests
use to follow them:

- **`PackageTexts`** loads the file, mounts its block under a scope (the
  package name, or any scope path an application uses, `a.b` nesting it one
  level deeper), installs it as the `TomTextResourceProvider` and runs a body
  in that scope, so a component is constructed exactly as an application
  mounts it. `withPackageTexts` does all of it and clears the texts
  afterwards; `clearTexts` belongs in `tearDown`.
- **`expectTextCoverage`** runs the coverage check and fails the test naming
  every finding with its file, line, id and key; `checkTextCoverage` answers
  the report instead.

Pure Dart on `tom_core_kernel` only: Flutter and pure-Dart packages take it as
a dev dependency alike. It takes no test framework (a failed check throws,
which fails a test in `package:test` and `flutter_test` alike) and no analyzer
(the sources are read lexically, which is enough because ids are written as
literals by rule).

## Adding it to a package

`pubspec.yaml`:

```yaml
dev_dependencies:
  tom_text_testing:
    path: ../../core/tom_text_testing # relative to the package
```

`test/i18n_coverage_test.dart`, one test:

```dart
import 'package:test/test.dart'; // flutter_test in a Flutter package
import 'package:tom_text_testing/tom_text_testing.dart';

void main() {
  test('texts and code agree', () => expectTextCoverage('my_package'));
}
```

A widget test of a component:

```dart
late PackageTexts texts;
setUp(() => texts = PackageTexts.load('my_package')..install());
tearDown(clearTexts);

testWidgets('the dialog', (tester) async {
  await tester.pumpWidget(
    MaterialApp(home: texts.run(() => RenameDialog(onRename: (_) {}))),
  );
  expect(find.text('Rename file'), findsOneWidget);
});
```

and the same component mounted elsewhere, as the guideline asks once per
component: `texts.installAt(['files', 'workbench.explorer'])`, then
`runInScopePath('workbench.explorer', () => RenameDialog(...))`.

## The coverage check

`checkTextCoverage(packageName)` reads `lib/resources/` and every Dart file of
`lib/` under the package root and reports:

| Kind | What |
| --- | --- |
| `missingId`, `missingKey` | an id (or id and key) the code uses that the reference file (`_en`) lacks |
| `unusedEntry` | an element of the file no code uses |
| `noSuffix` | an entry with texts whose name ends in no type suffix (`nameText`, `saveButton`, ...) |
| `disallowedKey`, `missingRequiredKey` | a key the element's kind does not allow, or a required one it lacks (`TextElementKinds.standard`, the guideline's suffix table (its section 3)) |
| `placeholders` | the parameters a call passes and the text's `{name}` placeholders differ |
| `literal`, `unusedAllowance` | a user-visible string literal left in `lib/`; an allow-list entry that matches nothing |
| `language` | another language's file lacks a text, has one the reference lacks, or differs in its placeholders (extra plural forms `zero`, `two`, `few` are allowed) |
| `shape` | the file breaks the guideline's shape: the top level is not the package name alone, a dotted key, `null`, a list |
| `nonLiteralId`, `packageName` | an id written with an interpolation, or one naming the package |

**Ids** are found where a `TextIdCarrier` says: `tomId: '<id>'` and
`TomCtr.resolvePath('<id>', ...)` always (`TextIdCarrier.standard`), plus the
carriers a package family adds for its own text reference type, e.g.
`TextIdCarrier.call(r'\bForgeText', includesKey: true, paramsArgument: 'params')`.

**User-visible literals** are told by a heuristic (two words with a space
between, or one capitalised word); literals that are arguments of log,
trail, assertion, error and exception, key, `RegExp` and `Uri` calls
(`defaultNonUserCalls`, extended with `nonUserCalls`) are not reported, nor
`import` URIs. What is left and is still not translated goes into
`allowedLiterals`, each with its reason. `checkLiterals: false` skips the
literal check for a package not migrated yet.

## Tests

`test/fixtures/rename_demo` is the guideline's worked example, verbatim, and
passes the check; `test/fixtures/broken_demo` breaks every rule once.
`test/worked_example_test.dart` holds the fixture to the guideline.

---

Part of [Tom Core](../README.md).

<!-- markdownlint-disable-file MD013 MD028 -->
