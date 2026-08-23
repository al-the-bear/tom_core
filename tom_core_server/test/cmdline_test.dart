import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.dart' show FixtureServerConfig;
import 'fixtures/reflection_fixture.reflection.dart';

void main() {
  // fillFromArgs binds through the reflector, which throws until the generated
  // mirrors are registered.
  setUpAll(() {
    initializeReflection();
  });

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
      final m = TomArgs.parseArgsToMap(['key=value']);
      expect(m['key'], 'value');
    });

    // The separator is the *first* "="; every later one is part of the value.
    // A connection string, a URL with a query, and a padded base64 blob all
    // carry further "=" characters that are data, and cutting the value at the
    // second one corrupts it silently — there is no diagnostic, the argument
    // simply arrives short.
    test('a value containing further "=" survives whole', () {
      final m = TomArgs.parseArgsToMap(['url=mysql://h/db?user=root']);
      expect(m['url'], 'mysql://h/db?user=root');
    });

    test('base64 padding is not mistaken for a separator', () {
      final m = TomArgs.parseArgsToMap(['secret=YWJjZA==']);
      expect(m['secret'], 'YWJjZA==');
    });

    test('a value that is only "=" characters is kept', () {
      expect(TomArgs.parseArgsToMap(['k==='])['k'], '==');
    });

    // The two parsers are documented as sharing one syntax, so the same text
    // has to mean the same thing whether it arrives on the command line or
    // from a .env file. This is the guarantee that regressed.
    test('agrees with TomEnvFile.parse on where the key ends', () {
      const line = 'url=mysql://h/db?user=root&pw=s3cret';
      expect(TomArgs.parseArgsToMap([line]), TomEnvFile.parse([line]));
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

    // The shape test says "all digits", but Dart's int is 64-bit, so a longer
    // run has no int to become. It stays a String for the same reason `-5` and
    // `12px` do: the value is not something this converter can represent as an
    // int, so it is left as the text it arrived as. Previously the shape alone
    // decided and the unguarded parse threw, taking the whole parse down.
    test('a digit run too large for an int stays a String', () {
      expect(convert('99999999999999999999'), '99999999999999999999');
    });

    // The boundary itself, both sides, because "too large" is only meaningful
    // if the largest representable value still converts.
    test('the 64-bit boundary converts and one past it does not', () {
      expect(convert('9223372036854775807'), 9223372036854775807);
      expect(convert('9223372036854775808'), '9223372036854775808');
    });

    // An oversized run has no decimal point, so it cannot fall through to the
    // double branch and arrive as a lossy approximation. Pinned because
    // "otherwise treat it as a double" is the obvious wrong repair.
    test('an oversized digit run does not become a double', () {
      expect(convert('99999999999999999999'), isA<String>());
    });

    test('a leading sign keeps the value a String (no whole-string match)', () {
      expect(convert('-5'), '-5');
      expect(convert('-1.5'), '-1.5');
    });

    test('trailing non-numeric text keeps the value a String', () {
      expect(convert('12px'), '12px');
    });

    // The patterns are unanchored, so `doublePattern` matches the "1.2" prefix
    // of "1.2.3" — but `_convertString` compares the match against the *whole*
    // string, which is what keeps a dotted triple (a version, an IPv4 address)
    // a String. Pinned because the prefix match invites the opposite reading.
    test('a dotted triple keeps the value a String', () {
      expect(convert('1.2.3'), '1.2.3');
      expect(convert('192.168.0.1'), '192.168.0.1');
    });

    // The documented double shape is `digits . digits?`, so the fractional part
    // is optional and a trailing dot still converts.
    test('a trailing dot still converts to a double', () {
      expect(convert('5.'), 5.0);
    });

    test('exponent notation keeps the value a String', () {
      expect(convert('1e3'), '1e3');
    });

    test('a quoted value is unquoted to a String', () {
      expect(convert('"hello"'), 'hello');
      expect(convert("'world'"), 'world');
    });

    test('an empty quoted value is the empty String', () {
      expect(convert('""'), '');
      expect(convert("''"), '');
    });

    // Unquoting needs a *pair*. A lone quote character is one character long,
    // so it is its own first and last character — the reason the old
    // drop-both-ends rule reduced to substring(1, 0) and raised a RangeError
    // naming neither the key nor the file it came from.
    test('a lone quote character is kept verbatim', () {
      expect(convert('"'), '"');
      expect(convert("'"), "'");
    });

    // Without a closing quote there is nothing to strip, and stripping the
    // last character anyway silently ate it — `"hello` became `hell` and
    // `"abc` became `ab`. No error, no diagnostic: a password or token that
    // happens to begin with a quote simply arrived one character short.
    test('a value with no closing quote is kept verbatim', () {
      expect(convert('"hello'), '"hello');
      expect(convert("'hello"), "'hello");
      expect(convert('"abc'), '"abc');
    });

    // The interior space makes this the nastiest shape of the truncation:
    // `"a b` became `a ` — corruption that ends in whitespace and so survives
    // a visual check of a log line or a config dump.
    test('an unterminated quote around a value with a space keeps it', () {
      expect(convert('"a b'), '"a b');
    });

    test('mismatched quotes are kept verbatim', () {
      expect(convert('"hello\''), '"hello\'');
    });

    // A trailing quote alone was never treated as quoted, and still is not.
    test('a trailing quote alone is kept verbatim', () {
      expect(convert('hello"'), 'hello"');
    });

    test('any other text passes through unchanged', () {
      expect(convert('localhost'), 'localhost');
    });
  });

  group('TomArgs.fillFromArgs', () {
    test('fills String and int fields from key=value arguments', () {
      final config = TomArgs.fillFromArgs([
        'name=svc',
        'port=8080',
      ], FixtureServerConfig());
      expect(config.name, 'svc');
      expect(config.port, 8080);
    });

    test('fills a double field from a decimal value', () {
      final config = TomArgs.fillFromArgs(['rate=1.5'], FixtureServerConfig());
      expect(config.rate, 1.5);
    });

    // A command line cannot say "double": `rate=2` converts to an int, which
    // the reflector widens onto the declared double field.
    test('fills a double field from a whole number', () {
      final config = TomArgs.fillFromArgs(['rate=2'], FixtureServerConfig());
      expect(config.rate, 2.0);
    });

    test('coerces a key=value bool into the bool field', () {
      final config = TomArgs.fillFromArgs([
        'verbose=true',
      ], FixtureServerConfig());
      expect(config.verbose, isTrue);
    });

    // RCJ2: a *bare* flag is recorded by fillFromArgs as the boolean `true`
    // (matching how `key=true` converts), so it fills a reflected bool field
    // directly.
    test('a bare bool flag fills the bool field (RCJ2)', () {
      final config = TomArgs.fillFromArgs(['verbose'], FixtureServerConfig());
      expect(config.verbose, isTrue);
    });

    test('a quoted value stays a String', () {
      final config = TomArgs.fillFromArgs([
        'name="my svc"',
      ], FixtureServerConfig());
      expect(config.name, 'my svc');
    });

    // The consequence that matters: an unterminated quote used to reach the
    // field one character short, silently. A secret or host name beginning
    // with a quote was corrupted on the way in, and nothing said so.
    test('an unterminated quote reaches the field whole', () {
      final config = TomArgs.fillFromArgs([
        'name="my svc',
      ], FixtureServerConfig());
      expect(config.name, '"my svc');
    });

    // The consequence that matters here: a long digit run belongs in a String
    // field, and the caller would have been happy with it. Instead the parse
    // threw before any field was assigned, so an account number in one
    // argument cost the server every other argument as well.
    test('an oversized digit run fills a String field', () {
      final config = TomArgs.fillFromArgs([
        'name=99999999999999999999',
        'port=8080',
      ], FixtureServerConfig());
      expect(config.name, '99999999999999999999');
      expect(config.port, 8080);
    });

    test('fills every field type in one pass', () {
      final config = TomArgs.fillFromArgs([
        'name=svc',
        'port=8080',
        'rate=1.5',
        'verbose=true',
      ], FixtureServerConfig());
      expect(config.name, 'svc');
      expect(config.port, 8080);
      expect(config.rate, 1.5);
      expect(config.verbose, isTrue);
    });

    test('an argument with no matching field is ignored', () {
      final config = TomArgs.fillFromArgs([
        'unrelated=1',
      ], FixtureServerConfig());
      expect(config.name, '');
      expect(config.port, 0);
      expect(config.rate, 0.0);
      expect(config.verbose, isFalse);
    });

    // fillFromArgs has no notion of a *required* argument — it binds whatever
    // is present and never validates completeness. An omitted argument is
    // therefore indistinguishable from one that was never declared: the field
    // simply keeps its initialiser. Callers that need a value to be mandatory
    // must check it themselves after binding.
    test('an omitted argument leaves the field at its initialiser', () {
      final config = TomArgs.fillFromArgs(['name=svc'], FixtureServerConfig());
      expect(config.name, 'svc');
      expect(config.port, 0);
    });

    test('a value whose type does not match the field throws', () {
      // "abc" is not numeric, so it stays a String and cannot fill an int.
      expect(
        () => TomArgs.fillFromArgs(['port=abc'], FixtureServerConfig()),
        throwsA(isA<TomReflectorException>()),
      );
    });

    test('a decimal value cannot narrow into an int field', () {
      expect(
        () => TomArgs.fillFromArgs(['port=1.5'], FixtureServerConfig()),
        throwsA(isA<TomReflectorException>()),
      );
    });

    // The same first-"=" rule reaches the reflected object, not just the map:
    // a connection string is exactly the kind of value a configuration field
    // holds, so the binding path is where the truncation would have hurt.
    test('a value containing further "=" reaches the field whole', () {
      final config = TomArgs.fillFromArgs([
        'name=mysql://h/db?user=root',
      ], FixtureServerConfig());
      expect(config.name, 'mysql://h/db?user=root');
    });

    test('returns the same instance it was given', () {
      final config = FixtureServerConfig();
      expect(
        identical(TomArgs.fillFromArgs(['name=svc'], config), config),
        isTrue,
      );
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

    test('an empty quoted value is the empty String', () {
      expect(TomEnvFile.parse(['EMPTY=""'])['EMPTY'], '');
    });

    // The .env path checked both ends but not the length, so a lone quote
    // satisfied startsWith and endsWith at once and aborted the read with a
    // RangeError — a stray quote in a .env file killed server start-up.
    test('a lone quote character is kept verbatim', () {
      expect(TomEnvFile.parse(['K="'])['K'], '"');
      expect(TomEnvFile.parse(["K='"])['K'], "'");
    });

    test('a value with no closing quote is kept verbatim', () {
      expect(TomEnvFile.parse(['K="hello'])['K'], '"hello');
    });

    // The .env path declined `"a b` as unquoted on its own check — both ends
    // had to match — and then handed it to the shared converter, which
    // unquoted on the opening character alone and returned `a `. Getting the
    // check right locally was not enough while the rule lived in two places.
    test('an unterminated quote is not truncated by the shared converter', () {
      expect(TomEnvFile.parse(['K="a b'])['K'], '"a b');
    });

    test('mismatched quotes are kept verbatim', () {
      expect(TomEnvFile.parse(['K="hello\''])['K'], '"hello\'');
    });

    // The stray quote must not take the rest of the file with it.
    test('a stray quote does not stop the remaining lines being read', () {
      final env = TomEnvFile.parse(['BAD="', 'PORT=8080']);
      expect(env['BAD'], '"');
      expect(env['PORT'], 8080);
    });

    // The shapes a long digit run actually takes in a .env file: an account
    // number, a device identifier. Neither is arithmetic, and both used to
    // abort the read.
    test('an oversized digit run arrives as a String', () {
      final env = TomEnvFile.parse([
        'ACCOUNT=99999999999999999999',
        'DEVICE=123456789012345678901234',
      ]);
      expect(env['ACCOUNT'], '99999999999999999999');
      expect(env['DEVICE'], '123456789012345678901234');
    });

    // And it must not take the rest of the file with it either — the failure
    // was one unguarded parse in the shared converter, so every line after the
    // offending one was lost as well.
    test('an oversized value does not stop the remaining lines being read', () {
      final env = TomEnvFile.parse(['BIG=99999999999999999999', 'PORT=8080']);
      expect(env['BIG'], '99999999999999999999');
      expect(env['PORT'], 8080);
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

    // `merge` only addAll's. Dart's covariance lets a Map<String, String> —
    // which is what Platform.environment is — pass as a Map<String, Object?>,
    // so an unconverted source merges without complaint and its values stay
    // strings. This is the trap in the layering idiom: every other source in
    // the stack (read, parse, parseArgsToMap) is already converted, so the
    // environment is the one entry that has to be wrapped by the caller.
    test('does not convert: an unconverted source stays stringly typed', () {
      final merged = TomEnvFile.merge([
        <String, String>{'PORT': '8080'},
      ]);
      expect(merged['PORT'], '8080');
      expect(merged['PORT'], isA<String>());
    });

    test('converting the source first is what types it', () {
      final merged = TomEnvFile.merge([
        TomArgs.convertToObjectMap(<String, String>{'PORT': '8080'}),
      ]);
      expect(merged['PORT'], 8080);
    });
  });

  // The module documents a layering idiom — environment, then .env, then argv,
  // later winning — and the value of documenting it is that it can be pasted.
  // These two tests are what make that true: the wrapped form reaches the
  // fields, and the unwrapped form fails loudly rather than subtly, so a reader
  // who drops the wrap learns it immediately.
  group('layering the sources onto a reflected configuration', () {
    Map<String, Object?> layer(
      Map<String, String> environment,
      List<String> args,
    ) => TomEnvFile.merge([
      TomArgs.convertToObjectMap(environment),
      TomArgs.parseArgsToMap(args),
    ]);

    test('a converted environment fills typed fields, argv winning', () {
      final config = FixtureServerConfig();
      tomReflectionInfo.setValues<FixtureServerConfig>(
        config,
        layer(
          {'name': 'from-env', 'port': '8080', 'verbose': 'true'},
          ['port=9090'],
        ),
      );
      expect(config.name, 'from-env');
      expect(config.verbose, isTrue);
      // The later source wins, and it arrives as an int either way.
      expect(config.port, 9090);
    });

    test('an unconverted environment is rejected by the reflector', () {
      final config = FixtureServerConfig();
      expect(
        () => tomReflectionInfo.setValues<FixtureServerConfig>(
          config,
          TomEnvFile.merge([
            <String, String>{'port': '8080'},
          ]),
        ),
        throwsA(isA<TomReflectorException>()),
      );
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
