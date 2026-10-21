/// What the package is, read from its source: a leaf that any Dart program can
/// link, with no I/O of its own and nowhere to put content in its audit trail.
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  final lib = Directory('lib');
  final sources = {
    for (final f in lib.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart')) f.path: f.readAsStringSync(),
  };

  test('the library reaches no dart:io, no Flutter and no platform package, '
      'so a browser build links it', () {
    expect(sources, isNotEmpty);
    for (final entry in sources.entries) {
      final imports = RegExp(
        r"^import '([^']+)'",
        multiLine: true,
      ).allMatches(entry.value).map((m) => m.group(1)!);
      for (final uri in imports) {
        expect(
          uri.startsWith('dart:') &&
              !{'dart:async', 'dart:convert', 'dart:math'}.contains(uri),
          isFalse,
          reason: '${entry.key} imports $uri',
        );
        if (uri.startsWith('package:')) {
          expect(
            uri,
            anyOf(
              startsWith('package:meta/'),
              startsWith('package:tom_core_llm/'),
            ),
            reason: '${entry.key} imports $uri',
          );
        }
      }
    }
  });

  test('the pubspec depends on meta and tom_core_llm alone', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dependencies = pubspec
        .split('\ndev_dependencies:')
        .first
        .split('\ndependencies:')
        .last;
    final names = RegExp(
      r'^  (\w+):',
      multiLine: true,
    ).allMatches(dependencies).map((m) => m.group(1)).toSet();
    expect(names, {'meta', 'tom_core_llm'});
  });

  test('an invocation has no public constructor: consent exists only through '
      'its two factories', () {
    final source = sources.entries
        .firstWhere((e) => e.key.endsWith('invocation.dart'))
        .value;
    expect(source, contains('const AgentInvocation._({'));
    expect(
      RegExp(
        r'^\s*(?:const\s+)?AgentInvocation\s*\(',
        multiLine: true,
      ).hasMatch(source),
      isFalse,
    );
    final factories = RegExp(
      r'factory\s+AgentInvocation\.(\w+)\s*\(\{([^}]*)\}\)',
    ).allMatches(source).map((m) => (m.group(1)!, m.group(2)!)).toList();
    expect([for (final f in factories) f.$1], ['mint', 'withExecution']);
    for (final (name, params) in factories) {
      expect(
        params,
        isNot(
          contains(
            RegExp(
              r'origin|token|credential|allowExecution',
              caseSensitive: false,
            ),
          ),
        ),
        reason: name,
      );
    }
  });
}
