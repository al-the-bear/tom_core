import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Domain exception stand-in: proves the [YamlConfigReader.errorFactory]
/// seam keeps the thrown type loader-specific.
class _CfgException implements Exception {
  final String message;
  const _CfgException(this.message);
  @override
  String toString() => 'CfgException: $message';
}

YamlConfigReader _reader({Map<String, String> env = const {}}) =>
    YamlConfigReader(env: env, errorFactory: _CfgException.new);

YamlMap _map(String yaml) => loadYaml(yaml) as YamlMap;

void main() {
  group('YamlConfigReader typed accessors', () {
    test('requireString returns the value', () {
      final r = _reader();
      expect(r.requireString(_map('a: hello'), 'a', 'root.a'), 'hello');
    });

    test('requireString throws domain exception when missing', () {
      final r = _reader();
      expect(
        () => r.requireString(_map('b: x'), 'a', 'root.a'),
        throwsA(isA<_CfgException>().having(
          (e) => e.message,
          'message',
          'Missing required field: root.a',
        )),
      );
    });

    test('requireString throws on type mismatch with path + runtimeType', () {
      final r = _reader();
      expect(
        () => r.requireString(_map('a: 7'), 'a', 'root.a'),
        throwsA(isA<_CfgException>().having(
          (e) => e.message,
          'message',
          contains('root.a must be a string (got'),
        )),
      );
    });

    test('optionalString returns null when absent', () {
      expect(_reader().optionalString(_map('b: x'), 'a', 'root.a'), isNull);
    });

    test('requireInt / optionalInt', () {
      final r = _reader();
      expect(r.requireInt(_map('a: 42'), 'a', 'root.a'), 42);
      expect(r.optionalInt(_map('b: x'), 'a', 'root.a'), isNull);
      expect(
        () => r.requireInt(_map('a: nope'), 'a', 'root.a'),
        throwsA(isA<_CfgException>()),
      );
    });

    test('requireDouble accepts int and double', () {
      final r = _reader();
      expect(r.requireDouble(_map('a: 3'), 'a', 'root.a'), 3.0);
      expect(r.requireDouble(_map('a: 2.5'), 'a', 'root.a'), 2.5);
    });

    test('optionalDouble returns null when absent, throws on non-number', () {
      final r = _reader();
      expect(r.optionalDouble(_map('b: x'), 'a', 'root.a'), isNull);
      expect(
        () => r.optionalDouble(_map('a: text'), 'a', 'root.a'),
        throwsA(isA<_CfgException>()),
      );
    });

    test('optionalBool', () {
      final r = _reader();
      expect(r.optionalBool(_map('a: true'), 'a', 'root.a'), isTrue);
      expect(r.optionalBool(_map('b: x'), 'a', 'root.a'), isNull);
      expect(
        () => r.optionalBool(_map('a: 1'), 'a', 'root.a'),
        throwsA(isA<_CfgException>()),
      );
    });

    test('requireMap / optionalMap', () {
      final r = _reader();
      expect(r.requireMap(_map('a: {x: 1}'), 'a', 'root.a'), isA<YamlMap>());
      expect(r.optionalMap(_map('b: 1'), 'a'), isNull);
      expect(
        () => r.optionalMap(_map('a: 1'), 'a'),
        throwsA(isA<_CfgException>().having(
          (e) => e.message,
          'message',
          contains('Field `a` must be a map'),
        )),
      );
    });

    test('requireList / optionalList', () {
      final r = _reader();
      expect(r.requireList(_map('a: [1, 2]'), 'a', 'root.a'), isA<YamlList>());
      expect(r.optionalList(_map('b: 1'), 'a', 'root.a'), isNull);
      expect(
        () => r.requireList(_map('a: 1'), 'a', 'root.a'),
        throwsA(isA<_CfgException>()),
      );
    });

    test('parseUri', () {
      final r = _reader();
      expect(r.parseUri('https://x/y', 'root.url'), Uri.parse('https://x/y'));
      expect(
        () => r.parseUri('::::', 'root.url'),
        throwsA(isA<_CfgException>()),
      );
    });
  });

  group('YamlConfigReader.expandEnv', () {
    test('returns input unchanged when no token', () {
      expect(_reader().expandEnv('plain', 'root.x'), 'plain');
    });

    test('substitutes a defined variable', () {
      final r = _reader(env: {'TOKEN': 'secret'});
      expect(r.expandEnv(r'Bearer ${TOKEN}', 'root.x'), 'Bearer secret');
    });

    test('substitutes multiple variables', () {
      final r = _reader(env: {'A': '1', 'B': '2'});
      expect(r.expandEnv(r'${A}-${B}', 'root.x'), '1-2');
    });

    test('throws on undefined variable with path', () {
      expect(
        () => _reader().expandEnv(r'${MISSING}', 'root.x'),
        throwsA(isA<_CfgException>().having(
          (e) => e.message,
          'message',
          contains(r'root.x references undefined env var `${MISSING}`'),
        )),
      );
    });

    test('throws on unterminated token', () {
      expect(
        () => _reader().expandEnv(r'${UNCLOSED', 'root.x'),
        throwsA(isA<_CfgException>().having(
          (e) => e.message,
          'message',
          contains('root.x has unterminated'),
        )),
      );
    });

    test('throws on empty token', () {
      expect(
        () => _reader().expandEnv(r'${}', 'root.x'),
        throwsA(isA<_CfgException>().having(
          (e) => e.message,
          'message',
          contains('root.x has empty'),
        )),
      );
    });

    test('a bare \$ without brace is passed through verbatim', () {
      expect(_reader().expandEnv(r'cost $5', 'root.x'), r'cost $5');
    });
  });
}
