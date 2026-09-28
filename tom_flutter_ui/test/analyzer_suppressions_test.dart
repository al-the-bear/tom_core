/// Every analyzer suppression that ships carries its reason, and none of them
/// hides a deprecation.
///
/// `// ignore: deprecated_member_use` was on both `Radio.groupValue` and
/// `Radio.onChanged` in `tom_choice_group.dart` while Flutter was moving
/// single-selection radios to a `RadioGroup` ancestor. It silenced the
/// analyzer and changed nothing: when the parameters go, the file stops
/// compiling, and whoever meets that has to rediscover why the comment was
/// there — because it said nothing. The migration itself was three lines.
///
/// A deprecation is the one diagnostic whose whole purpose is a deadline, so
/// suppressing it converts a warning that will be acted on into a build break
/// that will not be expected. Every other rule can be suppressed for a good
/// reason, and the rule here is that the reason is written down.
///
/// **Scoped to `lib/`, which is what ships.** A test or an example
/// legitimately silences `avoid_print` to show its output, and holding those
/// to the same rule would be noise with no consumer behind it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A suppression comment, with where it was found.
typedef _Suppression = ({String file, int line, String rules, String text});

/// `// ignore: a, b` or `// ignore_for_file: a, b`, capturing the rule list.
final _ignore = RegExp(r'//\s*ignore(?:_for_file)?\s*:\s*([\w, ]+)');

/// Machine-written files. Their suppressions are the generator's, and editing
/// one would be undone by the next build.
const _generated = ['.reflection.dart', '.g.dart', '.freezed.dart'];

List<File> _shippedSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !_generated.any(f.path.endsWith))
    .toList();

List<_Suppression> _suppressions() {
  final out = <_Suppression>[];
  for (final file in _shippedSources()) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final match = _ignore.firstMatch(lines[i]);
      // A `///` line is documentation *about* ignoring something, not a
      // directive — only a real comment directive suppresses anything.
      if (match == null || lines[i].trimLeft().startsWith('///')) continue;
      out.add((
        file: file.path,
        line: i + 1,
        rules: match.group(1)!.trim(),
        // The line above is where a reason lives: a directive has to sit
        // immediately on top of what it suppresses, so there is nowhere else
        // for one to go.
        text: i > 0 ? lines[i - 1].trim() : '',
      ));
    }
  }
  return out;
}

void main() {
  test('the scan reads the shipped sources', () {
    // Guards both cases below: an empty walk satisfies "nothing suppresses a
    // deprecation" and "every suppression has a reason" without reading a
    // line.
    final sources = _shippedSources();
    expect(
      sources.length,
      greaterThan(100),
      reason: 'found ${sources.length} files under lib/ — the walk is broken',
    );
    expect(
      sources.any((f) => f.path.endsWith('tom_choice_group.dart')),
      isTrue,
      reason: 'the file this was written for is not in the walk',
    );
  });

  test('no shipped source suppresses a deprecation', () {
    final offenders = _suppressions()
        .where((s) => s.rules.contains('deprecated_member_use'))
        .map((s) => '${s.file}:${s.line} — ${s.rules}')
        .toList();
    expect(
      offenders,
      isEmpty,
      reason:
          'a deprecation is a deadline, not a lint: silencing it turns a '
          'warning somebody would act on into a build break nobody expects. '
          'Migrate, or if the migration genuinely cannot be made yet, say so '
          'in a todo and not in a comment nobody can read: $offenders',
    );
  });

  test('every shipped suppression says why', () {
    // Not a matter of taste: the suppression that prompted this carried no
    // reason, and a reader could not tell deliberate deferral from an
    // oversight. The line above it is where the answer goes.
    final offenders = <String>[];
    for (final suppression in _suppressions()) {
      final above = suppression.text;
      final explained =
          (above.startsWith('//') || above.startsWith('///')) &&
          above.replaceAll(RegExp(r'^/+\s*'), '').length > 20;
      if (!explained) {
        offenders.add(
          '${suppression.file}:${suppression.line} — '
          '${suppression.rules}',
        );
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these suppress an analyzer rule with nothing above them saying '
          'why: $offenders',
    );
  });
}
