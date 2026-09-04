import 'dart:io';

import 'package:path/path.dart' as p;
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

    // "First" is only a claim when there is more than one "=" to choose
    // between: for a plain pair, first and last give the same key, so an
    // argument carrying two is what puts the question. `_parseArgs` takes
    // `indexOf("=")` and slices either side of it, so the key is the shortest
    // prefix and everything after that one index is the value.
    //
    // This is the key side of the split; the tests below assert the value side.
    test('the key is the text before the first "=", not before the last', () {
      final m = TomArgs.parseArgsToMap(['key=a=b']);
      expect(m.keys, ['key']); // not 'key=a', and no second entry
      expect(m['key'], 'a=b');
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

    // An empty key names nothing. The .env parser has always skipped such a
    // line, and the two sources are documented as one syntax; on the
    // fillFromArgs path an empty key could never match a field either, so it
    // was only ever dead weight travelling into setValues.
    test('an argument with an empty key is skipped', () {
      expect(TomArgs.parseArgsToMap(['']), isEmpty);
      expect(TomArgs.parseArgsToMap(['=orphan']), isEmpty);
      expect(TomArgs.parseArgsToMap(['=']), isEmpty);
    });

    // Skipped, not fatal: one malformed argument must not cost the launch line
    // the arguments around it, which is the principle the oversized-digit and
    // stray-quote cases settle too.
    test('an empty key does not displace the arguments around it', () {
      final m = TomArgs.parseArgsToMap(['name=svc', '=orphan', 'port=8080']);
      expect(m, {'name': 'svc', 'port': 8080});
    });

    test('agrees with TomEnvFile.parse on an empty key', () {
      for (final line in ['', '=orphan', '=']) {
        expect(
          TomArgs.parseArgsToMap([line]),
          TomEnvFile.parse([line]),
          reason: 'the two parsers differ on "$line"',
        );
      }
    });

    // The two parsers are documented as sharing one syntax, so the same text
    // has to mean the same thing whether it arrives on the command line or
    // from a .env file. This is the guarantee that regressed.
    //
    // The expected map is named rather than left implicit. Comparing the two
    // parsers to each other only asserts that they agree, and duplicated logic
    // regresses in both copies at once — a shared move to `lastIndexOf` would
    // keep them in perfect agreement about the wrong answer. Naming the result
    // makes this a test of the rule as well as of the agreement.
    test('agrees with TomEnvFile.parse on where the key ends', () {
      const line = 'url=mysql://h/db?user=root&pw=s3cret';
      const expected = {'url': 'mysql://h/db?user=root&pw=s3cret'};
      expect(TomArgs.parseArgsToMap([line]), expected);
      expect(TomEnvFile.parse([line]), expected);
    });

    // Where the two still part company. Both differences come from
    // `TomEnvFile.parse` trimming and comment-stripping where `_parseArgs`
    // takes the token as given; they are documented as limitations, and these
    // tests are what make a change to either one visible.
    test('differs from TomEnvFile.parse on surrounding whitespace', () {
      const line = ' k = v ';
      expect(TomArgs.parseArgsToMap([line]), {' k ': ' v '});
      expect(TomEnvFile.parse([line]), {'k': 'v'});
    });

    test('differs from TomEnvFile.parse on a "#" inside a value', () {
      const line = 'pw=pa#ss';
      expect(TomArgs.parseArgsToMap([line]), {'pw': 'pa#ss'});
      expect(TomEnvFile.parse([line]), {'pw': 'pa'}); // truncated at the '#'
    });

    // The one place the two conversion tables themselves disagree, rather than
    // the surrounding parse: `TomEnvFile._convertValue` short-circuits an empty
    // value to null before delegating, and `_convertString` has no such branch,
    // so the same text yields a different *type* from each source. The
    // documentation states this as the single exception to "typed the same way
    // from either source", so it is worth a differential test rather than two
    // independent ones that happen to disagree.
    test('differs from TomEnvFile.parse on an empty value', () {
      const line = 'EMPTY=';
      expect(TomArgs.parseArgsToMap([line])['EMPTY'], '');
      expect(TomEnvFile.parse([line])['EMPTY'], isNull);

      // Null as a value, not an absent key — an empty assignment is a key set
      // to nothing, which a caller checking completeness must tell apart from
      // a key no source mentioned.
      expect(TomEnvFile.parse([line]).containsKey('EMPTY'), isTrue);
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

    // A leading zero is only ever written when the zeros carry meaning —
    // nobody writes `port=08080` intending 8080 — so a padded run is an
    // identifier (a phone number, a zero-padded account or article number, a
    // postcode, a country code) and converting it yields a *different*
    // identifier with nothing reporting the change. It is the same rule the
    // magnitude limit follows: the converter produces a type only when it can
    // represent the value faithfully, and `007` -> `7` is not faithful.
    test('leading zeros keep the value a String', () {
      expect(convert('007'), '007');
      expect(convert('004917612345678901'), '004917612345678901');
      expect(convert('01'), '01');
      expect(convert('00'), '00');
    });

    // The one exception, and the reason the rule is about *padding* rather
    // than about a leading zero character: a lone `0` is not a padded value,
    // it is zero written the only way zero can be written.
    test('a lone zero is not padding and still converts', () {
      expect(convert('0'), 0);
      expect(convert('0'), isA<int>());
    });

    // The integer part of a decimal is a digit run too and loses its padding
    // the same way, so the same rule governs it — otherwise the module would
    // have to document one answer for `007` and another for `007.5`. The
    // fractional part is deliberately left alone: a trailing zero after the
    // point is not identity (`1.50` and `1.5` are one quantity), whereas
    // `007` and `7` are two identifiers.
    test('leading zeros in the integer part keep a decimal a String', () {
      expect(convert('00.5'), '00.5');
      expect(convert('007.5'), '007.5');
      expect(convert('0.5'), 0.5);
      expect(convert('1.50'), 1.5);
    });

    // The patterns are unanchored, so `doublePattern` matches the "1.2" prefix
    // of "1.2.3" — but `_convertString` compares the match against the *whole*
    // string, which is what keeps a dotted triple (a version, an IPv4 address)
    // a String. Pinned because the prefix match invites the opposite reading.
    test('a dotted triple keeps the value a String', () {
      expect(convert('1.2.3'), '1.2.3');
      expect(convert('192.168.0.1'), '192.168.0.1');
    });

    // The double shape is `digits . digits*` — zero or more fractional digits,
    // not the "one optional digit" that a `digits?` shorthand suggests. All
    // three counts are pinned here because the shorthand was wrong in the
    // dartdoc and the API mirror for long enough to be worth making
    // unambiguous in the tests.
    test('the fractional part may have zero, one or many digits', () {
      expect(convert('5.'), 5.0);
      expect(convert('5.5'), 5.5);
      expect(convert('5.5678'), 5.5678);
    });

    // The consequence of "zero" that a reader is least likely to predict: a
    // value ending in a bare `.` is not left a String, it becomes a double.
    test('a trailing dot converts rather than keeping the value a String', () {
      expect(convert('5.'), 5.0);
      expect(convert('5.'), isA<double>());
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

    // The dashes are part of the key, and no Dart field can be named `--port`,
    // so the conventional double-dash style is one particular case of "no
    // matching field" — it binds nothing and says nothing. Worth its own test
    // because that style is what a reader is most likely to try first.
    test('a dashed key silently fills nothing', () {
      final config = TomArgs.fillFromArgs([
        '--port=8080',
      ], FixtureServerConfig());
      expect(config.port, 0); // not 8080
      expect(TomArgs.parseArgsToMap(['--port=8080']), {'--port': 8080});
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

    // The sign restriction is not merely "stays a String" once a reflected
    // field is involved: the String is refused at assignment, so a negative
    // setting cannot reach an int field by any route, quoted or not.
    test('a negative value cannot fill an int field', () {
      expect(
        () => TomArgs.fillFromArgs(['port=-5'], FixtureServerConfig()),
        throwsA(isA<TomReflectorException>()),
      );
    });

    test('a decimal value cannot narrow into an int field', () {
      expect(
        () => TomArgs.fillFromArgs(['port=1.5'], FixtureServerConfig()),
        throwsA(isA<TomReflectorException>()),
      );
    });

    // The visible cost of refusing to drop leading zeros, and the reason it is
    // worth paying: `port=08080` is refused at assignment instead of quietly
    // binding 8080, so a deployment that pads a number learns it at start-up
    // rather than never. The same padding on a String field is what the rule
    // exists to protect — the identifier arrives as it was written.
    test('a zero-padded value cannot fill an int field', () {
      expect(
        () => TomArgs.fillFromArgs(['port=08080'], FixtureServerConfig()),
        throwsA(isA<TomReflectorException>()),
      );

      final config = TomArgs.fillFromArgs([
        'name=004917612345678901',
      ], FixtureServerConfig());
      expect(config.name, '004917612345678901');
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

  // `fillFromArgs` and `parseArgsToMap` are one syntax with two return types,
  // and both run through the private `_parseArgs` for that reason. Written as
  // two byte-identical loops they invite exactly one kind of maintenance: a
  // rule such as the first-"=" split or the bare-flag handling gets corrected
  // in one of them.
  //
  // The two tests below guard the two different failure modes that fact has,
  // and neither substitutes for the other. Duplication does not announce itself
  // as disagreement — byte-identical copies agree perfectly, which is exactly
  // why nothing catches them — so only the source-level test sees a
  // re-duplication on the day it happens. The behavioural test sees the
  // consequence that duplication makes possible afterwards: two copies drifting
  // apart, one rule fixed in one of them.
  group('the two entry points are one parse', () {
    /// The fixture's fields, keyed as an argument would name them, with the
    /// initialiser each keeps when no argument mentions it.
    const initialisers = <String, Object?>{
      'name': '',
      'port': 0,
      'rate': 0.0,
      'verbose': false,
    };

    Object? fieldOf(FixtureServerConfig config, String key) => switch (key) {
      'name' => config.name,
      'port' => config.port,
      'rate' => config.rate,
      'verbose' => config.verbose,
      _ => throw ArgumentError('no fixture field named $key'),
    };

    // One case per rule the argument syntax has, restricted to values the
    // declared field type accepts — a rule whose result cannot be assigned
    // (a negative int, say) is put on the String field instead, where the
    // question is still "does the field get what the map got".
    const corpus = <String, List<String>>{
      'a plain pair': ['name=svc', 'port=8080'],
      'a bare flag': ['verbose'],
      'an explicit bool': ['verbose=false'],
      'a value containing a further "="': ['name=a=b'],
      'a quoted value': ['name="my svc"'],
      'an unterminated quote': ['name="my svc'],
      'an empty key between two good arguments': [
        'name=svc',
        '=orphan',
        'port=8080',
      ],
      'a digit run too large for an int': ['name=9223372036854775808'],
      'a negative number': ['name=-5'],
      // On the String field, like the negative number above: a padded run no
      // longer converts, so it is a value the int field cannot accept.
      'leading zeros': ['name=007'],
      'a decimal': ['rate=1.5'],
      'a trailing dot': ['rate=5.'],
      'a whole number on a double field': ['rate=2'],
      'an empty value': ['name='],
      'every field in one pass': [
        'name=svc',
        'port=8080',
        'rate=1.5',
        'verbose',
      ],
    };

    test('every field receives exactly what the map holds for its key', () {
      corpus.forEach((description, args) {
        final map = TomArgs.parseArgsToMap(args);
        final config = TomArgs.fillFromArgs(args, FixtureServerConfig());

        for (final key in initialisers.keys) {
          // A key no argument supplied leaves the field at its initialiser,
          // so the map's silence and the object's default must agree too —
          // that is the half a per-entry-point test tends to leave out.
          final expected = map.containsKey(key) ? map[key] : initialisers[key];
          expect(
            fieldOf(config, key),
            expected,
            reason: '$description: field `$key` disagrees with the map',
          );
        }
      });
    });

    // The defect this guards is invisible to every behavioural test in this
    // file, because a fresh copy of the loop starts out agreeing with the
    // original. It is a maintenance defect, and the source is the only place
    // it is observable on the day it is introduced.
    test('the argument list is walked in exactly one place', () {
      final source = File(
        p.join('lib', 'src', 'tomserver', 'cmdline', 'args.dart'),
      ).readAsStringSync();

      final loops = RegExp(
        r'for\s*\(\s*String\s+\w+\s+in\s+args\s*\)',
      ).allMatches(source).length;

      expect(
        loops,
        1,
        reason:
            'the argument syntax must be implemented once (in `_parseArgs`); '
            'a second loop over `args` is the duplication that made the '
            'first-"=" and bare-flag rules each need fixing twice',
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

    // The first-"=" rule on the .env side. The command-line group asserts the
    // same rule for `TomArgs`; these three are its counterparts, because the
    // two sources are documented as one syntax and a rule stated for both is
    // only tested here if it is tested on both.
    //
    // A line with one "=" cannot put the question — first and last give the
    // same key — so each case below carries a second one that is data.
    test('the key is the text before the first "=", not before the last', () {
      final env = TomEnvFile.parse(['DB_URL=mysql://host/db?user=root']);
      // The key side: exactly one entry, and not 'DB_URL=mysql://host/db?user'.
      expect(env.keys, ['DB_URL']);
      // The value side: the query parameter is part of the URL, not a pair.
      expect(env['DB_URL'], 'mysql://host/db?user=root');
    });

    test('base64 padding is not mistaken for a separator', () {
      expect(TomEnvFile.parse(['SECRET=YWJjZA=='])['SECRET'], 'YWJjZA==');
    });

    test('a value that is only "=" characters is kept', () {
      expect(TomEnvFile.parse(['K==='])['K'], '==');
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

    // The .env counterpart of the padding rule, and the shapes that actually
    // motivate it: a phone number written with its international prefix, a
    // zero-padded article number, a German postcode. All three fit a 64-bit
    // int, so magnitude does not save them — the padding rule does. Written
    // for the .env side as well as the command line because the two sources
    // are documented as one syntax, and a rule stated for both is only tested
    // if it is tested on both.
    test('a zero-padded identifier arrives as a String', () {
      final env = TomEnvFile.parse([
        'PHONE=004917612345678901',
        'ARTICLE=007',
        'POSTCODE=01067',
        'PORT=8080',
      ]);
      expect(env['PHONE'], '004917612345678901');
      expect(env['ARTICLE'], '007');
      expect(env['POSTCODE'], '01067');
      expect(env['PORT'], 8080); // an unpadded number still converts
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

    // Completeness is nobody's job here. A setting no source mentions is simply
    // absent from the merged map — no exception, no marker — so it is
    // indistinguishable from one that was never required, and the field it
    // would have filled keeps its initialiser instead of failing at start-up.
    test('a setting no source supplies is silently absent', () {
      final merged = TomEnvFile.merge([
        {'name': 'svc'},
        {'rate': 1.5},
      ]);
      expect(merged.containsKey('port'), isFalse);

      final config = TomArgs.fillFromArgs(['name=svc'], FixtureServerConfig());
      expect(config.port, 0); // the initialiser, not a reported failure
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

    test('resolveEnvironment lets the .env file win over the process', () async {
      // The precedence question this method exists to answer, and the one that
      // could reasonably have gone the other way: Docker Compose lets the shell
      // win over `.env`. This layering follows TomBaseServerConfiguration
      // .getDefaultValues instead -- OS environment, then `.env` -- so one file
      // means the same thing whether it is read as a config key or expanded
      // into a ${VAR} placeholder.
      final f = File('${dir.path}/.env');
      await f.writeAsString('SHARED=fromFile\nONLY_IN_FILE=yes\n');
      final env = TomEnvFile.resolveEnvironment(
        path: f.path,
        processEnvironment: <String, String>{
          'SHARED': 'fromProcess',
          'ONLY_IN_PROCESS': 'kept',
        },
      );
      expect(env['SHARED'], 'fromFile');
      expect(env['ONLY_IN_FILE'], 'yes');
      // Both directions, because "layered on top" is a claim about each: the
      // file overwrites what it names and leaves what it does not.
      expect(env['ONLY_IN_PROCESS'], 'kept');
    });

    test('resolveEnvironment stringifies the values read typed', () async {
      // read() converts, but substituteEnvVars takes Map<String, String> and
      // writes its expansion back into the tree as text anyway -- so the typing
      // is undone here rather than lost somewhere downstream. A port written as
      // 3307 must arrive as '3307' and not blow up on the covariant cast that
      // Map<String, Object?> would have allowed.
      final f = File('${dir.path}/.env');
      await f.writeAsString('PORT=3307\nDEBUG=true\nRATE=1.5\n');
      final env = TomEnvFile.resolveEnvironment(
        path: f.path,
        processEnvironment: const <String, String>{},
      );
      expect(env['PORT'], '3307');
      expect(env['DEBUG'], 'true');
      expect(env['RATE'], '1.5');
    });

    test('resolveEnvironment drops a key whose .env value is empty', () async {
      // read() maps an empty value to null, which cannot be stringified into a
      // Map<String, String> without inventing something. Dropping is the honest
      // choice *and* the equivalent one: substituteEnvVars treats a present-
      // but-empty value exactly as an absent one, so `${EMPTY:fallback}`
      // resolves to the fallback either way. What the drop does change is that
      // a process-environment value of the same name is no longer shadowed by
      // a blank line in the file.
      final f = File('${dir.path}/.env');
      await f.writeAsString('EMPTY=\nKEPT=x\n');
      final env = TomEnvFile.resolveEnvironment(
        path: f.path,
        processEnvironment: <String, String>{'EMPTY': 'fromProcess'},
      );
      expect(env.containsKey('EMPTY'), isTrue);
      expect(env['EMPTY'], 'fromProcess');
      expect(env['KEPT'], 'x');
    });

    test('resolveEnvironment returns the process environment unchanged '
        'when there is no .env', () async {
      // The default path for anyone who has not copied .env.example: absent
      // file, nothing contributed, no behaviour change. read() returning {}
      // rather than throwing is what makes this a no-op instead of a guard the
      // caller has to write.
      final process = <String, String>{'A': '1', 'B': '2'};
      expect(
        TomEnvFile.resolveEnvironment(
          path: '${dir.path}/.env.absent',
          processEnvironment: process,
        ),
        equals(process),
      );
    });

    test('resolveEnvironment defaults to the real process environment', () async {
      // The no-argument call is the one every boot makes, and it must see the
      // OS environment rather than an empty map -- otherwise a ${VAR} that used
      // to resolve from an exported variable would silently fall back to its
      // default the moment a boot started resolving .env.
      final path = Platform.environment['PATH'];
      expect(path, isNotNull, reason: 'PATH must be set for this test');
      expect(
        TomEnvFile.resolveEnvironment(path: '${dir.path}/.env.absent')['PATH'],
        path,
      );
    });
  });

  group('The example runs green', () {
    final examplePath = p.join('example', 'cmdline', 'cmdline_example.dart');

    test('under exactly the command its header documents', () async {
      // The example is this module's worked demonstration and `doc/cmdline.md`
      // names it as such, so it drifts silently unless something runs it. Run
      // it the way a reader would — plain `dart run`, no extra flags — and
      // require the exit code its own checks produce.
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        examplePath,
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'example failed: ${result.stdout}${result.stderr}',
      );
      // A crash before the last step would also exit 0 if it were swallowed,
      // so pin that every numbered step actually reported.
      //
      // The count comes from the example rather than from a literal here. A
      // literal only ever matches the file on the day it is written: when the
      // example grew from five steps to seven, a hard-coded 5 kept passing and
      // stopped covering the last two — silently, which is the failure this
      // test exists to prevent.
      final declared = RegExp(r"print\('(\d+)\. ")
          .allMatches(File(examplePath).readAsStringSync())
          .map((m) => int.parse(m.group(1)!))
          .toList();
      expect(
        declared,
        List.generate(declared.length, (i) => i + 1),
        reason: 'the example\'s steps must be numbered 1..n without a gap',
      );
      expect(declared, isNotEmpty, reason: 'no numbered step found at all');
      for (final step in declared) {
        expect(result.stdout, contains('$step. '));
      }
    });

    test('with its expectations checked rather than asserted', () async {
      // The test above cannot see the difference on its own: an example that
      // checks nothing exits 0 too. `dart run` leaves assertions disabled —
      // that is what `--enable-asserts` is for — so an `assert` in the example
      // is compiled out under the very command the test above uses, and the run
      // stays green with every expectation violated. This example was written
      // that way, and its eight checks were inert for exactly that reason. It
      // now states its expectations through a throwing helper, and this guards
      // the regression of quietly reverting them to `assert`.
      final source = File(examplePath).readAsStringSync();
      expect(
        source,
        isNot(contains('assert(')),
        reason: 'an assert in the example does not run under `dart run`',
      );
      expect(
        source,
        contains("import '../_support/check.dart'"),
        reason: 'the example states its expectations through the shared helper',
      );
    });

    // The example once ran five steps and reached two of `TomEnvFile`'s five
    // methods; `parse`, `readAsync` and `load` appeared nowhere, and the header
    // explained only the one omission it had thought about. Adding the missing
    // steps fixes that instance. This fixes the class: a method added to
    // `TomEnvFile` tomorrow is either shown or accounted for, and the list is
    // read off the source rather than restated here, so it cannot go stale the
    // way the hard-coded step count above did.
    //
    // Either resolution counts, because the todo's own bar allowed either: a
    // demonstration, or a reason in the header. `load` takes the second route —
    // it is `read` under another name and `doc/cmdline.md` says to prefer
    // `read`, so showing it would recommend what the documentation warns off.
    test('every public TomEnvFile method is shown or explained', () {
      final api = File(
        p.join('lib', 'src', 'tomserver', 'cmdline', 'env_file.dart'),
      ).readAsStringSync();
      final methods = RegExp(r'\n  static\s+[\w<>?,\s]+?\s(\w+)\(')
          .allMatches(api)
          .map((m) => m.group(1)!)
          .where((name) => !name.startsWith('_'))
          .toSet();
      // If this ever empties, the regex has drifted and the test below would
      // pass by vacuum rather than by coverage.
      expect(
        methods,
        containsAll(['read', 'readAsync', 'parse', 'merge', 'load']),
        reason: 'the public method list was not recovered from env_file.dart',
      );

      final example = File(examplePath).readAsStringSync();
      // The header is the part before `library;` — a reason has to be stated
      // where a reader meets it, not buried beside the code that omits it.
      final header = example.substring(0, example.indexOf('library;'));
      for (final method in methods) {
        expect(
          example.contains('TomEnvFile.$method(') || header.contains(method),
          isTrue,
          reason:
              '`TomEnvFile.$method` is neither demonstrated by the example nor '
              'named in its header as a deliberate omission',
        );
      }
    });
  });

  group("The readme's quick start runs green", () {
    // The readme's quick start is a complete `main()` as well, and it is the
    // first artefact a reader of the module meets. Nothing ran it, so it could
    // drift from the conversion rules it advertises without failing anything.
    final readmePath = p.join(
      'lib',
      'src',
      'tomserver',
      'cmdline',
      'readme.md',
    );

    /// Returns the `dart` fenced block under the readme's "Quick start"
    /// heading — the program this module tells a reader to start from.
    String quickStartSource() {
      final lines = File(readmePath).readAsLinesSync();
      final heading = lines.indexWhere((l) => l.trim() == '## Quick start');
      expect(
        heading,
        greaterThanOrEqualTo(0),
        reason: 'no Quick start heading',
      );
      final open = lines.indexWhere((l) => l.trim() == '```dart', heading);
      expect(open, greaterThan(heading), reason: 'no dart block after it');
      final close = lines.indexWhere((l) => l.trim() == '```', open + 1);
      expect(close, greaterThan(open), reason: 'unterminated dart block');
      return lines.sublist(open + 1, close).join('\n');
    }

    test('exactly as written, printing what its comments promise', () async {
      // Written to `.dart_tool/` for two reasons: it is gitignored, so the
      // scratch file cannot be committed by accident, and it is inside the
      // package, so the snippet's `package:tom_core_server` import resolves
      // against the real package_config.json rather than a synthesised one.
      final script = File(
        p.join('.dart_tool', 'cmdline_readme_quick_start.dart'),
      );
      script.writeAsStringSync(quickStartSource());
      addTearDown(() {
        if (script.existsSync()) script.deleteSync();
      });

      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        script.path,
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'quick start failed: ${result.stdout}${result.stderr}',
      );
      // Exit 0 alone would be satisfied by a snippet that printed nothing, so
      // pin the four values the readme's own trailing comments promise. They
      // are the conversion table in miniature — int, String, bool flag — and
      // the empty-map answer for an absent `.env`.
      final out = result.stdout as String;
      expect(out, contains('8080'));
      expect(out, contains('localhost'));
      expect(out.trim().split('\n').map((l) => l.trim()).toList(), [
        '8080',
        'localhost',
        'true',
        'true',
      ]);
    });
  });
}
