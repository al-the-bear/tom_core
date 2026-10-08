import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Minimal TomField subclass for test TomFormValidationError construction
// ---------------------------------------------------------------------------
class _TestField<T> extends TomField<T> {
  _TestField(super.tomId, super.initialValue);

  @override
  Widget get widget => const SizedBox.shrink();
}

// ---------------------------------------------------------------------------
// Lightweight event source that doesn't require reflection
// ---------------------------------------------------------------------------
class _TestEventSource implements TomFormEventSource {
  final List<TomFormEventListener> _listeners = [];

  @override
  void addListener(TomFormEventListener listener) => _listeners.add(listener);

  @override
  void removeListener(TomFormEventListener listener) =>
      _listeners.remove(listener);

  @override
  void fireEvent(TomFormEvent event) {
    for (final listener in List.of(_listeners)) {
      listener.handleEvent(event);
    }
  }

  int get listenerCount => _listeners.length;
}

Widget _wrap(Widget child, {TomFormStyle? style}) {
  return MaterialApp(
    home: Scaffold(
      body: style != null
          ? TomFormStyleScope(style: style, child: child)
          : child,
    ),
  );
}

void main() {
  // Reusable test field references for TomFormValidationError construction
  final fieldA = _TestField<String>('a', '');
  final fieldB = _TestField<String>('b', '');
  final fieldName = _TestField<String>('name', '');
  final fieldPassword = _TestField<String>('password', '');
  final fieldConfirmPassword = _TestField<String>('confirmPassword', '');
  final fieldStartDate = _TestField<String>('startDate', '');
  final fieldEndDate = _TestField<String>('endDate', '');

  group('TomFormErrorBanner — display', () {
    testWidgets('renders nothing when no errors', (tester) async {
      final form = _TestEventSource();

      await tester.pumpWidget(_wrap(TomFormErrorBanner(form: form)));

      expect(find.text('Form Errors'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('shows banner on cross-field validation errors', (
      tester,
    ) async {
      final form = _TestEventSource();
      final banner = TomFormErrorBanner(form: form);

      await tester.pumpWidget(_wrap(banner));

      // Fire a TomFormValidatedEvent with cross-field errors
      form.fireEvent(
        TomFormValidatedEvent(
          source: 'testForm',
          errors: [
            TomFormValidationError(
              errorKey: 'error.passwordMismatch',
              fields: [fieldPassword, fieldConfirmPassword],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Form Errors'), findsOneWidget);
      expect(find.text('error.passwordMismatch'), findsOneWidget);
    });

    testWidgets('shows multiple errors', (tester) async {
      final form = _TestEventSource();
      final banner = TomFormErrorBanner(form: form);

      await tester.pumpWidget(_wrap(banner));

      form.fireEvent(
        TomFormValidatedEvent(
          source: 'testForm',
          errors: [
            TomFormValidationError(
              errorKey: 'error.passwordMismatch',
              fields: [fieldPassword, fieldConfirmPassword],
            ),
            TomFormValidationError(
              errorKey: 'error.dateRange',
              fields: [fieldStartDate, fieldEndDate],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('error.passwordMismatch'), findsOneWidget);
      expect(find.text('error.dateRange'), findsOneWidget);
    });

    testWidgets('filters out single-field errors', (tester) async {
      final form = _TestEventSource();
      final banner = TomFormErrorBanner(form: form);

      await tester.pumpWidget(_wrap(banner));

      form.fireEvent(
        TomFormValidatedEvent(
          source: 'testForm',
          errors: [
            // Single-field error — should NOT appear in banner
            TomFormValidationError(
              errorKey: 'error.required',
              fields: [fieldName],
            ),
            // Cross-field error — should appear
            TomFormValidationError(
              errorKey: 'error.mismatch',
              fields: [fieldA, fieldB],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('error.required'), findsNothing);
      expect(find.text('error.mismatch'), findsOneWidget);
    });
  });

  group('TomFormErrorBanner — auto-dismiss', () {
    testWidgets('hides on TomFormSavedEvent', (tester) async {
      final form = _TestEventSource();
      final banner = TomFormErrorBanner(form: form);

      await tester.pumpWidget(_wrap(banner));

      // Show errors
      form.fireEvent(
        TomFormValidatedEvent(
          source: 'testForm',
          errors: [
            TomFormValidationError(
              errorKey: 'error.cross',
              fields: [fieldA, fieldB],
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('error.cross'), findsOneWidget);

      // Save clears errors
      form.fireEvent(TomFormSavedEvent(source: 'testForm'));
      await tester.pump();
      expect(find.text('error.cross'), findsNothing);
      expect(find.text('Form Errors'), findsNothing);
    });

    testWidgets('hides on TomFormDiscardedEvent', (tester) async {
      final form = _TestEventSource();
      final banner = TomFormErrorBanner(form: form);

      await tester.pumpWidget(_wrap(banner));

      // Show errors
      form.fireEvent(
        TomFormValidatedEvent(
          source: 'testForm',
          errors: [
            TomFormValidationError(
              errorKey: 'error.cross',
              fields: [fieldA, fieldB],
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('error.cross'), findsOneWidget);

      // Discard clears errors
      form.fireEvent(TomFormDiscardedEvent(source: 'testForm'));
      await tester.pump();
      expect(find.text('error.cross'), findsNothing);
    });

    testWidgets('hides when validation succeeds (empty errors)', (
      tester,
    ) async {
      final form = _TestEventSource();
      final banner = TomFormErrorBanner(form: form);

      await tester.pumpWidget(_wrap(banner));

      // Show errors
      form.fireEvent(
        TomFormValidatedEvent(
          source: 'testForm',
          errors: [
            TomFormValidationError(
              errorKey: 'error.cross',
              fields: [fieldA, fieldB],
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('error.cross'), findsOneWidget);

      // Validate again with no errors
      form.fireEvent(TomFormValidatedEvent(source: 'testForm', errors: []));
      await tester.pump();
      expect(find.text('Form Errors'), findsNothing);
    });
  });

  group('TomFormErrorBanner — styling', () {
    testWidgets('uses border radius from TomFormStyle', (tester) async {
      final form = _TestEventSource();
      final banner = TomFormErrorBanner(form: form);

      await tester.pumpWidget(
        _wrap(
          banner,
          style: const TomFormStyle(
            defaults: TomFieldStyle(borderRadius: 16.0),
          ),
        ),
      );

      // Show errors
      form.fireEvent(
        TomFormValidatedEvent(
          source: 'testForm',
          errors: [
            TomFormValidationError(
              errorKey: 'error.cross',
              fields: [fieldA, fieldB],
            ),
          ],
        ),
      );
      await tester.pump();

      // Find the container with the border decoration
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.borderRadius, BorderRadius.circular(16.0));
    });

    testWidgets('shows error icon', (tester) async {
      final form = _TestEventSource();
      final banner = TomFormErrorBanner(form: form);

      await tester.pumpWidget(_wrap(banner));

      form.fireEvent(
        TomFormValidatedEvent(
          source: 'testForm',
          errors: [
            TomFormValidationError(
              errorKey: 'error.cross',
              fields: [fieldA, fieldB],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('TomFormErrorBanner — lifecycle', () {
    testWidgets('unsubscribes from form on dispose', (tester) async {
      final form = _TestEventSource();

      // Pump the banner
      await tester.pumpWidget(_wrap(TomFormErrorBanner(form: form)));
      expect(form.listenerCount, 1);

      // Replace with a different widget (triggers dispose)
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(form.listenerCount, 0);

      // Firing events after dispose should not throw
      expect(
        () => form.fireEvent(
          TomFormValidatedEvent(
            source: 'testForm',
            errors: [
              TomFormValidationError(
                errorKey: 'error.cross',
                fields: [fieldA, fieldB],
              ),
            ],
          ),
        ),
        returnsNormally,
      );
    });

    testWidgets('handles form change via didUpdateWidget', (tester) async {
      final form1 = _TestEventSource();
      // ignore: unused_local_variable
      final form2 = _TestEventSource();

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TomFormErrorBanner(
                    key: const ValueKey('banner'),
                    form: form1,
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Switch'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      // Fire event on form1
      form1.fireEvent(
        TomFormValidatedEvent(
          source: 'testForm',
          errors: [
            TomFormValidationError(
              errorKey: 'error.from1',
              fields: [fieldA, fieldB],
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('error.from1'), findsOneWidget);
    });
  });

  group('TomFormErrorBanner — messages', () {
    tearDown(
      () => TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(const {}),
      ),
    );

    testWidgets('shows the resolved message, not the resource key', (
      tester,
    ) async {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(const {
          'error.dateRange.invalid': 'The range ends before {start}.',
        }),
      );
      final form = _TestEventSource();
      await tester.pumpWidget(_wrap(TomFormErrorBanner(form: form)));

      form.fireEvent(
        TomFormValidatedEvent(
          source: 'testForm',
          errors: [
            TomFormValidationError(
              errorKey: 'error.dateRange.invalid',
              params: const {'start': 'the start date'},
              fields: [fieldStartDate, fieldEndDate],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(
        find.text('The range ends before the start date.'),
        findsOneWidget,
      );
      expect(find.text('error.dateRange.invalid'), findsNothing);
    });

    testWidgets('falls back to the key when no resource defines it', (
      tester,
    ) async {
      final form = _TestEventSource();
      await tester.pumpWidget(_wrap(TomFormErrorBanner(form: form)));

      form.fireEvent(
        TomFormValidatedEvent(
          source: 'testForm',
          errors: [
            TomFormValidationError(
              errorKey: 'error.unknown',
              fields: [fieldA, fieldB],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('error.unknown'), findsOneWidget);
    });
  });
}
