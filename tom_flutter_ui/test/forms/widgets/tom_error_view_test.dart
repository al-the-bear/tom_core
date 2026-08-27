import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// Starter coverage for the placement-flexible TomErrorView. Mirrors the
// established TomFormErrorBanner harness — a lightweight event source plus
// minimal fields for FormValidationError construction.

class _TestField<T> extends TomField<T> {
  _TestField(super.tomId, super.initialValue);

  @override
  Widget get widget => const SizedBox.shrink();
}

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

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  final fieldA = _TestField<String>('a', '');
  final fieldB = _TestField<String>('b', '');
  final fieldName = _TestField<String>('name', '');

  group('TomErrorView — empty state', () {
    testWidgets('collapses to SizedBox.shrink when no errors', (tester) async {
      final form = _TestEventSource();

      await tester.pumpWidget(_wrap(TomErrorView(form: form)));

      expect(find.byType(Container), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders custom emptyState when provided', (tester) async {
      final form = _TestEventSource();

      await tester.pumpWidget(_wrap(TomErrorView(
        form: form,
        emptyState: const Text('all good'),
      )));

      expect(find.text('all good'), findsOneWidget);
    });
  });

  group('TomErrorView — error display', () {
    testWidgets('shows both field and cross-field errors by default',
        (tester) async {
      final form = _TestEventSource();

      await tester.pumpWidget(_wrap(TomErrorView(form: form)));

      form.fireEvent(FormValidatedEvent(
        source: 'testForm',
        errors: [
          FormValidationError(errorKey: 'error.required', fields: [fieldName]),
          FormValidationError(
            errorKey: 'error.mismatch',
            fields: [fieldA, fieldB],
          ),
        ],
      ));
      await tester.pump();

      expect(find.text('error.required'), findsOneWidget);
      expect(find.text('error.mismatch'), findsOneWidget);
    });

    testWidgets('filters single-field errors when includeFieldErrors is false',
        (tester) async {
      final form = _TestEventSource();

      await tester.pumpWidget(_wrap(TomErrorView(
        form: form,
        includeFieldErrors: false,
      )));

      form.fireEvent(FormValidatedEvent(
        source: 'testForm',
        errors: [
          FormValidationError(errorKey: 'error.required', fields: [fieldName]),
          FormValidationError(
            errorKey: 'error.mismatch',
            fields: [fieldA, fieldB],
          ),
        ],
      ));
      await tester.pump();

      expect(find.text('error.required'), findsNothing);
      expect(find.text('error.mismatch'), findsOneWidget);
    });

    testWidgets('renders the title when provided', (tester) async {
      final form = _TestEventSource();

      await tester.pumpWidget(_wrap(TomErrorView(form: form, title: 'Problems')));

      form.fireEvent(FormValidatedEvent(
        source: 'testForm',
        errors: [
          FormValidationError(
            errorKey: 'error.mismatch',
            fields: [fieldA, fieldB],
          ),
        ],
      ));
      await tester.pump();

      expect(find.text('Problems'), findsOneWidget);
    });
  });

  group('TomErrorView — auto-clear', () {
    testWidgets('clears on FormSavedEvent', (tester) async {
      final form = _TestEventSource();

      await tester.pumpWidget(_wrap(TomErrorView(form: form)));

      form.fireEvent(FormValidatedEvent(
        source: 'testForm',
        errors: [
          FormValidationError(
            errorKey: 'error.mismatch',
            fields: [fieldA, fieldB],
          ),
        ],
      ));
      await tester.pump();
      expect(find.text('error.mismatch'), findsOneWidget);

      form.fireEvent(FormSavedEvent(source: 'testForm'));
      await tester.pump();
      expect(find.text('error.mismatch'), findsNothing);
    });

    testWidgets('clears on FormDiscardedEvent', (tester) async {
      final form = _TestEventSource();

      await tester.pumpWidget(_wrap(TomErrorView(form: form)));

      form.fireEvent(FormValidatedEvent(
        source: 'testForm',
        errors: [
          FormValidationError(
            errorKey: 'error.mismatch',
            fields: [fieldA, fieldB],
          ),
        ],
      ));
      await tester.pump();
      expect(find.text('error.mismatch'), findsOneWidget);

      form.fireEvent(FormDiscardedEvent(source: 'testForm'));
      await tester.pump();
      expect(find.text('error.mismatch'), findsNothing);
    });
  });

  group('TomErrorView — lifecycle', () {
    testWidgets('unsubscribes from the form on dispose', (tester) async {
      final form = _TestEventSource();

      await tester.pumpWidget(_wrap(TomErrorView(form: form)));
      expect(form.listenerCount, 1);

      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(form.listenerCount, 0);
    });
  });
}
