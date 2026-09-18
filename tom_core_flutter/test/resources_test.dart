import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import '../example/resources/resources_example.dart' as example;

/// Tests for the resources module (`TomProperty` and its typed subclasses).
///
/// Each test installs a deterministic config provider, then constructs a
/// property and asserts the value resolved at construction.
///
/// Two groups are not about behaviour but about what the module's documents
/// say. The first holds the four artefacts to the recommendation to prefer a
/// typed subclass *and* its nullable-`T` exception, because unqualified it
/// forbids the one construction an optional property requires. The second
/// holds the API summary to the failures the module actually throws — their
/// wording and their number — because throwing is this module's entire
/// failure contract and both sites fire during construction.
void main() {
  // `Object?`, not `Object`: the config map is a `Map<String, dynamic>` and a
  // null value is a case the module has to answer for (see 'a key configured
  // as null counts as absent'), so the helper has to be able to express it.
  void installConfig(Map<String, Object?> values) {
    TomConfigResourceProvider.setAppConfigProvider(
      TomConfigResourceProvider.from(values),
    );
  }

  setUp(() {
    // Default to an empty config; individual tests override as needed.
    installConfig({});
  });

  group('typed properties resolve their config value', () {
    test('TomStringProperty reads a String', () {
      installConfig({'app.title': 'My App'});
      final p = TomStringProperty('app.title');
      expect(p.get(), 'My App');
      expect(~p, 'My App'); // operator mirrors get()
    });

    test('TomIntProperty reads an int', () {
      installConfig({'app.retries': 3});
      expect(TomIntProperty('app.retries').get(), 3);
    });

    test('TomDoubleProperty reads a double', () {
      installConfig({'app.ratio': 1.5});
      expect(TomDoubleProperty('app.ratio').get(), 1.5);
    });

    test('TomBoolProperty reads a bool', () {
      installConfig({'app.flag': true});
      expect(TomBoolProperty('app.flag').get(), isTrue);
    });
  });

  group('dot notation resolves through nested maps', () {
    // Every other test in this file writes its config as a flat map under a
    // literal dotted key (`{'app.title': …}`), which the provider answers by
    // plain map lookup. That is not the shape a configuration file arrives in:
    // YAML nests, so `app.db.host` reaches the provider as three levels of map
    // and is resolved by a tree walk. The walk and the flat lookup are separate
    // legs of the kernel's resolver — the walk first, the flat lookup only as
    // its fallback — so a suite that exercises one of them says nothing about
    // the other.

    test('all four typed subclasses read a nested leaf', () {
      installConfig({
        'app': <String, dynamic>{
          'db': <String, dynamic>{
            'host': 'localhost',
            'port': 3306,
            'ratio': 1.5,
            'ssl': true,
          },
        },
      });
      expect(TomStringProperty('app.db.host').get(), 'localhost');
      expect(TomIntProperty('app.db.port').get(), 3306);
      expect(TomDoubleProperty('app.db.ratio').get(), 1.5);
      expect(TomBoolProperty('app.db.ssl').get(), isTrue);
    });

    test('a nested value outranks a literal dotted key of the same name', () {
      // Both spellings can be present at once — a nested block from a file,
      // merged with a flat entry written key-by-key — and only one can win.
      // The walk runs first and the flat lookup is its fallback, so the nested
      // value is the answer. Worth pinning because the opposite order is just
      // as plausible a reading of "either a flat entry or a nested one", and
      // nothing else in the suite can tell the two apart.
      installConfig({
        'app': <String, dynamic>{'title': 'from the nested block'},
        'app.title': 'from the flat key',
      });
      expect(TomStringProperty('app.title').get(), 'from the nested block');
    });

    test('a path that stops at an interior node yields the subtree', () {
      // Descent stops at the last segment, so an interior node is a value like
      // any other rather than something only traversed. Holding one needs the
      // generic — no typed subclass closes over `Map` — which is a second
      // reason the four subclasses are a recommendation and not the whole API.
      installConfig({
        'app': <String, dynamic>{
          'db': <String, dynamic>{'host': 'localhost'},
        },
      });
      expect(TomProperty<Map<String, dynamic>>('app.db').get(), {
        'host': 'localhost',
      });
    });

    test('a nested path whose leaf is missing is absent, not an error', () {
      // The walk reaching a real subtree and finding nothing in it is an
      // ordinary miss, and this module cannot tell it from a key that was never
      // written: obligatory fails, `withDefault` falls back. A half-written
      // path is therefore reported the same way as no path at all.
      installConfig({
        'app': <String, dynamic>{'db': <String, dynamic>{}},
      });
      expect(
        () => TomStringProperty('app.db.host'),
        throwsA(
          isA<TomPropertyException>().having(
            (e) => e.key,
            'key',
            'resources.property.not_configured',
          ),
        ),
      );
      expect(
        TomStringProperty.withDefault('app.db.host', 'fallback').get(),
        'fallback',
      );
    });
  });

  group('withDefault', () {
    test('uses the config value when the key exists', () {
      installConfig({'app.retries': 7});
      expect(TomIntProperty.withDefault('app.retries', 5).get(), 7);
    });

    test('falls back to the default when the key is absent', () {
      installConfig({});
      expect(TomIntProperty.withDefault('app.retries', 5).get(), 5);
      expect(
        TomStringProperty.withDefault('app.title', 'Fallback').get(),
        'Fallback',
      );
    });

    // Full-surface: every typed subclass exposes a `withDefault` named
    // constructor. Exercise all four across both branches (present key wins /
    // absent key falls back) so no subclass constructor is left uncovered.
    //
    // Both branches are read twice, once through `get()` and once through `~`.
    // The operator is declared once on the generic, so what the sweep pins is
    // not four implementations but that all four subclasses still *inherit* the
    // one — and that it answers with the resolved value on the fallback branch
    // as well, where there is no configured value for it to return.
    test('all four typed subclasses honour a present config value', () {
      installConfig({
        'app.title': 'Present',
        'app.retries': 9,
        'app.ratio': 2.5,
        'app.flag': true,
      });
      expect(TomStringProperty.withDefault('app.title', 'x').get(), 'Present');
      expect(TomIntProperty.withDefault('app.retries', 0).get(), 9);
      expect(TomDoubleProperty.withDefault('app.ratio', 0.0).get(), 2.5);
      expect(TomBoolProperty.withDefault('app.flag', false).get(), isTrue);

      expect(~TomStringProperty.withDefault('app.title', 'x'), 'Present');
      expect(~TomIntProperty.withDefault('app.retries', 0), 9);
      expect(~TomDoubleProperty.withDefault('app.ratio', 0.0), 2.5);
      expect(~TomBoolProperty.withDefault('app.flag', false), isTrue);
    });

    test('all four typed subclasses fall back when the key is absent', () {
      installConfig({});
      expect(
        TomStringProperty.withDefault('app.title', 'Fallback').get(),
        'Fallback',
      );
      expect(TomIntProperty.withDefault('app.retries', 5).get(), 5);
      expect(TomDoubleProperty.withDefault('app.ratio', 1.25).get(), 1.25);
      expect(TomBoolProperty.withDefault('app.flag', true).get(), isTrue);

      expect(
        ~TomStringProperty.withDefault('app.title', 'Fallback'),
        'Fallback',
      );
      expect(~TomIntProperty.withDefault('app.retries', 5), 5);
      expect(~TomDoubleProperty.withDefault('app.ratio', 1.25), 1.25);
      expect(~TomBoolProperty.withDefault('app.flag', true), isTrue);
    });
  });

  group('type mismatch', () {
    // A key that is present but holds a value of the wrong type fails at
    // construction rather than resolving to anything. The report names both
    // the key and the value that could not be cast, which are the two facts a
    // reader needs to find the offending line in a configuration file.
    test(
      'a present value of the wrong type throws a descriptive Exception',
      () {
        installConfig({'app.title': 'not-an-int'});
        expect(
          () => TomIntProperty('app.title'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              allOf(contains('app.title'), contains('not-an-int')),
            ),
          ),
        );
      },
    );

    test('a default does not rescue a present value of the wrong type', () {
      // The asymmetry a reader is most likely to get wrong: `withDefault`
      // covers an *absent* key, not an unusable one. A wrong-typed value that
      // is present takes the cast branch before the default is ever consulted,
      // so supplying one does not turn a mistyped config entry into a working
      // property — which is right, because a typo'd value and a deliberate
      // omission are different mistakes and only one of them has an intended
      // fallback.
      installConfig({'app.retries': 'not-an-int'});
      expect(
        () => TomIntProperty.withDefault('app.retries', 5),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('app.retries'), contains('not-an-int')),
          ),
        ),
      );
    });

    test('the report carries a matchable code and the cast that failed', () {
      // What a caller can act on. The message is for a human reading a log;
      // `key` is what code matches on, and `rootException` is the only record
      // of what the runtime actually objected to — the module's own message
      // says a cast failed but not which types were involved, because `$T` is
      // the target and the source type appears nowhere.
      installConfig({'app.retries': 'not-an-int'});
      expect(
        () => TomIntProperty('app.retries'),
        throwsA(
          isA<TomPropertyException>()
              .having((e) => e.key, 'key', 'resources.property.type_mismatch')
              .having(
                (e) => e.rootException,
                'rootException',
                isA<TypeError>(),
              ),
        ),
      );
    });

    test('a generic mismatch is diagnosable only through the chained cause', () {
      // The case that makes chaining load-bearing rather than tidy. A scalar
      // mismatch is legible from the message alone -- 'not-an-int' wanted as
      // an int explains itself. A *generic* one is not: a configured
      // `['alpha', 'beta']` decodes as `List<dynamic>` and fails an element
      // check, and the module's message reports `with value [alpha, beta]`,
      // which is exactly what the operator wrote and looks perfectly valid.
      // The reader is told the value is wrong and shown a value that is right.
      //
      // Only the TypeError names the two types, so the assertion below is on
      // `rootException.toString()`, not on the message: were the cause ever
      // summarised away again, the message would still pass every check above
      // and this one would fail.
      installConfig({
        'app.hosts': <dynamic>['alpha', 'beta'],
      });
      expect(
        () => TomProperty<List<String>>('app.hosts'),
        throwsA(
          isA<TomPropertyException>()
              .having((e) => e.key, 'key', 'resources.property.type_mismatch')
              .having(
                (e) => e.defaultUserMessage,
                'message',
                allOf(contains('app.hosts'), contains('[alpha, beta]')),
              )
              .having(
                (e) => e.rootException.toString(),
                'rootException',
                allOf(contains('List<dynamic>'), contains('List<String>')),
              ),
        ),
      );
    });
  });

  group('int to double widening', () {
    // A configuration file cannot say "double". `rate: 2` in YAML and
    // `"rate": 2` in JSON both decode to an int, so a value the operator wrote
    // as a whole number would otherwise fail the `TomDoubleProperty` that is
    // declared for it -- while the reflected path widens the same value onto a
    // declared double field, so one file could fill a field and fail the
    // matching property. `TomConfig` on the server widens identically; the two
    // are read by the same operator writing the same file.

    test('a whole number configured for a double property widens', () {
      installConfig({'app.rate': 2});
      expect(TomDoubleProperty('app.rate').get(), 2.0);
      expect(TomDoubleProperty.withDefault('app.rate', 9.5).get(), 2.0);
      // The generic form as well, since the widening lives on it and the
      // subclass only closes over the type.
      expect(TomProperty<double>('app.rate').get(), 2.0);
    });

    test('a nullable double property widens too', () {
      // `0.0 is double?` is true, so the test the widening makes is satisfied
      // by the nullable form -- which is the form the generic exists for.
      installConfig({'app.rate': 2});
      expect(TomProperty<double?>.withDefault('app.rate', null).get(), 2.0);
    });

    test('the widening does not narrow', () {
      // Deliberately absent, for the reason the reflector gives for not having
      // it either: narrowing needs a rounding policy, and truncating 2.5 loses
      // what the operator wrote. So a fractional value under an int property
      // is still a mismatch, chained cause and all.
      installConfig({'app.retries': 2.5});
      expect(
        () => TomIntProperty('app.retries'),
        throwsA(
          isA<TomPropertyException>().having(
            (e) => e.key,
            'key',
            'resources.property.type_mismatch',
          ),
        ),
      );
    });

    test('a widenable type that already accepts the int keeps it an int', () {
      // Why the widening sits *after* the failed cast rather than in front of
      // it. `0.0 is T` is also true for `num`, `Object` and `dynamic`, where
      // `2 as T` succeeds -- so a check placed first would convert an int the
      // caller asked for as a num into a double. Reached only by a cast that
      // has actually failed, it cannot.
      installConfig({'app.count': 2});
      expect(TomProperty<num>('app.count').get(), isA<int>());
      expect(TomProperty<Object>('app.count').get(), isA<int>());
      expect(TomProperty<dynamic>('app.count').get(), isA<int>());
    });

    test('only an int widens, not any other mistyped value', () {
      // The widening is keyed on the value being an int, so a string that
      // happens to spell a number is still a mismatch: parsing text into a
      // number is a different decision from widening one number to another,
      // and the module does not make it.
      installConfig({'app.rate': '2'});
      expect(
        () => TomDoubleProperty('app.rate'),
        throwsA(
          isA<TomPropertyException>().having(
            (e) => e.key,
            'key',
            'resources.property.type_mismatch',
          ),
        ),
      );
    });
  });

  group('missing obligatory key', () {
    // A property declared without a default is obligatory: an absent key is a
    // failure, not a null. What this pins is that the failure is the module's
    // own descriptive one and that it names the key — a report that says only
    // "not configured" leaves the reader to work out which of a config file's
    // properties is the missing one.
    test(
      'no-default constructor throws the descriptive obligatory-key error',
      () {
        installConfig({});
        expect(
          () => TomStringProperty('app.missing'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              allOf(contains('Obligatory'), contains('app.missing')),
            ),
          ),
        );
      },
    );

    test('a key configured as null counts as absent', () {
      // `getObjectOrNull` returns null both for a key that was never written
      // and for one configured with no value, and the module treats the two
      // alike. Worth pinning because they look different in a YAML file and
      // identical here: `app.region:` with no value does not satisfy an
      // obligatory property.
      //
      // This is the settled contract, not a defect awaiting a fix. There is no
      // third state for a lookup to report — `exists` returns a `bool` and
      // `getObjectOrNull` an `Object?` — and the state the two collapse to is
      // the one an unconfigured key should get anyway. Every accessor on both
      // providers behaves this way, for flat and for dotted paths alike. What a
      // caller who genuinely needs the distinction reaches for is the provider's
      // own map, pinned two tests below.
      installConfig({'app.region': null});
      expect(
        () => TomStringProperty('app.region'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('Obligatory'), contains('app.region')),
          ),
        ),
      );
    });

    test(
      'a key configured as null takes the default rather than staying null',
      () {
        // The other half of the collapse, and the more surprising half: over a
        // nullable `T` a caller can write `null` as a deliberate default, but
        // they cannot write it as a deliberate *value* — a configured `null` is
        // read as no value at all and the fallback wins. So an explicit `null` in
        // the config file can never override a non-null default, whatever the
        // author of that file intended by writing it.
        installConfig({'app.region': null});
        expect(
          TomStringProperty.withDefault('app.region', 'fallback').get(),
          'fallback',
        );
        expect(
          TomProperty<String?>.withDefault('app.region', 'fallback').get(),
          'fallback',
        );

        // Nested spelling, same answer — the collapse is in the resolver, not in
        // the flat-key leg.
        installConfig({
          'app': <String, dynamic>{'region': null},
        });
        expect(
          TomStringProperty.withDefault('app.region', 'fallback').get(),
          'fallback',
        );
      },
    );

    test('the provider map is the recourse when the distinction matters', () {
      // The escape hatch the module itself does not offer. `resources` is
      // public, so a caller who has to tell "explicitly unset" from "never
      // configured" can ask the map directly — which is the whole reason the
      // collapse above is documented rather than worked around here. Pinned
      // because the documents now promise this recourse: if `resources` were
      // made private or lazily materialised, the promise would break silently
      // while every other test in this file still passed.
      installConfig({'app.region': null});
      expect(
        TomConfigResourceProvider.getAppConfig().resources.containsKey(
          'app.region',
        ),
        isTrue,
        reason:
            'a key present with a null value is not visible in the map, so '
            'nothing can distinguish it from one that was never written',
      );

      installConfig({});
      expect(
        TomConfigResourceProvider.getAppConfig().resources.containsKey(
          'app.region',
        ),
        isFalse,
      );
    });

    test('the report carries a matchable code distinct from the cast one', () {
      // Two conditions, one exception type, two codes — the kernel's own
      // resources module is shaped the same way. The distinction matters
      // because the two call for different repairs: an absent key is a
      // configuration file that is missing a line, a mistyped one is a
      // configuration file whose line is wrong.
      installConfig({});
      expect(
        () => TomStringProperty('app.missing'),
        throwsA(
          isA<TomPropertyException>().having(
            (e) => e.key,
            'key',
            'resources.property.not_configured',
          ),
        ),
      );
    });
  });

  group('explicit null default (nullable T)', () {
    // Over a nullable `T`, `null` is a legitimate default rather than the
    // absence of one. The module tracks whether a default was supplied
    // separately from what it is, so `withDefault(key, null)` resolves to null
    // instead of failing as an unconfigured obligatory key — which is what
    // makes the generic the only form that can express an optional property.
    test('withDefault(key, null) returns null when the key is absent', () {
      installConfig({});
      final p = TomProperty<String?>.withDefault('app.missing', null);
      expect(p.get(), isNull);
    });
  });

  group('the documents qualify the subclass recommendation', () {
    // Every artefact tells the reader to prefer a typed subclass, and that
    // advice is right four times out of five. The fifth is the group above:
    // the subclasses close over non-nullable String/int/double/bool, so an
    // optional value can only be written as the generic. A reader who is told
    // the rule but not its exception writes a sentinel default and tests for
    // it, or uses the generic believing they are breaking the contract.
    const artefacts = <String>[
      'lib/src/tomclient/resources/tom_properties.dart',
      'lib/src/tomclient/resources/readme.md',
      'doc/resources.md',
      'doc/api_reference/api_summary_resources.md',
    ];

    /// The three consumer-facing documents — the artefacts a reader who is not
    /// reading the source arrives at.
    const consumerDocs = <String>[
      'lib/src/tomclient/resources/readme.md',
      'doc/resources.md',
      'doc/api_reference/api_summary_resources.md',
    ];

    /// [file]'s text with emphasis and code markers removed, so a document is
    /// free to bold or quote any part of the rule without breaking the check.
    String plainTextOf(String file) =>
        File(file).readAsStringSync().replaceAll(RegExp(r'[*`\[\]]'), '');

    test('every artefact recommends the typed subclasses', () {
      // The recommendation itself is worth pinning: it is the reason the four
      // subclasses exist, and dropping it would make the exception below
      // read as blanket permission to use the generic everywhere.
      for (final artefact in artefacts) {
        expect(
          plainTextOf(artefact),
          contains('subclass'),
          reason:
              '$artefact no longer points the reader at the typed '
              'subclasses, which are the intended form for the four '
              'non-nullable value types',
        );
      }
    });

    test('every artefact states the nullable-T exception to it', () {
      // The half that is easy to leave out, because the four subclasses cover
      // every case their author had in mind. Unqualified, the recommendation
      // forbids the only construction that expresses an optional value.
      for (final artefact in artefacts) {
        expect(
          plainTextOf(artefact),
          contains('nullable'),
          reason:
              '$artefact states the subclass recommendation without its '
              'exception, so a reader who needs an optional property is told '
              'their only correct option is the one to avoid',
        );
      }
    });

    test('the construction no subclass can express is shown, and runs as '
        'shown', () {
      // A qualification without the construction beside it leaves the reader
      // knowing an exception exists but not how to write it, so each document
      // has to show it — and then the snippet it shows is run here, against
      // the key the documents themselves use. That is the link to behaviour:
      // not a text match between documents, but the printed line executing.
      const construction = 'TomProperty<String?>.withDefault(';
      for (final doc in consumerDocs) {
        expect(
          plainTextOf(doc),
          contains(construction),
          reason:
              '$doc names the nullable-T exception but does not show it; '
              'the qualification is only actionable with the construction '
              'beside it',
        );
      }

      installConfig({});
      final region = TomProperty<String?>.withDefault('app.region', null);
      expect(
        region.get(),
        isNull,
        reason:
            'the documents print this construction as the way to hold an '
            'optional value; it no longer yields the absent value',
      );
    });
  });

  group('the documented failures are the ones the module throws', () {
    // Throwing is this module's whole failure contract: both constructors
    // resolve in their body, so the two throw sites are not error paths
    // reached after a successful construction — they are the two ways
    // construction fails, at whatever point in start-up the property is built.
    // A summary that omits them leaves the reader with neither the exception
    // type, the message shape, nor the fact that a wrong-typed *present* value
    // fails as hard as a missing one.
    const source = 'lib/src/tomclient/resources/tom_properties.dart';
    const summary = 'doc/api_reference/api_summary_resources.md';

    /// The message of every `TomPropertyException` thrown in [source] — the
    /// second constructor argument, the first being the matchable `key`.
    ///
    /// Requires each message to be a single literal on one line, which is the
    /// point: a message split across adjacent literals is one string in the
    /// log and several in the source, so the search that finds it in one does
    /// not find it in the other.
    List<String> thrownMessagesOf(String file) => RegExp(
      '''throw TomPropertyException\\(\\s*'[^']*',\\s*"([^"]*)"''',
    ).allMatches(File(file).readAsStringSync()).map((m) => m[1]!).toList();

    /// [text] with runs of whitespace collapsed, so a document may re-wrap a
    /// long line without breaking a match. Code and emphasis markers go too,
    /// leaving the words themselves.
    String flattened(String text) => text
        .replaceAll(RegExp(r'[*`\[\]]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    /// The body of [heading] in [file], up to the next `## `.
    String sectionOf(String file, String heading) {
      final text = File(file).readAsStringSync();
      final start = text.indexOf('\n## $heading\n');
      if (start < 0) return '';
      var rest = text.substring(start + heading.length + 5);
      final next = RegExp(r'^## ', multiLine: true).firstMatch(rest);
      return next == null ? rest : rest.substring(0, next.start);
    }

    test('the summary quotes the message shape each throw site produces', () {
      // Matches the fixed fragments *around* the interpolations rather than
      // whole sentences, so the summary is free to write the holes however
      // reads best (`<key>`, `<T>`) while the words a reader would grep a log
      // for stay tied to the source. Reword the throw and this fails.
      final summaryText = flattened(File(summary).readAsStringSync());
      final messages = thrownMessagesOf(source);
      var checked = 0;
      for (final message in messages) {
        for (final fragment in message.split(RegExp(r'\$\{[^}]*\}|\$\w+'))) {
          if (fragment.trim().length < 4) continue; // a gap between two holes
          checked++;
          expect(
            summaryText,
            contains(flattened(fragment)),
            reason:
                '$summary does not carry the wording of a message this '
                'module throws, so a reader who greps their log for it finds '
                'nothing:\n  $message',
          );
        }
      }
      // Vacuous if the throw sites stop being recognised as such.
      expect(checked, greaterThanOrEqualTo(4));
    });

    test('every throw site has a row in the Exceptions section', () {
      // The count, not the wording: a third failure added to `_getValue` is
      // exactly the change that would otherwise leave this section quietly
      // describing two of three.
      final rows = sectionOf(summary, 'Exceptions')
          .split('\n')
          .where((l) => l.startsWith('| ') && !l.startsWith('| ---'))
          .length;
      expect(
        rows - 1, // the header row
        thrownMessagesOf(source).length,
        reason:
            '$summary documents a different number of failures than '
            '$source throws',
      );
    });
  });

  group('resolution reads the provider once', () {
    // How many times a property resolves its key is a contract, not an
    // implementation detail: a provider may be backed by something more
    // expensive and less reliable than a map, and every extra read is another
    // chance to be slow or to fail. `getObjectOrNull` answers "present, and
    // this is the value" in one lookup, so presence and value never need two.

    test('a successful resolution performs one read', () {
      final provider = _CountingConfigProvider({'app.title': 'My App'});
      TomConfigResourceProvider.setAppConfigProvider(provider);
      expect(TomStringProperty('app.title').get(), 'My App');
      expect(
        provider.reads,
        1,
        reason: 'resolving one key looked the store up more than once',
      );
    });

    test('an absent key falling back to its default performs one read', () {
      final provider = _CountingConfigProvider({});
      TomConfigResourceProvider.setAppConfigProvider(provider);
      expect(TomIntProperty.withDefault('app.retries', 5).get(), 5);
      expect(provider.reads, 1);
    });

    test('a failed cast does not read the value again to describe itself', () {
      // The failure path is where a redundant read is least affordable: the
      // premise of being there is that the store already answered.
      final provider = _CountingConfigProvider({'app.retries': 'not-an-int'});
      TomConfigResourceProvider.setAppConfigProvider(provider);
      expect(
        () => TomIntProperty('app.retries'),
        throwsA(isA<TomPropertyException>()),
      );
      expect(
        provider.reads,
        1,
        reason:
            'the type-mismatch report read the store again to quote the '
            'value it had already been given',
      );
    });
  });

  group('a property is a snapshot, and the ordering that implies', () {
    // The module's central constraint, and the one a caller can get wrong
    // without anything saying so: a property is the value config held at the
    // moment it was built, not a view of config. Configuration is installed at
    // bootstrap and captured by its consumers when they are built, which is
    // why the kernel's config provider announces nothing when it is replaced
    // (`TomConfigResourceProvider.setAppConfigProvider`) — a counter would
    // notify a value that has already been taken.
    //
    // Half of the constraint is enforced and half is not, and the difference
    // is what these tests are for.

    test('a property built before any configuration fails loudly', () {
      // The enforced half. "Construct the property after the config providers
      // are populated" is not advice a caller can quietly ignore: with nothing
      // installed the provider refuses the lookup, and the property's
      // construction — not some later read — is where that surfaces.
      TomConfigResourceProvider.clearAppConfigProvider();
      addTearDown(() => installConfig({}));

      expect(
        () => TomStringProperty('app.title'),
        throwsA(
          isA<TomResourceException>().having(
            (error) => error.key,
            'key',
            'resources.config_provider.not_installed',
          ),
        ),
      );
    });

    test('replacing the configuration leaves a built property untouched', () {
      // The unenforced half, and the one worth having a test for: nothing
      // detects this, by design, so the only thing standing between the
      // documented behaviour and a silent change to it is this assertion.
      installConfig({'app.title': 'First'});
      final title = TomStringProperty('app.title');

      installConfig({'app.title': 'Second'});

      expect(
        title.get(),
        'First',
        reason: 'a property re-read config after construction',
      );
    });

    test('a property built after the replacement reads the new one', () {
      // What makes the assertion above mean something. Without it, a test
      // showing the old value survives a provider that was never installed —
      // and would pass just as well against a replacement that silently did
      // nothing.
      installConfig({'app.title': 'First'});
      final before = TomStringProperty('app.title');

      installConfig({'app.title': 'Second'});
      final after = TomStringProperty('app.title');

      expect(before.get(), 'First');
      expect(after.get(), 'Second');
    });

    test('a default already taken survives the key arriving later', () {
      // The same rule on the fallback path, where it is easier to expect
      // otherwise: a default is not a placeholder consulted until config turns
      // up. It was the resolution.
      installConfig({});
      final retries = TomIntProperty.withDefault('app.retries', 5);

      installConfig({'app.retries': 9});

      expect(retries.get(), 5);
      expect(TomIntProperty.withDefault('app.retries', 5).get(), 9);
    });
  });

  group('the documents state the snapshot constraint', () {
    // The constraint is a decision, not an implementation detail, so every
    // artefact a reader arrives at has to carry it — and carry the part that
    // is actionable. "Eager" alone describes when the read happens; what a
    // caller needs is the consequence (a later config change is not reflected)
    // and the obligation it creates (build properties after the providers are
    // populated).
    const artefacts = <String>[
      'lib/src/tomclient/resources/tom_properties.dart',
      'lib/src/tomclient/resources/readme.md',
      'doc/resources.md',
      'doc/api_reference/api_summary_resources.md',
    ];

    /// [file]'s text with markdown emphasis, code markers, link brackets,
    /// blockquote markers and line breaks flattened to spaces, so a document is
    /// free to bold the rule, quote it in a callout or wrap it anywhere.
    String plainTextOf(String file) => File(file)
        .readAsStringSync()
        .replaceAll(RegExp(r'[*`\[\]>]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    test('every artefact states that a later config change is not seen', () {
      for (final artefact in artefacts) {
        expect(
          plainTextOf(artefact),
          contains('not reflected'),
          reason:
              '$artefact no longer tells the reader that a config change '
              'after construction does not reach a built property',
        );
      }
    });

    test('every artefact states the ordering it obliges', () {
      // The half that turns the statement into something a caller can act on.
      // Knowing a property is a snapshot is only useful alongside "so build it
      // after the providers are populated".
      for (final artefact in artefacts) {
        expect(
          plainTextOf(artefact),
          contains(RegExp(r'after the config(uration)? provider')),
          reason:
              '$artefact describes the property as eager without saying what '
              'a caller must therefore do',
        );
      }
    });
  });

  group('the failure report survives a config source that can fail', () {
    test('a lookup that fails is not reported as a type mismatch', () {
      // The report says a value could not be cast. Only a failed cast is
      // evidence of that, so only a failed cast may produce it — a lookup that
      // never returned a value diagnosed nothing, and dressing it as a type
      // error sends the reader to audit type declarations for a fault that is
      // in the config source. Keeping the read outside the `try`, and the
      // `try` down to the single cast, is what makes that true structurally
      // rather than by care.
      TomConfigResourceProvider.setAppConfigProvider(_UnreadableProvider());
      expect(() => TomStringProperty('app.title'), throwsA(isA<StateError>()));
    });

    test('a second read failing does not replace the type-mismatch report', () {
      // A map-backed provider always answers, so a description built by
      // reading the value a second time looks harmless. A provider over a
      // file, a remote store or a lazily-decrypted bundle does not have that
      // property — and the read that fails is on the failure path, where its
      // exception replaces the diagnosis the caller was about to receive. The
      // fix is not to retry more carefully but to not read again at all: the
      // value is already in hand.
      TomConfigResourceProvider.setAppConfigProvider(
        _FailsAfterFirstReadProvider(),
      );
      expect(
        () => TomIntProperty('app.retries'),
        throwsA(
          isA<TomPropertyException>().having(
            (e) => e.key,
            'key',
            'resources.property.type_mismatch',
          ),
        ),
      );
    });
  });

  group('the shipped example runs', () {
    test('resources_example.run() completes its assertions', () {
      // The example is quoted as documentation, so it has to be executable
      // documentation. Running it here is what stops a snippet that no longer
      // compiles — or an assert that no longer holds — from being shown to a
      // reader as the way to use the module. It is also what makes the command
      // the example's header names a real one: that command is this suite.
      //
      // run() installs its own app config provider process-wide and does not
      // restore it — correct for an example, which owns the process, but this
      // suite does not, so the empty default is put back explicitly rather than
      // left to the next setUp to overwrite.
      addTearDown(() => installConfig({}));
      example.run();
    });
  });
}

/// A config provider that counts every lookup made through it.
///
/// Counts all three accessors together, because they are three ways of asking
/// the same store the same question: a resolution that calls two of them has
/// resolved the key twice regardless of which two.
class _CountingConfigProvider extends TomConfigResourceProvider {
  _CountingConfigProvider(Map<String, dynamic> values) : super.from(values);

  /// Lookups performed since construction.
  int reads = 0;

  @override
  bool exists(String s) {
    reads++;
    return super.exists(s);
  }

  @override
  Object getObject(String s) {
    reads++;
    return super.getObject(s);
  }

  @override
  Object? getObjectOrNull(String s) {
    reads++;
    return super.getObjectOrNull(s);
  }
}

/// A config provider whose every lookup fails.
///
/// Stands in for a configuration source that is unreachable rather than empty
/// — the case in which "the value could not be cast" is not merely unhelpful
/// but untrue.
class _UnreadableProvider extends TomConfigResourceProvider {
  _UnreadableProvider() : super.from({});

  @override
  bool exists(String s) => throw StateError('configuration is unreadable');

  @override
  Object getObject(String s) => throw StateError('configuration is unreadable');

  @override
  Object? getObjectOrNull(String s) =>
      throw StateError('configuration is unreadable');
}

/// A config provider that answers its first lookup and fails every one after.
///
/// Stands in for a configuration source that is not a map in memory — one
/// backed by a file handle, a remote store or a cache with a lifetime. Such a
/// source can succeed once and fail immediately afterwards, which is exactly
/// what makes a second read on the failure path dangerous rather than merely
/// wasteful.
class _FailsAfterFirstReadProvider extends TomConfigResourceProvider {
  _FailsAfterFirstReadProvider() : super.from({'app.retries': 'not-an-int'});

  int _reads = 0;

  Object? _read(String s) {
    if (_reads++ > 0) throw StateError('configuration source is gone');
    return super.getObjectOrNull(s);
  }

  @override
  Object getObject(String s) => _read(s) ?? s;

  @override
  Object? getObjectOrNull(String s) => _read(s);
}
