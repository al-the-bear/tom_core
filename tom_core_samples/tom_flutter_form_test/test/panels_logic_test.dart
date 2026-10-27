/// Unit tests for the pure mapping logic in the two debug *panels*. Nothing
/// else covers them directly: they are only transitively mounted inside the
/// demo screens, whose tests assert form behaviour, not panel behaviour.
/// Covered here:
///
///   * `eventCategoryOf` (lifted from `EventLogPanel._categoryOf`) — the
///     event-type → `EventCategory` mapping that drives the filter chips. A
///     misclassified event type would pass every existing demo test.
///   * `fieldRowColour` / `fieldValidationLabel` / `fieldAuthLabel` (lifted
///     from `FieldStateTable`'s private statics) — the auth/validation →
///     colour-and-label mapping. A swapped validation colour would likewise
///     slip through.
///
/// The pure mappings are pinned as plain `test()`s. The `EventLogPanel`
/// filter/clear/auto-scroll pipeline — inherently stateful widget behaviour —
/// is pinned with a `testWidgets` case that toggles a filter chip and clears
/// the log, asserting the visible event count.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/panels/event_log_panel.dart';
import 'package:tom_flutter_form_test/panels/field_state_table.dart';

void main() {
  group('eventCategoryOf — event type → filter category', () {
    test('a value change maps to value', () {
      expect(
        eventCategoryOf(TomFieldValueChangedEvent(source: 'f', newValue: 'x')),
        EventCategory.value,
      );
    });

    test('field and form validation both map to validation', () {
      expect(
        eventCategoryOf(
          TomFieldValidatedEvent(
            source: 'f',
            result: const TomValidationSuccess(),
          ),
        ),
        EventCategory.validation,
      );
      expect(
        eventCategoryOf(TomFormValidatedEvent(source: 'f', errors: const [])),
        EventCategory.validation,
      );
    });

    test('an effective-auth change maps to auth', () {
      expect(
        eventCategoryOf(
          TomFieldAuthChangedEvent(
            source: 'f',
            oldState: TomAuthState.full,
            newState: TomAuthState.read,
          ),
        ),
        EventCategory.auth,
      );
    });

    test(
      'everything else (bind/commit/save/discard/list) maps to lifecycle',
      () {
        expect(
          eventCategoryOf(TomFieldBoundEvent(source: 'f')),
          EventCategory.lifecycle,
        );
        expect(
          eventCategoryOf(TomFieldCommittedEvent(source: 'f')),
          EventCategory.lifecycle,
        );
        expect(
          eventCategoryOf(TomFormBoundEvent(source: 'f')),
          EventCategory.lifecycle,
        );
        expect(
          eventCategoryOf(TomFormSavedEvent(source: 'f')),
          EventCategory.lifecycle,
        );
        expect(
          eventCategoryOf(TomFormDiscardedEvent(source: 'f')),
          EventCategory.lifecycle,
        );
        expect(
          eventCategoryOf(
            TomListItemAddedEvent(source: 'f', index: 0, itemFormId: 'i0'),
          ),
          EventCategory.lifecycle,
        );
      },
    );
  });

  group('fieldAuthLabel — auth state → label', () {
    test('each auth state maps to its short label', () {
      expect(fieldAuthLabel(TomAuthState.full), 'full');
      expect(fieldAuthLabel(TomAuthState.read), 'read');
      expect(fieldAuthLabel(TomAuthState.disabled), 'disabled');
      expect(fieldAuthLabel(TomAuthState.none), 'none');
    });
  });

  group('fieldValidationLabel — validation result → label', () {
    test('each validation variant maps to its label', () {
      expect(fieldValidationLabel(const TomValidationPristine()), 'pristine');
      expect(fieldValidationLabel(const TomValidationSuccess()), 'valid');
      expect(fieldValidationLabel(const TomValidationPending()), 'pending');
      expect(
        fieldValidationLabel(const TomValidationError('minRequired')),
        'error: minRequired',
      );
    });
  });

  group('fieldRowColour — auth/validation → row colour', () {
    final theme = ThemeData();

    test('a disabled auth state greys the row regardless of validation', () {
      // Even a *successful* validation is overridden by disabled auth.
      expect(
        fieldRowColour(
          theme,
          TomAuthState.disabled,
          const TomValidationSuccess(),
        ),
        theme.colorScheme.surfaceContainer,
      );
    });

    test('a none auth state greys the row regardless of validation', () {
      expect(
        fieldRowColour(theme, TomAuthState.none, const TomValidationError('x')),
        theme.colorScheme.surfaceContainerLow,
      );
    });

    test('with full auth the validation state drives the colour', () {
      expect(
        fieldRowColour(theme, TomAuthState.full, const TomValidationError('x')),
        theme.colorScheme.errorContainer.withValues(alpha: 0.4),
      );
      expect(
        fieldRowColour(theme, TomAuthState.full, const TomValidationPending()),
        Colors.amber.withValues(alpha: 0.25),
      );
      expect(
        fieldRowColour(theme, TomAuthState.full, const TomValidationSuccess()),
        Colors.green.withValues(alpha: 0.12),
      );
      expect(
        fieldRowColour(theme, TomAuthState.full, const TomValidationPristine()),
        theme.colorScheme.surface,
      );
    });

    test('read auth is not greyed — validation still drives the colour', () {
      // read != disabled/none, so it falls through to the validation switch.
      expect(
        fieldRowColour(theme, TomAuthState.read, const TomValidationSuccess()),
        Colors.green.withValues(alpha: 0.12),
      );
    });
  });

  group('EventLogPanel — filter / clear pipeline', () {
    Future<TomFormInspector> pumpPanel(WidgetTester tester) async {
      final inspector = TomFormInspector()
        ..onFieldValueChanged(
          TomFieldValueChangedEvent(source: 'a', newValue: '1'),
        )
        ..onFormValidated(TomFormValidatedEvent(source: 'f', errors: const []))
        ..onFieldAuthChanged(
          TomFieldAuthChangedEvent(
            source: 'a',
            oldState: TomAuthState.full,
            newState: TomAuthState.read,
          ),
        )
        ..onFormBound(TomFormBoundEvent(source: 'f'));
      final rebuildOn = ValueNotifier<int>(0);
      addTearDown(rebuildOn.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventLogPanel(inspector: inspector, rebuildOn: rebuildOn),
          ),
        ),
      );
      return inspector;
    }

    testWidgets('shows all events initially (one per category)', (
      tester,
    ) async {
      await pumpPanel(tester);
      expect(find.text('4 / 4 events'), findsOneWidget);
    });

    testWidgets('deselecting a filter chip hides that category', (
      tester,
    ) async {
      await pumpPanel(tester);
      // Toggle off the "value" chip — the single value event drops out.
      await tester.tap(find.widgetWithText(FilterChip, 'value'));
      await tester.pumpAndSettle();
      expect(find.text('3 / 4 events'), findsOneWidget);
    });

    testWidgets('clear empties the log and shows the empty state', (
      tester,
    ) async {
      await pumpPanel(tester);
      await tester.tap(find.byTooltip('Clear log'));
      await tester.pumpAndSettle();
      expect(find.text('0 / 0 events'), findsOneWidget);
      expect(
        find.text('No events yet — interact with the form to see entries.'),
        findsOneWidget,
      );
    });

    testWidgets('the auto-scroll toggle flips on→off', (tester) async {
      await pumpPanel(tester);
      expect(find.byTooltip('Auto-scroll: on'), findsOneWidget);
      await tester.tap(find.byTooltip('Auto-scroll: on'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Auto-scroll: off'), findsOneWidget);
    });
  });
}
