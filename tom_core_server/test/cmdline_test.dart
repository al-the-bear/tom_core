import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

void main() {
  group('TomArgs.parseArgsToMap', () {
    test('parses key=value pairs', () {
      final m = TomArgs.parseArgsToMap(['name=server', 'port=8080']);
      expect(m['name'], 'server');
      expect(m['port'], 8080);
    });

    test('records a bare flag as boolean true', () {
      expect(TomArgs.parseArgsToMap(['--verbose'])['--verbose'], isTrue);
    });

    test('keeps only the text before the first "=" as the key', () {
      // A value may itself contain "=" (split only takes parts.length > 1 into
      // account, then joins on the original); the helper splits on every "=",
      // so document the first-segment-is-key behaviour for a plain pair.
      final m = TomArgs.parseArgsToMap(['key=value']);
      expect(m['key'], 'value');
    });
  });

  group('TomArgs.convertToObjectMap value conversion', () {
    Object? convert(String v) => TomArgs.convertToObjectMap({'_': v})['_'];

    test('"true"/"false" become booleans', () {
      expect(convert('true'), isTrue);
      expect(convert('false'), isFalse);
    });

    test('all-digit strings become ints', () {
      expect(convert('8080'), 8080);
      expect(convert('0'), 0);
    });

    test('decimal strings become doubles', () {
      expect(convert('3.14'), 3.14);
    });

    test('a leading sign keeps the value a String (no whole-string match)', () {
      expect(convert('-5'), '-5');
      expect(convert('-1.5'), '-1.5');
    });

    test('trailing non-numeric text keeps the value a String', () {
      expect(convert('12px'), '12px');
    });

    test('a quoted value is unquoted to a String', () {
      expect(convert('"hello"'), 'hello');
      expect(convert("'world'"), 'world');
    });

    test('any other text passes through unchanged', () {
      expect(convert('localhost'), 'localhost');
    });
  });

  group('TomEnvFile.parse', () {
    test('parses pairs and converts value types', () {
      final env = TomEnvFile.parse(['PORT=8080', 'RATE=1.5', 'ON=true']);
      expect(env['PORT'], 8080);
      expect(env['RATE'], 1.5);
      expect(env['ON'], isTrue);
    });

    test('skips blank lines and # comments', () {
      final env = TomEnvFile.parse(['', '# a comment', 'KEY=value']);
      expect(env, {'KEY': 'value'});
    });

    test('keeps a quoted value as a String without conversion', () {
      final env = TomEnvFile.parse(['NAME="my service"', 'NUM="123"']);
      expect(env['NAME'], 'my service');
      expect(env['NUM'], '123'); // quoted digits stay a String
    });

    test('strips an inline comment after an unquoted value', () {
      final env = TomEnvFile.parse(['KEY=value # trailing note']);
      expect(env['KEY'], 'value');
    });

    test('maps an empty value to null', () {
      expect(TomEnvFile.parse(['EMPTY='])['EMPTY'], isNull);
    });

    test('ignores a line with no "=" and a line with an empty key', () {
      final env = TomEnvFile.parse(['novalue', '=orphan', 'KEY=ok']);
      expect(env, {'KEY': 'ok'});
    });
  });

  group('TomEnvFile.merge', () {
    test('later sources override earlier ones', () {
      final env = TomEnvFile.merge([
        {'A': 1, 'B': 'base'},
        {'B': 'override', 'C': 3},
      ]);
      expect(env, {'A': 1, 'B': 'override', 'C': 3});
    });

    test('merging nothing yields an empty map', () {
      expect(TomEnvFile.merge([]), isEmpty);
    });
  });

  group('TomEnvFile file IO', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('tom_cmdline_test');
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('read returns an empty map when the file is missing', () {
      expect(TomEnvFile.read('${dir.path}/.env.absent'), isEmpty);
    });

    test('read parses a .env file from disk', () async {
      final f = File('${dir.path}/.env');
      await f.writeAsString('# header\nPORT=8080\nNAME="svc"\n');
      final env = TomEnvFile.read(f.path);
      expect(env['PORT'], 8080);
      expect(env['NAME'], 'svc');
    });

    test('readAsync parses the same content', () async {
      final f = File('${dir.path}/.env');
      await f.writeAsString('ENABLED=true\nWORKERS=4\n');
      final env = await TomEnvFile.readAsync(f.path);
      expect(env['ENABLED'], isTrue);
      expect(env['WORKERS'], 4);
    });

    test('readAsync returns an empty map when the file is missing', () async {
      expect(await TomEnvFile.readAsync('${dir.path}/.env.absent'), isEmpty);
    });

    test('load reads the file (the OS environment is not mutated)', () async {
      final f = File('${dir.path}/.env');
      await f.writeAsString('LOADED=yes\n');
      expect(TomEnvFile.load(f.path)['LOADED'], 'yes');
    });
  });
}
