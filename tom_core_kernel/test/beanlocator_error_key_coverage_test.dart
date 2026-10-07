/// The guard that keeps the bean locator's two documented key lists equal to
/// the set of keys it actually throws.
///
/// `TomBeanLocatorException` carries a `key`, and both a caller's `switch` and a
/// support engineer reading a log line depend on the key list being complete.
/// Two places claim to hold that list — the `## Exception Keys` block in the
/// `TomBeanLocatorException` dartdoc, and the `### Error Keys` table in
/// `doc/beanlocator/beanlocator.md` — and each says, in so many words, that it
/// is the complete set.
///
/// Both have been wrong. They were completed once by hand, and the very todo
/// that asked for the audit had itself gone stale in the meantime: it named ten
/// keys when the module already threw eleven, because a key added afterwards
/// was documented in both lists but not in the audit. A list maintained by
/// remembering to maintain it drifts the moment someone adds a `throw`, and the
/// drift is invisible — nothing fails, the key is simply undocumented.
///
/// So the invariant is checked instead of remembered. Three sets must agree:
///
///  * the keys thrown from `lib/src/tombase/beanlocator/bean_locator.dart`;
///  * the keys listed in the dartdoc `## Exception Keys` block;
///  * the keys listed in the prose `### Error Keys` table.
///
/// The thrown set is the anchor, because it is the code. Both directions are
/// checked: an undocumented key leaves a reader with a log line they cannot look
/// up, and a documented key nothing throws sends them hunting for a failure mode
/// that no longer exists — the second reads as authoritative precisely because
/// it sits in a maintained list.
///
/// Every entry must also carry a description, since a bare key repeated back is
/// not documentation.
///
/// Everything here reads the working tree, so the failure names the missing key
/// and appears in the same run as the `throw` that introduced it.
///
/// Whether some test *names* each thrown key is not asked here. That question
/// spans every package, so it is asked once, by
/// `tom_ai/core/tool/check_doc_error_keys.py` (its `UNTESTED` fault), run with
/// every other gate by `tool/check_gates.py`. A second copy of one rule in one
/// module would be the copy that gets edited and never travels back.
library;

import 'dart:io';

import 'package:test/test.dart';

/// The module source, relative to the package root the test runs from.
const String _sourcePath = 'lib/src/tombase/beanlocator/bean_locator.dart';

/// The narrative guide that carries the prose key table.
const String _docPath = 'doc/beanlocator/beanlocator.md';

/// A key as it appears in a thrown `TomBeanLocatorException`.
final RegExp _thrownKeyPattern = RegExp('"(beanlocator\\.[a-z_.]+)"');

/// A key as it appears in a dartdoc bullet: ``- `key`: meaning``.
final RegExp _bulletPattern = RegExp(r'^- `(beanlocator\.[a-z_.]+)`:\s*(.*)$');

/// A key as it appears in a markdown table row: ``| `key` | meaning |``.
final RegExp _tableRowPattern = RegExp(
  r'^\|\s*`(beanlocator\.[a-z_.]+)`\s*\|(.*)\|\s*$',
);

/// Whether [line] is part of a doc comment rather than code.
bool _isDocComment(String line) => line.trimLeft().startsWith('///');

/// The keys the module raises, read from its `throw` sites.
///
/// Doc comments are dropped first, so the module's own documentation of a key
/// cannot stand in for throwing it — otherwise the anchor set would be defined
/// partly by one of the two lists it is supposed to check.
Set<String> _thrownKeys() {
  final code = File(
    _sourcePath,
  ).readAsLinesSync().where((l) => !_isDocComment(l));

  return {
    for (final line in code)
      ..._thrownKeyPattern.allMatches(line).map((m) => m.group(1)!),
  };
}

/// Parses `key -> description` out of a run of lines.
///
/// [entryOf] recognises the line that starts an entry and returns its key and
/// first description line; any following line for which [isContinuation] holds
/// extends the description in progress.
Map<String, String> _entries(
  List<String> lines,
  MapEntry<String, String>? Function(String) entryOf,
  bool Function(String) isContinuation,
) {
  final result = <String, String>{};
  String? current;

  for (final line in lines) {
    final entry = entryOf(line);
    if (entry != null) {
      current = entry.key;
      result[current] = entry.value;
      continue;
    }
    if (current != null && isContinuation(line)) {
      result[current] = '${result[current]} ${line.trim()}'.trim();
      continue;
    }
    current = null;
  }

  return result;
}

/// The keys documented in the dartdoc block, mapped to their descriptions.
///
/// The block runs from its heading to the end of the doc comment it lives in —
/// in practice, to the `class TomBeanLocatorException` declaration below it.
/// The `/// ` prefix is stripped but the indent under it is kept, since that is
/// what marks a bullet's continuation line.
Map<String, String> _dartdocKeys() {
  final lines = File(_sourcePath).readAsLinesSync();
  final start = lines.indexWhere((l) => l.trim() == '/// ## Exception Keys');

  expect(
    start,
    isNonNegative,
    reason:
        'No "## Exception Keys" heading in $_sourcePath. The dartdoc list this '
        'guards has been renamed or removed; point the test at its new home '
        'rather than deleting the check.',
  );

  final block = lines
      .skip(start + 1)
      .takeWhile(_isDocComment)
      .map((l) => l.replaceFirst(RegExp(r'^\s*/// ?'), ''))
      .toList();

  return _entries(block, (line) {
    final match = _bulletPattern.firstMatch(line);
    return match == null ? null : MapEntry(match.group(1)!, match.group(2)!);
  }, (line) => line.startsWith('  ') && line.trim().isNotEmpty);
}

/// The keys documented in the prose table, mapped to their descriptions.
Map<String, String> _proseKeys() {
  final lines = File(_docPath).readAsLinesSync();
  final start = lines.indexWhere((l) => l.trim() == '### Error Keys');

  expect(
    start,
    isNonNegative,
    reason:
        'No "### Error Keys" heading in $_docPath. The prose table this guards '
        'has been renamed or removed; point the test at its new home rather '
        'than deleting the check.',
  );

  // The table ends at the next heading; rows are matched, so intervening prose
  // is simply ignored.
  final block = lines
      .skip(start + 1)
      .takeWhile((l) => !l.startsWith('#'))
      .toList();

  return _entries(
    block,
    (line) {
      final match = _tableRowPattern.firstMatch(line);
      return match == null
          ? null
          : MapEntry(match.group(1)!, match.group(2)!.trim());
    },
    // Table rows are one line each.
    (_) => false,
  );
}

void main() {
  group('documented error keys mirror the thrown ones', () {
    test('the module throws keys at all', () {
      // If the anchor set comes back empty the two comparisons below pass
      // vacuously, which is the one way this guard could fail silently.
      expect(
        _thrownKeys(),
        isNotEmpty,
        reason:
            'No "beanlocator.*" key literals found in $_sourcePath. Either the '
            'keys are no longer written as double-quoted literals, or the file '
            'moved — fix the parser, because the comparisons below are '
            'meaningless without it.',
      );
    });

    test('the dartdoc lists every key the module throws', () {
      final documented = _dartdocKeys().keys.toSet();
      final missing = (_thrownKeys()..removeAll(documented)).toList()..sort();

      expect(
        missing,
        isEmpty,
        reason:
            'These keys are thrown but not listed in the "## Exception Keys" '
            'block of $_sourcePath: ${missing.join(', ')}. A caller reading the '
            'dartdoc cannot handle a key it never mentions.',
      );
    });

    test('the dartdoc lists no key the module does not throw', () {
      final thrown = _thrownKeys();
      final orphaned =
          _dartdocKeys().keys.where((k) => !thrown.contains(k)).toList()
            ..sort();

      expect(
        orphaned,
        isEmpty,
        reason:
            'These keys are listed in $_sourcePath but nothing throws them: '
            '${orphaned.join(', ')}. Delete the entry, or rename it if the key '
            'was renamed — a documented failure mode that cannot occur sends a '
            'reader hunting for something that is not there.',
      );
    });

    test('the prose table lists every key the module throws', () {
      final documented = _proseKeys().keys.toSet();
      final missing = (_thrownKeys()..removeAll(documented)).toList()..sort();

      expect(
        missing,
        isEmpty,
        reason:
            'These keys are thrown but missing from the "### Error Keys" table '
            'in $_docPath: ${missing.join(', ')}. The table states it is the '
            'complete set, so an omission reads as "this cannot happen".',
      );
    });

    test('the prose table lists no key the module does not throw', () {
      final thrown = _thrownKeys();
      final orphaned =
          _proseKeys().keys.where((k) => !thrown.contains(k)).toList()..sort();

      expect(
        orphaned,
        isEmpty,
        reason:
            'These keys are listed in $_docPath but nothing throws them: '
            '${orphaned.join(', ')}. Delete the row, or rename it if the key '
            'was renamed.',
      );
    });

    test('every documented key carries a description', () {
      final undescribed = <String>[
        for (final entry in _dartdocKeys().entries)
          if (entry.value.trim().isEmpty) '$_sourcePath: ${entry.key}',
        for (final entry in _proseKeys().entries)
          if (entry.value.trim().isEmpty) '$_docPath: ${entry.key}',
      ]..sort();

      expect(
        undescribed,
        isEmpty,
        reason:
            'These entries name a key and say nothing about it: '
            '${undescribed.join(', ')}. A key repeated back as prose tells a '
            'reader only what they already had from the log line.',
      );
    });
  });
}
