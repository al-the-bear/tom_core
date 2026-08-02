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

/// English bundle: every [TodoStatus] value plus one [TodoPriority] value.
Map<String, dynamic> englishBundle() => {
      'global': {
        'todostatus': {
          'open': 'Open',
          'inreview': 'In review',
          'done': 'Done',
        },
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

/// Installs [bundle] as the application-wide text resources.
void installBundle(Map<String, dynamic> bundle) {
  TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(bundle));
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
  // Resolution
  // ===========================================================================
  group('TomObservableEnum resolution', () {
    test('resolves display text from the bundle', () {
      final status = TomObservableEnum(TodoStatus.inReview,
          values: TodoStatus.values);
      expect(status.displayText, equals('In review'));
    });

    test('resolves the labels of all values in declaration order', () {
      final status =
          TomObservableEnum(TodoStatus.open, values: TodoStatus.values);
      expect(status.displayTexts, equals(['Open', 'In review', 'Done']));
    });

    test('reports the key that resolved', () {
      final status =
          TomObservableEnum(TodoStatus.done, values: TodoStatus.values);
      expect(status.displayKey, equals('global.todostatus.done'));
    });

    test('prefers a scoped override over the global key', () {
      installBundle({
        'global': {
          'todostatus': {'open': 'Open'}
        },
        'checkout': {
          'todostatus': {'open': 'Not yet ordered'}
        },
      });
      TomScope.withScope('checkout', () {
        final status =
            TomObservableEnum(TodoStatus.open, values: TodoStatus.values);
        expect(status.displayText, equals('Not yet ordered'));
        expect(status.displayKey, equals('checkout.todostatus.open'));
      });
    });

    test('falls back to the global key when the scope has no override', () {
      TomScope.withScope('checkout', () {
        final status =
            TomObservableEnum(TodoStatus.done, values: TodoStatus.values);
        expect(status.displayText, equals('Done'));
        expect(status.displayKey, equals('global.todostatus.done'));
      });
    });

    test('follows the value when it is set', () {
      final status =
          TomObservableEnum(TodoStatus.open, values: TodoStatus.values);
      expect(status.displayText, equals('Open'));
      status | TodoStatus.done;
      expect(status.displayText, equals('Done'));
    });
  });

  // ===========================================================================
  // Two locales
  // ===========================================================================
  group('TomObservableEnum locales', () {
    test('renders the text of whichever bundle is installed', () {
      final status = TomObservableEnum(TodoStatus.inReview,
          values: TodoStatus.values);
      expect(status.displayText, equals('In review'));

      installBundle(germanBundle());
      expect(status.displayText, equals('In Prüfung'));

      installBundle(englishBundle());
      expect(status.displayText, equals('In review'));
    });

    test('notifies observers when the bundle changes, not just the value', () {
      final status = TomObservableEnum(TodoStatus.open,
          values: TodoStatus.values);
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
      final status =
          TomObservableEnum(TodoStatus.open, values: TodoStatus.values);
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
      final priority =
          TomObservableEnum(TodoPriority.low, values: TodoPriority.values);
      expect(priority.displayText, equals('low'));
    });

    test('reports the global key as the one that should be added', () {
      final priority =
          TomObservableEnum(TodoPriority.low, values: TodoPriority.values);
      expect(priority.displayKey, equals('global.todopriority.low'));
    });

    test('resolveTextOrNull returns null instead of the fallback', () {
      expect(TomObservableEnum.resolveTextOrNull(TodoPriority.low), isNull);
      expect(TomObservableEnum.resolveTextOrNull(TodoPriority.high),
          equals('High'));
    });

    test('degrades per value — present labels still resolve', () {
      final priority =
          TomObservableEnum(TodoPriority.low, values: TodoPriority.values);
      expect(priority.displayTexts, equals(['low', 'High']));
    });

    test('a bundle that adds the key repairs the label without rebuilding', () {
      final priority =
          TomObservableEnum(TodoPriority.low, values: TodoPriority.values);
      expect(priority.displayText, equals('low'));

      installBundle({
        'global': {
          'todopriority': {'low': 'Low'}
        }
      });
      expect(priority.displayText, equals('Low'));
    });
  });
}
