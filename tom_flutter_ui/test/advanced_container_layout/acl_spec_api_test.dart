/// Pins §17 of `doc/acl_design_specification.md` — the complete `AclBuilder`
/// public API — against the builder it claims to describe.
///
/// §17 is a hand-written list of ~96 signatures. Nothing made it wrong in a
/// way a build would notice, so it drifted three different ways at once, and
/// all three were found by a script rather than by review:
///
/// * **Methods that no longer exist.** `alignTopInRow`, `alignMiddleInRow`,
///   `alignBottomInRow` and `setRowAlignment` were documented in full, with
///   parameters and prose, long after they were renamed away. A reader
///   following the specification wrote code that did not compile.
/// * **Signatures that changed under the name.** `setAclDefaultAppendGap` was
///   listed as taking `int pixels` when it takes
///   `(double, [List<(double, double)>])`; five others had likewise moved.
/// * **Methods never documented at all.** Eighteen public builder methods —
///   the whole authorization-hiding and id-scope families among them — existed
///   with no entry, so a reader could not learn they were there.
///
/// The fix for a list is not to re-check it by eye; it is to stop maintaining
/// it by eye. This test derives both sides mechanically and compares them, so
/// each of the three failures above becomes a red test at the moment it is
/// introduced.
///
/// **What counts as a mismatch.** Types and optionality — never parameter
/// names. A document is entitled to call a parameter something clearer than
/// the implementation does; `clearAttr(int attr)` against
/// `clearAttr(int newAttr)` is a better name, not drift. Default *values* are
/// stripped for the same reason: `= const []` and `= 0` are facts about the
/// implementation that the signature's shape already implies.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The section-17 source of truth, and the unit it describes. Paths are
/// package-relative; `flutter test` runs with the package root as its working
/// directory.
const _specPath = 'doc/acl_design_specification.md';
const _builderPath = 'lib/src/advanced_container_layout/acl_builder.dart';

/// A declaration as written, before canonicalisation.
class _Signature {
  _Signature(this.name, this.params);

  final String name;

  /// The raw text between the outermost parentheses.
  final String params;
}

/// Reduces a parameter list to *type and optionality only*.
///
/// The result is a comma-joined list of `<mode>[!]:<type>` entries, where mode
/// is `pos`, `opt` or `named` and `!` marks `required`. Two signatures agree
/// when their canonical forms are equal — which is what lets the document
/// choose its own parameter names and omit nothing that matters.
String _canonical(String params) {
  var text = params.replaceAll(RegExp(r'//.*'), '');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Strip default values BEFORE splitting. A `const []` default would
  // otherwise be read as the opening of an optional-positional group and
  // throw the mode tracking off for every parameter after it.
  text = text.replaceAll(RegExp(r'=\s*const\s*\[\s*\]'), '');
  text = text.replaceAll(RegExp(r'=\s*[^,\]}]+'), '');

  final parts = <({String mode, String text})>[];
  var mode = 'pos';
  var depth = 0;
  var current = StringBuffer();

  void flush() {
    if (current.toString().trim().isNotEmpty) {
      parts.add((mode: mode, text: current.toString().trim()));
    }
    current = StringBuffer();
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if ('<([{'.contains(c)) {
      // A `[` or `{` at depth zero opens an optional or named group rather
      // than a type argument or collection literal.
      if (depth == 0 && c == '[') {
        mode = 'opt';
        continue;
      }
      if (depth == 0 && c == '{') {
        mode = 'named';
        continue;
      }
      depth++;
    } else if ('>)]}'.contains(c)) {
      if (depth == 0 && (c == ']' || c == '}')) continue;
      depth--;
    }
    if (c == ',' && depth == 0) {
      flush();
      continue;
    }
    current.write(c);
  }
  flush();

  return parts.map((p) {
    var body = p.text;
    final isRequired = body.startsWith('required ');
    body = body.replaceFirst(RegExp(r'^required\s+'), '');
    // Drop the parameter name — the trailing identifier.
    body = body.replaceFirst(RegExp(r'\s+\w+$'), '').trim();
    return '${p.mode}${isRequired ? '!' : ''}:${body.replaceAll(' ', '')}';
  }).join(',');
}

/// Every declaration in [text] whose header matches [header], with its
/// parameter list extracted by balancing parentheses.
///
/// Balancing rather than a regex is what makes function-typed and generic
/// parameters — `void Function(int, int)?`, `List<(double, double)>` — survive
/// intact instead of being cut at their first comma or bracket.
List<_Signature> _declarations(String text, RegExp header) {
  final found = <_Signature>[];
  for (final match in header.allMatches(text)) {
    final name = match.group(1)!;
    if (name.startsWith('_')) continue;

    final open = match.end - 1;
    var depth = 0;
    var close = -1;
    for (var j = open; j < text.length; j++) {
      if ('([{'.contains(text[j])) depth++;
      if (')]}'.contains(text[j])) {
        depth--;
        if (depth == 0) {
          close = j;
          break;
        }
      }
    }
    if (close < 0) continue;
    found.add(_Signature(name, text.substring(open + 1, close)));
  }
  return found;
}

/// Declarations returning `AclBuilder` or `Acl` inside the specification's
/// ```dart fences.
///
/// The first fence to mention a method wins: §17 lists each once, and the
/// worked examples elsewhere in the document call methods rather than declare
/// them, so they do not collide.
Map<String, _Signature> _specSignatures() {
  final spec = File(_specPath).readAsStringSync();
  final header = RegExp(r'^\s*(?:AclBuilder|Acl)\s+(\w+)\(', multiLine: true);
  final signatures = <String, _Signature>{};
  for (final fence
      in RegExp(r'```dart\n(.*?)```', dotAll: true).allMatches(spec)) {
    for (final signature in _declarations(fence.group(1)!, header)) {
      signatures.putIfAbsent(signature.name, () => signature);
    }
  }
  return signatures;
}

/// Every public method declared at class or extension level in the builder.
///
/// Two-space indentation is the discriminator: it selects members of
/// `AclBuilder` and of the `AclBuilderExtensions` extension while excluding
/// top-level functions, nested closures, and the constructor (which has no
/// return type, so no space before its name).
Map<String, _Signature> _sourceSignatures() {
  final source = File(_builderPath).readAsStringSync();
  final header = RegExp(r'^  (?:[A-Za-z_][\w<>?, ]*?)\s+(\w+)\(',
      multiLine: true);
  return {for (final s in _declarations(source, header)) s.name: s};
}

/// The subset of the builder's methods that return a builder — the fluent API
/// §17 undertakes to list in full. Methods returning anything else (`bool`
/// predicates, `int` counts) are legitimately outside the section's scope.
Set<String> _fluentMethodNames() {
  final source = File(_builderPath).readAsStringSync();
  return RegExp(r'^  (?:AclBuilder|Acl)\s+(\w+)\(', multiLine: true)
      .allMatches(source)
      .map((m) => m.group(1)!)
      .where((n) => !n.startsWith('_'))
      .toSet();
}

void main() {
  late Map<String, _Signature> spec;
  late Map<String, _Signature> source;
  late Set<String> fluent;

  setUpAll(() {
    spec = _specSignatures();
    source = _sourceSignatures();
    fluent = _fluentMethodNames();
  });

  group('§17 describes the builder that exists', () {
    // Every check below is an `isEmpty` assertion, so all of them pass
    // vacuously against a parser that has silently stopped matching — which
    // is exactly what a refactor of either file could cause.
    test('both sides parse to a plausible number of methods', () {
      expect(spec.length, greaterThan(80),
          reason: 'only ${spec.length} signatures found in $_specPath — the '
              'fence or declaration parsing is probably broken');
      expect(fluent.length, greaterThan(80),
          reason: 'only ${fluent.length} fluent methods found in '
              '$_builderPath — the declaration parsing is probably broken');
      // Anchors: two methods carrying breakpoint-override lists, one
      // no-argument convenience wrapper, and `build` itself.
      expect(source.keys, contains('setRowHeight'));
      expect(source.keys, contains('setAclDefaultAppendGap'));
      expect(source.keys, contains('setRowAlignTop'));
      expect(source.keys, contains('build'));
    });

    test('every documented method exists', () {
      final phantom = spec.keys.where((n) => !source.containsKey(n)).toList()
        ..sort();
      expect(phantom, isEmpty,
          reason: '$_specPath documents methods that $_builderPath does not '
              'declare — a reader following it writes code that will not '
              'compile:\n${phantom.map((n) => '  $n').join('\n')}');
    });

    test('every documented signature matches on type and optionality', () {
      final drifted = <String>[];
      for (final name in spec.keys.toList()..sort()) {
        final declared = source[name];
        if (declared == null) continue; // reported by the test above
        final documented = _canonical(spec[name]!.params);
        final actual = _canonical(declared.params);
        if (documented != actual) {
          drifted.add('  $name\n'
              '      spec: ($documented)\n'
              '      src : ($actual)');
        }
      }
      expect(drifted, isEmpty,
          reason: 'signatures in $_specPath no longer match $_builderPath '
              '(parameter names are deliberately not compared):\n'
              '${drifted.join('\n')}');
    });

    test('every fluent builder method is documented', () {
      final undocumented =
          fluent.where((n) => !spec.containsKey(n)).toList()..sort();
      expect(undocumented, isEmpty,
          reason: '§17 of $_specPath undertakes to list the complete public '
              'API, but these methods have no entry, so a reader cannot '
              'learn they exist:\n${undocumented.map((n) => '  $n').join('\n')}');
    });
  });
}
