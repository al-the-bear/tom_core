/// Checks that an API summary's exception constructor block still says what the
/// source and the kernel say.
///
/// Three modules need the identical check — `little_things`, `preferences` and
/// `configuration` — because all three declare exceptions the same way: a class
/// that extends `TomClientException` and forwards every parameter with
/// `super.x`, declaring no type of its own. The summary has to spell those types
/// out, and the summary is the only place they are written down, so it is the
/// only place they can drift.
///
/// **Why the types cannot be read off the fields.** A super-parameter takes its
/// type from the *immediate superclass constructor*, not from wherever the field
/// was first declared. For `stack` the two differ: `TomBaseException`
/// (`tom_basics`) declares the field `Object? stack`, but `TomException`'s
/// constructor narrows the parameter to `StackTrace?` and forwards
/// `stack ?? StackTrace.current`. Documenting the parameter from the field
/// declaration therefore gives the wrong answer — plausibly enough that it has
/// been reported as a defect three times (tcinc617, tcinc654, tcinc664). Reading
/// the kernel constructor is not a convenience here; it is the only place the
/// answer is.
///
/// The parser's own self-check lives in `little_things_test.dart` ("the kernel
/// constructor parser reports the types it should"): without it, every check
/// below would pass just as happily on an empty parse.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The kernel constructor every client exception in this package ultimately
/// forwards to. A path dependency (`pubspec.yaml`), so this relative path is as
/// stable as the package layout itself.
const kernelExceptionPath =
    '../tom_core_kernel/lib/src/tombase/little_things/exception_base.dart';

/// The parameter lines of [name]'s constructor, from `(` to the `})` or `)`
/// that closes the list.
String constructorBody(String source, String name) {
  final start = source.indexOf('$name(\n');
  expect(start, isNot(-1), reason: 'no constructor $name( in the source');
  final open = source.indexOf('\n', start) + 1;
  final close = source.indexOf(RegExp(r'^\}?\)', multiLine: true), open);
  // The declaration sites are indented, the summary's code fence is not, so
  // match either and take whichever terminator comes first.
  final closeIndented = source.indexOf(RegExp(r'^\s+\}?\)', multiLine: true), open);
  final end = [close, closeIndented].where((i) => i >= 0).reduce(
        (a, b) => a < b ? a : b,
      );
  return source.substring(open, end);
}

/// [constructorBody] read from whichever of [sourcePaths] declares [name].
///
/// A module's exceptions are spread over the files that raise them, so the
/// caller names the module's sources and the class is looked up across them.
String constructorBodyFrom(Iterable<String> sourcePaths, String name) {
  for (final path in sourcePaths) {
    final source = File(path).readAsStringSync();
    if (source.contains('$name(\n')) return constructorBody(source, name);
  }
  fail('no constructor $name( in any of ${sourcePaths.join(', ')}');
}

/// `{parameterName: 'declaredType' or 'declaredType = default'}`, in the order
/// declared. `this.x` / `super.x` forms yield a null type — the declaration
/// carries no type of its own.
Map<String, String?> parseParameters(String body) {
  final parsed = <String, String?>{};
  for (var line in body.split('\n')) {
    line = line.trim();
    if (line.endsWith('{')) line = line.substring(0, line.length - 1).trim();
    if (line.endsWith(',')) line = line.substring(0, line.length - 1).trim();
    if (line.isEmpty || line == '{' || line == '}') continue;

    String? defaultValue;
    final equals = line.indexOf(' = ');
    if (equals >= 0) {
      defaultValue = line.substring(equals + 3).trim();
      line = line.substring(0, equals).trim();
    }

    if (line.startsWith('this.') || line.startsWith('super.')) {
      parsed[line.split('.').last] = null;
      continue;
    }
    final words = line.split(RegExp(r'\s+'));
    final name = words.removeLast();
    final type = words.join(' ');
    parsed[name] = defaultValue == null ? type : '$type = $defaultValue';
  }
  return parsed;
}

/// The kernel constructor's parameters with `this.x` resolved to the type of the
/// field it initialises — which is where the real answer lives for `autoLog`.
Map<String, String?> kernelParameters() {
  final kernel = File(kernelExceptionPath).readAsStringSync();
  final body = constructorBody(kernel, 'TomException');
  final parsed = parseParameters(body);
  // Re-read the raw body: a `this.x = default` line loses its default in the
  // null-typed branch above, and the default is part of the contract.
  for (final entry in parsed.entries.toList()) {
    if (entry.value != null) continue;
    final name = entry.key;
    final field = RegExp(
      '^  (?:late )?(?:final )?([\\w<>?, ]+?) $name\\s*[;=]',
      multiLine: true,
    ).firstMatch(kernel);
    expect(
      field,
      isNotNull,
      reason: '`this.$name` initialises a field that could not be found',
    );
    final declared = RegExp('this\\.$name\\s*=\\s*([^,\n]+)').firstMatch(body);
    parsed[name] = declared == null
        ? field!.group(1)!.trim()
        : '${field!.group(1)!.trim()} = ${declared.group(1)!.trim()}';
  }
  return parsed;
}

/// The exception classes declared in [sourcePaths], in the order they appear.
///
/// Derived rather than listed so that an exception added to a module is covered
/// without anyone remembering to extend the guard — and so that a guard cannot
/// be satisfied by quietly dropping a class from a hand-written list.
List<String> exceptionClassesIn(Iterable<String> sourcePaths) {
  final names = <String>[];
  for (final path in sourcePaths) {
    final source = File(path).readAsStringSync();
    for (final match
        in RegExp(r'^class (\w+Exception) extends \w+', multiLine: true)
            .allMatches(source)) {
      names.add(match.group(1)!);
    }
  }
  return names;
}

/// Asserts each of [classNames]' summary block lists the same parameters, in the
/// same order, that its constructor in [sourcePaths] forwards.
void expectSummaryListsForwardedParameters({
  required String summaryPath,
  required Iterable<String> sourcePaths,
  required Iterable<String> classNames,
}) {
  final summary = File(summaryPath).readAsStringSync();
  for (final className in classNames) {
    expect(
      parseParameters(constructorBody(summary, className)).keys,
      parseParameters(constructorBodyFrom(sourcePaths, className)).keys,
      reason: '$className\'s summary block lists different parameters, or lists '
          'them in a different order, than the source forwards',
    );
  }
}

/// Asserts every parameter type in each of [classNames]' summary block matches
/// the kernel constructor the parameter is inherited from.
void expectSummaryTypesMatchKernel({
  required String summaryPath,
  required Iterable<String> classNames,
}) {
  final expected = kernelParameters();
  final summary = File(summaryPath).readAsStringSync();

  for (final className in classNames) {
    final documented = parseParameters(constructorBody(summary, className));
    final offenders = <String>[
      for (final entry in documented.entries)
        if (entry.value != expected[entry.key])
          '$className.${entry.key}: summary says `${entry.value}`, '
              'TomException declares `${expected[entry.key]}`',
    ];
    expect(offenders, isEmpty);
  }
}
