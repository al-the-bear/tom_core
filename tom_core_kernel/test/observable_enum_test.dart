/// Tests for [TomObservableEnum] — the observable enum cell whose display
/// text is resolved from the text resource bundle.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Enum under test. Its resource segment is its lower-cased type name,
/// `todostatus`.
enum TodoStatus { open, inReview, done }

/// Second enum, used to prove keys are namespaced per enum type.
enum TodoPriority { low, high }

/// An enum that overrides `toString`, so its segment cannot be inferred, and
/// declares one explicitly. The declared segment is deliberately *not* the
/// lower-cased type name, so a test asserting `shipping` proves the interface
/// is what supplied it.
enum ShippingState implements TomEnumResourceSegment {
  pending,
  shipped;

  @override
  String get resourceSegment => 'Shipping';

  @override
  String toString() => 'ShippingState<$name>';
}

/// An enum that overrides `toString` and declares nothing — the segment is
/// underivable and resolution must say so rather than guess.
enum LegacyFlag {
  on,
  off;

  @override
  String toString() => 'flag:$name';
}

/// Captures log records instead of printing them.
class _RecordingLogOutput extends TomLogOutput {
  final List<String> messages = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    messages.add(convertToString(message));
  }
}

/// English bundle: every [TodoStatus] value plus one [TodoPriority] value.
Map<String, dynamic> englishBundle() => {
  'global': {
    'todostatus': {'open': 'Open', 'inreview': 'In review', 'done': 'Done'},
    'todopriority': {'high': 'High'},
  },
};

/// German bundle: the same keys, different text.
Map<String, dynamic> germanBundle() => {
  'global': {
    'todostatus': {
      'open': 'Offen',
      'inreview': 'In Prüfung',
      'done': 'Erledigt',
    },
  },
};

/// The missing-label warnings [recorder] has seen, excluding the message that
/// announces the warnings have been cut off.
Iterable<String> missingLabelWarnings(_RecordingLogOutput recorder) =>
    recorder.messages.where((m) => m.contains('No enum label resource'));

/// Installs [bundle] as the application-wide text resources.
void installBundle(Map<String, dynamic> bundle) {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(bundle),
  );
}

void main() {
  setUp(() => installBundle(englishBundle()));

  // ===========================================================================
  // Key construction
  // ===========================================================================
  group('TomObservableEnum key construction', () {
    test('builds the global key from the lower-cased enum type and value', () {
      expect(
        TomObservableEnum.resourceKeysFor(TodoStatus.inReview),
        equals(['global.todostatus.inreview']),
      );
    });

    test('namespaces keys per enum type', () {
      expect(
        TomObservableEnum.resourceKeysFor(TodoPriority.high),
        equals(['global.todopriority.high']),
      );
    });

    test('walks the ambient scope chain from most to least specific', () {
      TomScope.withScope('app', () {
        TomScope.withScope('checkout', () {
          expect(
            TomObservableEnum.resourceKeysFor(TodoStatus.open),
            equals([
              'app.checkout.todostatus.open',
              'app.todostatus.open',
              'global.todostatus.open',
            ]),
          );
        });
      });
    });

    test('does not duplicate the global key when the scope is "global"', () {
      TomScope.withScope('global', () {
        expect(
          TomObservableEnum.resourceKeysFor(TodoStatus.open),
          equals(['global.todostatus.open']),
        );
      });
    });

    test('captures the scope at construction, not at display time', () {
      late TomObservableEnum<TodoStatus> cell;
      TomScope.withScope('checkout', () {
        cell = TomObservableEnum(TodoStatus.open, values: TodoStatus.values);
      });
      // Read outside the constructing zone — as a Flutter builder callback would.
      expect(cell.scope.getScopePath(), equals('checkout'));
      expect(
        TomObservableEnum.resourceKeysFor(TodoStatus.open, scope: cell.scope),
        equals(['checkout.todostatus.open', 'global.todostatus.open']),
      );
    });
  });

  // ===========================================================================
  // Segment stability
  // ===========================================================================
  group('TomObservableEnum segment stability', () {
    test('derives the segment from toString(), not runtimeType', () {
      // The two agree in a debug build, which is exactly why this has to be
      // asserted against the string rather than left to inspection: only
      // toString() carries the declared name through a minifying compile,
      // where runtimeType reads as the rewritten class name.
      const value = TodoStatus.inReview;
      final declaredName = value.toString().split('.').first;
      expect(
        TomObservableEnum.enumTypeSegment(value),
        equals(declaredName.toLowerCase()),
      );
      expect(TomObservableEnum.enumTypeSegment(value), equals('todostatus'));
    });

    test('an enum may declare its segment through TomEnumResourceSegment', () {
      // 'shipping', not 'shippingstate' — so the value can only have come from
      // resourceSegment.
      expect(
        TomObservableEnum.enumTypeSegment(ShippingState.shipped),
        equals('shipping'),
      );
      expect(
        TomObservableEnum.resourceKeysFor(ShippingState.shipped),
        equals(['global.shipping.shipped']),
      );
    });

    test('a declared segment resolves text like any other', () {
      installBundle({
        'global': {
          'shipping': {'shipped': 'On its way'},
        },
      });
      final state = TomObservableEnum(
        ShippingState.shipped,
        values: ShippingState.values,
      );
      expect(state.displayText, equals('On its way'));
      expect(state.displayKey, equals('global.shipping.shipped'));
    });

    test('an enum whose toString is overridden and undeclared is rejected', () {
      // Failing here is the point: it fails identically in every build, so the
      // enum is fixed during development rather than losing its labels only
      // once the release compiler rewrites the type name.
      expect(
        () => TomObservableEnum.enumTypeSegment(LegacyFlag.on),
        throwsA(
          isA<TomObservableException>()
              .having(
                (e) => e.key,
                'key',
                equals('observable.enum_segment.unstable_type_name'),
              )
              .having(
                (e) => e.toString(),
                'message',
                contains('TomEnumResourceSegment'),
              ),
        ),
      );
    });
  });

  // ===========================================================================
  // Permitted values
  // ===========================================================================
  group('TomObservableEnum permitted values', () {
    // `values` is required, so the old self-referential default — a one-element
    // list holding whatever the cell was constructed with — is now impossible
    // to ask for. Omitting it does not compile, which is why there is no test
    // for the omitted case: the compiler is the test.

    test('rejects a set to a value outside the permitted list', () {
      final status = TomObservableEnum(
        TodoStatus.open,
        values: const [TodoStatus.open, TodoStatus.done],
      );
      expect(
        () => status | TodoStatus.inReview,
        throwsA(
          isA<TomObservableException>().having(
            (e) => e.key,
            'key',
            equals('observable.enum_value.not_in_values'),
          ),
        ),
      );
      // The rejected write left the cell alone.
      expect(~status, equals(TodoStatus.open));
      expect(status.displayText, equals('Open'));
    });

    test('the rejection covers every write path, not just the operator', () {
      final status = TomObservableEnum(
        TodoStatus.open,
        values: const [TodoStatus.open],
      );
      expect(
        () => status.set(TodoStatus.done),
        throwsA(isA<TomObservableException>()),
      );
      expect(
        () => status << TodoStatus.done,
        throwsA(isA<TomObservableException>()),
      );
    });

    test('a rejected write notifies nobody', () {
      final status = TomObservableEnum(
        TodoStatus.open,
        values: const [TodoStatus.open, TodoStatus.done],
      );
      var notifications = 0;
      final observer = status >> (_) => notifications++;

      expect(() => status | TodoStatus.inReview, throwsA(anything));
      expect(notifications, isZero);

      status | TodoStatus.done;
      expect(notifications, equals(1));

      status.removeObserver(observer);
    });

    test('rejects an initial value outside the permitted list', () {
      // The shape the old `values` default produced silently: a cell whose own
      // option list does not contain its own value.
      expect(
        () => TomObservableEnum(
          TodoStatus.inReview,
          values: const [TodoStatus.open],
        ),
        throwsA(
          isA<TomObservableException>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('inReview'), contains('open')),
          ),
        ),
      );
    });

    test('a subset is a legitimate option list, and it is enforced', () {
      final status = TomObservableEnum(
        TodoStatus.open,
        values: const [TodoStatus.open, TodoStatus.inReview],
      );
      expect(status.displayTexts, equals(['Open', 'In review']));
      status | TodoStatus.inReview;
      expect(status.displayText, equals('In review'));
      expect(() => status | TodoStatus.done, throwsA(anything));
    });

    test('the option list stays in step with the value', () {
      // The invariant the two gaps broke between them: whatever the cell holds
      // is one of the options it offers.
      final status = TomObservableEnum(
        TodoStatus.open,
        values: TodoStatus.values,
      );
      for (final value in TodoStatus.values) {
        status | value;
        expect(status.values, contains(~status));
        expect(status.displayTexts, contains(status.displayText));
      }
    });
  });

  // ===========================================================================
  // Resolution
  // ===========================================================================
  group('TomObservableEnum resolution', () {
    test('resolves display text from the bundle', () {
      final status = TomObservableEnum(
        TodoStatus.inReview,
        values: TodoStatus.values,
      );
      expect(status.displayText, equals('In review'));
    });

    test('resolves the labels of all values in declaration order', () {
      final status = TomObservableEnum(
        TodoStatus.open,
        values: TodoStatus.values,
      );
      expect(status.displayTexts, equals(['Open', 'In review', 'Done']));
    });

    test('reports the key that resolved', () {
      final status = TomObservableEnum(
        TodoStatus.done,
        values: TodoStatus.values,
      );
      expect(status.displayKey, equals('global.todostatus.done'));
    });

    test('prefers a scoped override over the global key', () {
      installBundle({
        'global': {
          'todostatus': {'open': 'Open'},
        },
        'checkout': {
          'todostatus': {'open': 'Not yet ordered'},
        },
      });
      TomScope.withScope('checkout', () {
        final status = TomObservableEnum(
          TodoStatus.open,
          values: TodoStatus.values,
        );
        expect(status.displayText, equals('Not yet ordered'));
        expect(status.displayKey, equals('checkout.todostatus.open'));
      });
    });

    test('falls back to the global key when the scope has no override', () {
      TomScope.withScope('checkout', () {
        final status = TomObservableEnum(
          TodoStatus.done,
          values: TodoStatus.values,
        );
        expect(status.displayText, equals('Done'));
        expect(status.displayKey, equals('global.todostatus.done'));
      });
    });

    test('follows the value when it is set', () {
      final status = TomObservableEnum(
        TodoStatus.open,
        values: TodoStatus.values,
      );
      expect(status.displayText, equals('Open'));
      status | TodoStatus.done;
      expect(status.displayText, equals('Done'));
    });
  });

  // ===========================================================================
  // Rendering
  // ===========================================================================
  group('TomObservableEnum toString', () {
    // This is the form that appears in every log line and debug inspection of
    // an enum cell, and it is published in
    // `doc/api/api_summary_observable.md`. Asserted exactly, so the
    // documented form cannot drift away from the code.
    test('renders as ~<value name> (<display text>)', () {
      final status = TomObservableEnum(
        TodoStatus.inReview,
        values: TodoStatus.values,
      );

      expect(status.toString(), equals('~inReview (In review)'));
    });

    test('carries both halves: the stable name and the localized label', () {
      final status = TomObservableEnum(
        TodoStatus.done,
        values: TodoStatus.values,
      );
      expect(status.toString(), equals('~done (Done)'));

      // Switching locale changes only the parenthesised half. The bare name is
      // what makes the rendering usable in a log read by someone who does not
      // share the user's language — which is the reason it prints both.
      installBundle(germanBundle());
      expect(status.toString(), equals('~done (Erledigt)'));
    });

    test('a missing label degrades to the raw name, never to blank', () {
      installBundle({
        'global': {
          'todostatus': {'open': 'Open'},
        },
      });
      final status = TomObservableEnum(
        TodoStatus.done,
        values: TodoStatus.values,
      );

      expect(status.toString(), equals('~done (done)'));
    });
  });

  // ===========================================================================
  // Two locales
  // ===========================================================================
  group('TomObservableEnum locales', () {
    test('renders the text of whichever bundle is installed', () {
      final status = TomObservableEnum(
        TodoStatus.inReview,
        values: TodoStatus.values,
      );
      expect(status.displayText, equals('In review'));

      installBundle(germanBundle());
      expect(status.displayText, equals('In Prüfung'));

      installBundle(englishBundle());
      expect(status.displayText, equals('In review'));
    });

    test('notifies observers when the bundle changes, not just the value', () {
      final status = TomObservableEnum(
        TodoStatus.open,
        values: TodoStatus.values,
      );
      final seen = <String>[];
      // Retain the observer — observers are held weakly.
      final observer = status >> (_) => seen.add(status.displayText);

      installBundle(germanBundle());
      expect(seen, equals(['Offen']));

      status | TodoStatus.done;
      expect(seen, equals(['Offen', 'Erledigt']));

      status.removeObserver(observer);
    });

    test('stops reacting to the bundle after detachFromResources', () {
      final status = TomObservableEnum(
        TodoStatus.open,
        values: TodoStatus.values,
      );
      var notifications = 0;
      final observer = status >> (_) => notifications++;

      status.detachFromResources();
      installBundle(germanBundle());
      expect(notifications, isZero);

      // Value changes still notify.
      status | TodoStatus.done;
      expect(notifications, equals(1));

      status.removeObserver(observer);
    });
  });

  // ===========================================================================
  // Missing keys
  // ===========================================================================
  group('TomObservableEnum missing keys', () {
    test('degrades to the raw enum name when no key resolves', () {
      // The English bundle has no 'todopriority.low'.
      final priority = TomObservableEnum(
        TodoPriority.low,
        values: TodoPriority.values,
      );
      expect(priority.displayText, equals('low'));
    });

    test('reports the global key as the one that should be added', () {
      final priority = TomObservableEnum(
        TodoPriority.low,
        values: TodoPriority.values,
      );
      expect(priority.displayKey, equals('global.todopriority.low'));
    });

    test('resolveTextOrNull returns null instead of the fallback', () {
      expect(TomObservableEnum.resolveTextOrNull(TodoPriority.low), isNull);
      expect(
        TomObservableEnum.resolveTextOrNull(TodoPriority.high),
        equals('High'),
      );
    });

    test('degrades per value — present labels still resolve', () {
      final priority = TomObservableEnum(
        TodoPriority.low,
        values: TodoPriority.values,
      );
      expect(priority.displayTexts, equals(['low', 'High']));
    });

    test('warns once per key, and stops after a few hundred distinct keys', () {
      // Scope ids are arbitrary strings, so the number of distinct keys is
      // bounded by the application's scopes, not by its enums — the dedupe set
      // has to have a ceiling or it grows for the life of the process.
      installBundle(englishBundle()); // New revision: clears the dedupe set.
      final recorder = _RecordingLogOutput();
      final previousOutput = tomLog.logOutput;
      tomLog.logOutput = recorder;
      addTearDown(() => tomLog.logOutput = previousOutput);

      // Same key twice: one warning.
      TomObservableEnum.resolveText(TodoPriority.low);
      TomObservableEnum.resolveText(TodoPriority.low);
      expect(missingLabelWarnings(recorder), hasLength(1));

      // 599 further distinct keys, one per scope.
      for (var i = 0; i < 599; i++) {
        TomScope.withScope(
          'scope$i',
          () => TomObservableEnum.resolveText(TodoPriority.low),
        );
      }
      expect(missingLabelWarnings(recorder), hasLength(512));
      expect(
        recorder.messages.where((m) => m.contains('suppressing further')),
        hasLength(1),
      );

      // A new bundle is a new revision — reporting resumes.
      installBundle(germanBundle());
      TomObservableEnum.resolveText(TodoPriority.low);
      expect(missingLabelWarnings(recorder), hasLength(513));
    });

    test('a bundle that adds the key repairs the label without rebuilding', () {
      final priority = TomObservableEnum(
        TodoPriority.low,
        values: TodoPriority.values,
      );
      expect(priority.displayText, equals('low'));

      installBundle({
        'global': {
          'todopriority': {'low': 'Low'},
        },
      });
      expect(priority.displayText, equals('Low'));
    });
  });
}
