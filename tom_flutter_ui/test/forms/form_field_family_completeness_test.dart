/// `TomFormFieldFamily`'s both-sided rule, derived from the catalogue.
///
/// The library dartdoc promises that a method exists **exactly when** a field
/// kind has a concrete on both sides — Material and Cupertino — so that the
/// *absence* of a method tells a caller the control is genuinely one-sided,
/// not that the factory has a gap. The parity test proves every method that
/// exists behaves alike on both sides; nothing proved the set of methods is
/// the right set. A kind that gained its second-family concrete and no method,
/// or a method written for a one-sided kind, failed nothing.
///
/// So the set is derived here from `lib/src/forms/fields`, the same way
/// `module_readme_inventory_test.dart` derives an inventory from a barrel,
/// and compared with the factory's return types in both directions.
///
/// **What a kind is.** Every public concrete class under `fields/` is a
/// Material field and under `fields/cupertino/` a Cupertino one. Its kind is
/// the abstract `TomForm…Field` base it extends, followed up through any
/// intermediate class — or, for a field that extends `TomField<X?>` directly
/// (the nullable inputs), that `TomField<X?>` type itself, since the value type
/// is all that pairs one side's `TomFormNStringInput` with the other's
/// `TomCupertinoFormNStringInput`. A factory method's kind is its return type,
/// with a base's type arguments dropped (`TomFormEnumField<T>` is the enum
/// kind) and a direct `TomField<X?>` kept whole.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _fields = 'lib/src/forms/fields';
const _factory = 'lib/src/forms/form_field_family.dart';

/// `class Name<...> extends Super<...>` — across lines, up to the brace.
final _declaration = RegExp(
  r'^(abstract\s+)?(?:base\s+|final\s+|sealed\s+)*class\s+(\w+)(?:<[^{]*?>)?'
  r'\s+extends\s+(\w+)(<[^{]*?>)?\s*(?:with|implements|\{)',
  multiLine: true,
  dotAll: true,
);

/// A public factory method: `  ReturnType name(` or `  ReturnType name<T>(`,
/// two-space indented inside the class.
final _method = RegExp(
  r'^  (Tom\w+(?:<[^>]*>)?\??) ([a-z]\w*)(?:<[^>]*>)?\(',
  multiLine: true,
);

class _Declaration {
  _Declaration(this.name, this.isAbstract, this.superName, this.superArgs);
  final String name;
  final bool isAbstract;
  final String superName;
  final String superArgs;
}

Map<String, _Declaration> _declarationsIn(Iterable<File> files) => {
  for (final file in files)
    for (final m in _declaration.allMatches(file.readAsStringSync()))
      m.group(2)!: _Declaration(
        m.group(2)!,
        m.group(1) != null,
        m.group(3)!,
        (m.group(4) ?? '').replaceAll(RegExp(r'\s+'), ''),
      ),
};

List<File> _dartFiles(String dir, {required bool recursive}) => Directory(dir)
    .listSync(recursive: recursive)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// The kind each public concrete class belongs to, by class name.
///
/// Walks `extends` through [all] until it reaches an abstract `TomForm…Field`
/// base or `TomField` itself. A class that reaches neither is not a field.
Map<String, String> _kindsOf(
  Iterable<File> files,
  Map<String, _Declaration> all,
) {
  final kinds = <String, String>{};
  for (final declaration in _declarationsIn(files).values) {
    if (declaration.isAbstract || declaration.name.startsWith('_')) continue;
    var current = declaration;
    String? kind;
    for (var depth = 0; depth < 10; depth++) {
      if (current.superName == 'TomField') {
        kind = 'TomField${current.superArgs}';
        break;
      }
      final parent = all[current.superName];
      if (parent == null) break;
      if (parent.isAbstract && parent.name.startsWith('TomForm')) {
        kind = parent.name;
        break;
      }
      current = parent;
    }
    if (kind != null) kinds[declaration.name] = kind;
  }
  return kinds;
}

/// The kind a factory return type names.
String _kindOfReturn(String returnType) => returnType.startsWith('TomField<')
    ? returnType
    : returnType.replaceAll(RegExp(r'<.*$'), '');

void main() {
  final cupertinoFiles = _dartFiles('$_fields/cupertino', recursive: false);
  final materialFiles = _dartFiles(_fields, recursive: false);
  final all = _declarationsIn([...materialFiles, ...cupertinoFiles]);
  final materialKinds = _kindsOf(materialFiles, all).values.toSet();
  final cupertinoKinds = _kindsOf(cupertinoFiles, all).values.toSet();
  final bothSided = materialKinds.intersection(cupertinoKinds);

  final factorySource = File(_factory).readAsStringSync();
  final classBody = factorySource.substring(
    factorySource.indexOf('class TomFormFieldFamily'),
  );
  final methods = {
    for (final m in _method.allMatches(classBody))
      m.group(2)!: _kindOfReturn(m.group(1)!),
  };
  final covered = methods.values.toSet();

  group('FFC: the TomFormFieldFamily both-sided rule [2026-09-30]', () {
    test('FFC-1: the derivation finds the catalogue', () {
      // Guards the parse, not the rule: an empty or tiny set would make both
      // directions below vacuous, and read as a factory in perfect order.
      expect(materialKinds.length, greaterThanOrEqualTo(20));
      expect(cupertinoKinds.length, greaterThanOrEqualTo(15));
      expect(methods.length, greaterThanOrEqualTo(20));
      expect(
        bothSided,
        containsAll(<String>['TomFormStringField', 'TomField<String?>']),
      );
    });

    test('FFC-2: every kind with a concrete on both sides has a method', () {
      final missing = bothSided.difference(covered).toList()..sort();
      expect(
        missing,
        isEmpty,
        reason:
            'these kinds have a Material and a Cupertino concrete and no '
            'TomFormFieldFamily method, so the factory has a gap while its '
            'dartdoc says a missing method means a one-sided control',
      );
    });

    test('FFC-3: every method is for a kind with a concrete on both sides', () {
      final oneSided = {
        for (final entry in methods.entries)
          if (!bothSided.contains(entry.value)) entry.key: entry.value,
      };
      expect(
        oneSided,
        isEmpty,
        reason:
            'these methods return a kind with a concrete on only one side, so '
            'one of the two families cannot build it',
      );
    });
  });
}
