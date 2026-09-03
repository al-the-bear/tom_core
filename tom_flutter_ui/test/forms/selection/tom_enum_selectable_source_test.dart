/// Tests for [TomEnumSelectableSource] — enum pickers whose option labels
/// come from the text resource bundle rather than a Dart-side label table.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Enum under test. Its resource segment is its lower-cased type name,
/// `todostatus`.
enum TodoStatus { open, inReview, done }

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// English bundle: a label for every [TodoStatus] value.
Map<String, dynamic> englishBundle() => {
  'global': {
    'todostatus': {'open': 'Open', 'inreview': 'In review', 'done': 'Done'},
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
    TomTextResourceProvider.from(bundle),
  );
}

void main() {
  setUp(() => installBundle(englishBundle()));

  // ===========================================================================
  // Source
  // ===========================================================================
  group('TomEnumSelectableSource', () {
    test('labels every value from the bundle, in declaration order', () async {
      final source = TomEnumSelectableSource(TodoStatus.values);
      final items = await source.getItems();

      expect(items.map((i) => i.value), equals(TodoStatus.values));
      expect(items.map((i) => i.label), equals(['Open', 'In review', 'Done']));
    });

    test('labels a value with no key as its raw enum name', () async {
      installBundle({
        'global': {
          'todostatus': {'open': 'Open'},
        },
      });
      final source = TomEnumSelectableSource(TodoStatus.values);
      final items = await source.getItems();

      expect(items.map((i) => i.label), equals(['Open', 'inReview', 'done']));
      // Degraded options stay selectable.
      expect(items.every((i) => i.enabled), isTrue);
    });

    test('honours the isEnabled predicate', () async {
      final source = TomEnumSelectableSource(
        TodoStatus.values,
        isEnabled: (v) => v != TodoStatus.done,
      );
      final items = await source.getItems();

      expect(
        {for (final i in items) i.value: i.enabled},
        equals({
          TodoStatus.open: true,
          TodoStatus.inReview: true,
          TodoStatus.done: false,
        }),
      );
    });

    test('resolves in the scope captured at construction', () async {
      installBundle({
        'global': {
          'todostatus': {'open': 'Open'},
        },
        'checkout': {
          'todostatus': {'open': 'Not yet ordered'},
        },
      });
      late TomEnumSelectableSource<TodoStatus> source;
      TomScope.withScope('checkout', () {
        source = TomEnumSelectableSource(TodoStatus.values);
      });

      // Read outside the constructing zone — as a Flutter builder would.
      final items = await source.getItems();
      expect(items.first.label, equals('Not yet ordered'));
    });

    test('takes its values and scope from a TomObservableEnum', () async {
      late TomObservableEnum<TodoStatus> cell;
      TomScope.withScope('checkout', () {
        cell = TomObservableEnum(TodoStatus.open, values: TodoStatus.values);
      });
      final source = TomEnumSelectableSource.of(cell);

      expect(source.values, equals(TodoStatus.values));
      expect(source.scope, same(cell.scope));
      expect((await source.getItems()).first.label, equals('Open'));
    });

    test('re-emits relabelled items when the bundle changes', () async {
      final source = TomEnumSelectableSource(TodoStatus.values);
      final emissions = source.itemsStream!.first;

      installBundle(germanBundle());

      expect(
        (await emissions).map((i) => i.label),
        equals(['Offen', 'In Prüfung', 'Erledigt']),
      );
    });
  });

  // ===========================================================================
  // Name-valued source
  // ===========================================================================
  group('TomEnumNameSelectableSource', () {
    test(
      'values each option by its enum name, labelled from the bundle',
      () async {
        final source = TomEnumNameSelectableSource(TodoStatus.values);
        final items = await source.getItems();

        expect(items.map((i) => i.value), equals(['open', 'inReview', 'done']));
        expect(
          items.map((i) => i.label),
          equals(['Open', 'In review', 'Done']),
        );
      },
    );

    test('labels a value with no key as its raw enum name', () async {
      installBundle({
        'global': {
          'todostatus': {'open': 'Open'},
        },
      });
      final source = TomEnumNameSelectableSource(TodoStatus.values);
      final items = await source.getItems();

      expect(items.map((i) => i.label), equals(['Open', 'inReview', 'done']));
      expect(items.every((i) => i.enabled), isTrue);
    });

    test('honours the isEnabled predicate', () async {
      final source = TomEnumNameSelectableSource(
        TodoStatus.values,
        isEnabled: (v) => v != TodoStatus.done,
      );
      final items = await source.getItems();

      expect({
        for (final i in items) i.value: i.enabled,
      }, equals({'open': true, 'inReview': true, 'done': false}));
    });

    test('resolves in the scope captured at construction', () async {
      installBundle({
        'global': {
          'todostatus': {'open': 'Open'},
        },
        'checkout': {
          'todostatus': {'open': 'Not yet ordered'},
        },
      });
      late TomEnumNameSelectableSource<TodoStatus> source;
      TomScope.withScope('checkout', () {
        source = TomEnumNameSelectableSource(TodoStatus.values);
      });

      final items = await source.getItems();
      expect(items.first.label, equals('Not yet ordered'));
    });

    test('re-emits relabelled items when the bundle changes', () async {
      final source = TomEnumNameSelectableSource(TodoStatus.values);
      final emissions = source.itemsStream!.first;

      installBundle(germanBundle());

      final items = await emissions;
      expect(
        items.map((i) => i.label),
        equals(['Offen', 'In Prüfung', 'Erledigt']),
      );
      // Values are names, so a relabel never moves the bound value.
      expect(items.map((i) => i.value), equals(['open', 'inReview', 'done']));
    });
  });

  // ===========================================================================
  // Field wiring
  // ===========================================================================
  group('enum dropdown labels', () {
    testWidgets('renders bundle labels rather than enum names', (tester) async {
      final field = FormFieldFamily.material.enumPickerFor(
        'status',
        TodoStatus.open,
        values: TodoStatus.values,
      );

      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsWidgets);
      expect(find.text('open'), findsNothing);
    });

    testWidgets('renders the other locale when that bundle is installed', (
      tester,
    ) async {
      installBundle(germanBundle());
      final field = FormFieldFamily.material.enumPickerFor(
        'status',
        TodoStatus.open,
        values: TodoStatus.values,
      );

      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      expect(find.text('Offen'), findsWidgets);
      expect(find.text('Open'), findsNothing);
    });

    testWidgets('re-renders on a locale change without the caller rebuilding', (
      tester,
    ) async {
      final field = FormFieldFamily.material.enumPickerFor(
        'status',
        TodoStatus.open,
        values: TodoStatus.values,
      );
      final widget = _wrap(field.widget);

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsWidgets);

      // Switch locale. The caller does not rebuild — the same widget instance
      // is pumped again, only the frame is advanced.
      installBundle(germanBundle());
      await tester.pumpAndSettle();

      expect(find.text('Offen'), findsWidgets);
      expect(find.text('Open'), findsNothing);
    });

    testWidgets('a name-valued dropdown renders labels but holds the name', (
      tester,
    ) async {
      final field = TomFormStringDropdown(
        'status',
        TodoStatus.open.name,
        source: TomEnumNameSelectableSource(TodoStatus.values),
      );

      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsWidgets);
      expect(field.get(), equals('open'));

      installBundle(germanBundle());
      await tester.pumpAndSettle();

      expect(find.text('Offen'), findsWidgets);
      // A relabel must not disturb the stored value.
      expect(field.get(), equals('open'));
    });

    testWidgets('renders the raw enum name for a missing key', (tester) async {
      installBundle({
        'global': {
          'todostatus': {'open': 'Open'},
        },
      });
      final field = FormFieldFamily.material.enumPickerFor(
        'status',
        TodoStatus.done,
        values: TodoStatus.values,
      );

      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      // Degraded, but present and selected — never blank.
      expect(find.text('done'), findsWidgets);
      expect(field.get(), equals(TodoStatus.done));
    });
  });
}
