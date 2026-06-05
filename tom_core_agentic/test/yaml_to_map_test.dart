// Tests for the canonical YAML -> plain-Map loader (prototype-plan-2 item 4).
//
// `loadYamlAsMap` is the single, domain-free entry point the brain config
// loaders standardize on: it parses a YAML document and returns plain
// `Map<String, Object?>` / `List<Object?>` / scalar values — never a
// `YamlMap` or `YamlList`. Downstream type-safe reads then go through
// `MapFieldReader` (item 5), which operates on plain maps.
//
// `expandEnvVars` is the canonical `${NAME}` expander these loaders share;
// `YamlConfigReader.expandEnv` now delegates to it, so the two can never
// drift.
//
// What this file pins:
//   1. Round-trip: nested maps/lists/scalars convert to plain collections.
//   2. No `YamlMap`/`YamlList`/`YamlScalar` survives anywhere in the output
//      (recursive type walk — the item-4 verification gate).
//   3. Type-error messages: a non-map document and a non-string key fail
//      with located, engineer-readable messages.
//   4. `${ENV}` expansion: substitution, multiple tokens, and the three
//      failure modes (undefined / unterminated / empty), each with path.

import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:yaml/yaml.dart';
import 'package:test/test.dart';

/// Recursively asserts no `package:yaml` node type survives in [value].
void _assertNoYamlNodes(Object? value, String path) {
  expect(value, isNot(isA<YamlMap>()), reason: '$path is a YamlMap');
  expect(value, isNot(isA<YamlList>()), reason: '$path is a YamlList');
  expect(value, isNot(isA<YamlNode>()), reason: '$path is a YamlNode');
  if (value is Map) {
    value.forEach((k, v) {
      expect(k, isA<String>(), reason: '$path key `$k` is not a String');
      _assertNoYamlNodes(v, '$path.$k');
    });
  } else if (value is List) {
    for (var i = 0; i < value.length; i++) {
      _assertNoYamlNodes(value[i], '$path[$i]');
    }
  }
}

void main() {
  group('loadYamlAsMap — round-trip', () {
    test('nested maps, lists and scalars become plain collections', () {
      const source = '''
name: brain
version: 2
enabled: true
ratio: 0.5
providers:
  - id: omlx
    models:
      - gemma
      - llama
    weights:
      a: 1
      b: 2
  - id: ollama
    models: []
nested:
  deep:
    value: leaf
''';
      final map = loadYamlAsMap(source);

      // Top level is a plain Map<String, Object?>.
      expect(map, isA<Map<String, Object?>>());
      expect(map['name'], 'brain');
      expect(map['version'], 2);
      expect(map['enabled'], isTrue);
      expect(map['ratio'], 0.5);

      // Lists are plain List<Object?>.
      final providers = map['providers'];
      expect(providers, isA<List<Object?>>());
      providers as List<Object?>;
      expect(providers, hasLength(2));

      final first = providers[0] as Map<String, Object?>;
      expect(first['id'], 'omlx');
      expect(first['models'], <Object?>['gemma', 'llama']);
      expect(first['weights'], <String, Object?>{'a': 1, 'b': 2});

      final second = providers[1] as Map<String, Object?>;
      expect(second['models'], isEmpty);

      // Deeply nested map.
      final nested = map['nested'] as Map<String, Object?>;
      final deep = nested['deep'] as Map<String, Object?>;
      expect(deep['value'], 'leaf');
    });

    test('output contains no YamlMap/YamlList/YamlScalar anywhere', () {
      const source = '''
a:
  b:
    - x: 1
      y: [1, 2, 3]
    - z: true
list:
  - one
  - two
''';
      final map = loadYamlAsMap(source);
      _assertNoYamlNodes(map, 'root');
    });

    test('a plain mutable map is returned (values are assignable)', () {
      final map = loadYamlAsMap('k: v');
      // Must not throw an UnsupportedError the way a read-only YamlMap would.
      expect(() => map['k'] = 'w', returnsNormally);
      expect(map['k'], 'w');
    });
  });

  group('loadYamlAsMap — type errors', () {
    test('a non-map document fails with a located message (default factory)', () {
      expect(
        () => loadYamlAsMap('- just\n- a\n- list'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('root must be a map'),
          ),
        ),
      );
    });

    test('an empty document fails as a non-map', () {
      expect(
        () => loadYamlAsMap(''),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('root must be a map'))),
      );
    });

    test('a non-string key fails with a located message', () {
      // YAML allows integer keys; config requires string keys.
      expect(
        () => loadYamlAsMap('1: a\n2: b'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('non-string key'), contains('root')),
        )),
      );
    });

    test('a custom error factory wraps the message in the caller type', () {
      expect(
        () => loadYamlAsMap('- x', errorFactory: _ConfigError.new),
        throwsA(isA<_ConfigError>()
            .having((e) => e.message, 'message', contains('root must be a map'))),
      );
    });

    test('rootPath appears verbatim in messages', () {
      expect(
        () => loadYamlAsMap('- x', rootPath: 'substrate'),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('substrate must be a map'))),
      );
    });
  });

  group('expandEnvVars', () {
    const env = {'TOKEN': 'secret', 'A': '1', 'B': '2'};

    test('returns input unchanged when there is no token', () {
      expect(expandEnvVars('plain', env, path: 'root.x'), 'plain');
    });

    test('expands a single token', () {
      expect(
          expandEnvVars(r'Bearer ${TOKEN}', env, path: 'root.x'), 'Bearer secret');
    });

    test('expands multiple tokens', () {
      expect(expandEnvVars(r'${A}-${B}', env, path: 'root.x'), '1-2');
    });

    test('a bare \$ that is not a token is left untouched', () {
      expect(expandEnvVars(r'cost $5', env, path: 'root.x'), r'cost $5');
    });

    test('throws on undefined variable with path', () {
      expect(
        () => expandEnvVars(r'${MISSING}', env, path: 'root.x'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            contains(r'root.x references undefined env var `${MISSING}`'))),
      );
    });

    test('throws on unterminated token with path', () {
      expect(
        () => expandEnvVars(r'${UNCLOSED', env, path: 'root.x'),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('root.x has unterminated'))),
      );
    });

    test('throws on empty token with path', () {
      expect(
        () => expandEnvVars(r'${}', env, path: 'root.x'),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('root.x has empty'))),
      );
    });

    test('a custom error factory wraps env-expansion failures', () {
      expect(
        () => expandEnvVars(r'${MISSING}', env,
            path: 'root.x', errorFactory: _ConfigError.new),
        throwsA(isA<_ConfigError>()),
      );
    });
  });

  group('YamlConfigReader.expandEnv delegates to expandEnvVars', () {
    test('shares the exact same behaviour and messages', () {
      final reader = YamlConfigReader(
        env: const {'TOKEN': 'secret'},
        errorFactory: _ConfigError.new,
      );
      expect(reader.expandEnv(r'Bearer ${TOKEN}', 'p'), 'Bearer secret');
      expect(
        () => reader.expandEnv(r'${MISSING}', 'p'),
        throwsA(isA<_ConfigError>()
            .having((e) => e.message, 'message', contains('undefined env var'))),
      );
    });
  });
}

/// A loader-style domain exception used to prove the `errorFactory` seam.
final class _ConfigError implements Exception {
  final String message;
  _ConfigError(this.message);
  @override
  String toString() => '_ConfigError: $message';
}
