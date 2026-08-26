import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

/// Tests for the little_things module (`TomClientException`,
/// `TomClientUIException`).
void main() {
  group('TomClientException', () {
    test('carries the key, message and parameters', () {
      final ex = TomClientException(
        'client.error',
        'Something went wrong',
        parameters: {'field': 'email'},
      );
      expect(ex.key, 'client.error');
      expect(ex.defaultUserMessage, 'Something went wrong');
      expect(ex.parameters, {'field': 'email'});
    });

    test('is a kernel TomException', () {
      final ex = TomClientException('client.error', 'msg');
      expect(ex, isA<TomException>());
    });

    test('is not a TomClientUIException', () {
      final ex = TomClientException('client.error', 'msg');
      expect(ex, isNot(isA<TomClientUIException>()));
    });

    // Full-surface: the constructor forwards every optional argument to the
    // kernel TomException. `parameters`/`rootException` are covered above; these
    // pin the remaining two — `stack` (the raw trace object) and `autoLog`.
    test('forwards the stack trace object to the kernel exception', () {
      final trace = StackTrace.current;
      final ex = TomClientException('client.error', 'msg', stack: trace);
      expect(identical(ex.stack, trace), isTrue);
      // The formatted representation is derived from the forwarded trace.
      expect(ex.stackTrace, isNotEmpty);
    });

    test('forwards the autoLog flag (default false, honours true)', () {
      expect(TomClientException('client.error', 'msg').autoLog, isFalse);
      expect(
        TomClientException('client.error', 'msg', autoLog: true).autoLog,
        isTrue,
      );
    });
  });

  group('TomClientUIException', () {
    test('is both a TomClientException and a TomException', () {
      final ex = TomClientUIException('ui.error', 'Please try again');
      expect(ex, isA<TomClientException>());
      expect(ex, isA<TomException>());
      expect(ex.key, 'ui.error');
      expect(ex.defaultUserMessage, 'Please try again');
    });

    test('forwards stack, parameters and autoLog through both super calls', () {
      final trace = StackTrace.current;
      final ex = TomClientUIException(
        'ui.error',
        'Please try again',
        parameters: {'retryable': true},
        stack: trace,
        autoLog: true,
      );
      expect(ex.parameters, {'retryable': true});
      expect(identical(ex.stack, trace), isTrue);
      expect(ex.autoLog, isTrue);
    });

    test('type discriminates user-facing from internal client errors', () {
      // A presentable error rethrows; a non-presentable one is wrapped.
      TomException surface(TomException e) {
        if (e is TomClientUIException) return e;
        return TomClientUIException('wrapped', 'Unexpected error', rootException: e);
      }

      final presentable = TomClientUIException('ui.error', 'Shown to user');
      final internal = TomClientException('internal', 'Do not show');

      expect(identical(surface(presentable), presentable), isTrue);
      final wrapped = surface(internal);
      expect(wrapped, isA<TomClientUIException>());
      expect(wrapped.rootException, internal);
    });
  });

  group('the API summary mirrors the little_things sources', () {
    // `completion/README.md` §6 says the doc/ mirror is to be verified, not
    // trusted. It had drifted to `bool? autoLog`, which no call site can pass.
    //
    // The types are worth checking mechanically rather than by eye because
    // these classes declare none of them: every parameter arrives by
    // `super.x`, and a super-parameter takes its type from the *immediate*
    // superclass constructor, not from wherever the field was first declared.
    // For `stack` the two differ — `TomBaseException` declares the field
    // `Object?`, `TomException`'s constructor narrows it to `StackTrace?` —
    // so reading the field declaration to document the parameter gives the
    // wrong answer, plausibly. Comparing against the kernel constructor is
    // therefore not a convenience: it is the only place the answer is.
    const summaryPath = 'doc/api_reference/api_summary_little_things.md';
    const sourcePath = 'lib/src/tomclient/little_things/client_exceptions.dart';
    // A path dependency (`pubspec.yaml`), so this relative path is as stable
    // as the package layout itself.
    const kernelPath =
        '../tom_core_kernel/lib/src/tombase/little_things/exception_base.dart';

    /// The parameter lines of [name]'s constructor, from `(` to the `})` or
    /// `)` that closes the list.
    String constructorBody(String source, String name) {
      final start = source.indexOf('$name(\n');
      expect(start, isNot(-1), reason: 'no constructor $name( in the source');
      final open = source.indexOf('\n', start) + 1;
      final close = source.indexOf(RegExp(r'^\}?\)', multiLine: true), open);
      // The declaration sites are indented, the summary's code fence is not,
      // so match either and take whichever terminator comes first.
      final closeIndented =
          source.indexOf(RegExp(r'^\s+\}?\)', multiLine: true), open);
      final end = [close, closeIndented].where((i) => i >= 0).reduce(
            (a, b) => a < b ? a : b,
          );
      return source.substring(open, end);
    }

    /// `{parameterName: 'declaredType' or 'declaredType = default'}`, in the
    /// order declared. `this.x` / `super.x` forms yield a null type — the
    /// declaration carries no type of its own.
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

    final kernel = File(kernelPath).readAsStringSync();

    /// The kernel constructor's parameters with `this.x` resolved to the type
    /// of the field it initialises — which is where the real answer lives for
    /// `autoLog`.
    Map<String, String?> kernelParameters() {
      final parsed = parseParameters(constructorBody(kernel, 'TomException'));
      // Re-read the raw body: a `this.x = default` line loses its default in
      // the null-typed branch above, and the default is part of the contract.
      final body = constructorBody(kernel, 'TomException');
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

    test('the summary shows the parameters the source actually forwards', () {
      final source = File(sourcePath).readAsStringSync();
      final summary = File(summaryPath).readAsStringSync();

      for (final className in const [
        'TomClientException',
        'TomClientUIException',
      ]) {
        expect(
          parseParameters(constructorBody(summary, className)).keys,
          parseParameters(constructorBody(source, className)).keys,
          reason: '$className\'s summary block lists different parameters, or '
              'lists them in a different order, than $sourcePath forwards',
        );
      }
    });

    test('every parameter type matches the kernel constructor it comes from',
        () {
      final expected = kernelParameters();
      final summary = File(summaryPath).readAsStringSync();

      for (final className in const [
        'TomClientException',
        'TomClientUIException',
      ]) {
        final documented = parseParameters(constructorBody(summary, className));
        final offenders = <String>[
          for (final entry in documented.entries)
            if (entry.value != expected[entry.key])
              '$className.${entry.key}: summary says `${entry.value}`, '
                  'TomException declares `${expected[entry.key]}`',
        ];
        expect(offenders, isEmpty);
      }
    });

    test('the kernel constructor parser reports the types it should', () {
      // Without this the two tests above pass just as happily on an empty
      // parse. These three are the ones the mirror got wrong or was accused
      // of getting wrong, so pinning them pins the parser where it matters.
      final parsed = kernelParameters();
      expect(parsed['stack'], 'StackTrace?');
      expect(parsed['autoLog'], 'bool = false');
      expect(parsed['parameters'], 'Map<String, Object?>?');
    });

    test('the class hierarchy is drawn as deep as the source goes', () {
      // Conditioned on the source rather than hard-coded: if a base class is
      // ever inserted or removed, this fails rather than silently blessing a
      // diagram that no longer describes anything.
      final summary = File(summaryPath).readAsStringSync();
      final hierarchy = RegExp(r'## Class Hierarchy\n+```\n([\s\S]*?)```')
          .firstMatch(summary);
      expect(hierarchy, isNotNull, reason: 'no class hierarchy block');

      final bases = <String>[];
      for (var type in const ['TomClientUIException', 'TomClientException']) {
        while (true) {
          final source = type.startsWith('TomClient')
              ? File(sourcePath).readAsStringSync()
              : kernel;
          final extends_ = RegExp('class $type extends (\\w+)')
              .firstMatch(source)
              ?.group(1);
          if (extends_ == null) break;
          bases.add(extends_);
          type = extends_;
        }
        break;
      }
      // TomBaseException lives in tom_basics, which the walk above cannot
      // reach — it stops when it runs out of readable source, and that last
      // name is exactly the one the diagram used to omit.
      expect(bases, contains('TomBaseException'));

      for (final name in bases) {
        expect(
          hierarchy!.group(1),
          contains(name),
          reason: '`$name` is in the chain above TomClientUIException but is '
              'missing from the hierarchy diagram',
        );
      }
    });
  });
}
